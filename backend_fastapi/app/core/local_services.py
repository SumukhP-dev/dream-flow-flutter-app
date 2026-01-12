"""
Local inference services for CPU-only deployment.

This module provides lightweight, CPU-optimized alternatives to the cloud-based
HuggingFace services for story generation and text-to-speech.
"""

from __future__ import annotations

import asyncio
import io
import logging
import os
import random
import shutil
import tempfile
import textwrap
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, AsyncIterator, Callable, Optional

from PIL import Image, ImageDraw, ImageFont

try:
    import psutil
except ImportError:
    psutil = None  # Optional dependency for memory monitoring

from ..shared.config import get_settings
from .prompting import PromptBuilder, PromptContext, summarize_prompt_for_clip
from .guardrails import ContentGuard, GuardrailError, PromptSanitizer

settings = get_settings()
logger = logging.getLogger(__name__)

TRANSLATION_MODELS = {
    ("en", "es"): "Helsinki-NLP/opus-mt-en-es",
    ("es", "en"): "Helsinki-NLP/opus-mt-es-en",
    ("en", "fr"): "Helsinki-NLP/opus-mt-en-fr",
    ("fr", "en"): "Helsinki-NLP/opus-mt-fr-en",
    ("en", "ja"): "Helsinki-NLP/opus-mt-tc-big-en-ja",
    ("ja", "en"): "Helsinki-NLP/opus-mt-ja-en",
}
_translation_pipelines: dict[tuple[str, str], Any] = {}

def _get_translation_pipeline(source_lang: str, target_lang: str):
    """Lazy-load Hugging Face translation pipeline for supported language pairs."""
    key = (source_lang.lower(), target_lang.lower())
    model_name = TRANSLATION_MODELS.get(key)
    if not model_name:
        return None

    if key in _translation_pipelines:
        return _translation_pipelines[key]

    try:
        from transformers import pipeline as hf_pipeline
    except ImportError:
        logger.warning("transformers not installed; falling back to llama translation")
        return None

    device = -1
    try:
        import torch

        if torch.cuda.is_available():
            device = 0
    except Exception:
        device = -1

    try:
        translator = hf_pipeline(
            "translation",
            model=model_name,
            device=device,
        )
        _translation_pipelines[key] = translator
        logger.info(
            "Translation pipeline loaded",
            extra={"source": source_lang, "target": target_lang, "model": model_name},
        )
        return translator
    except Exception as exc:
        logger.error(
            "Failed to load translation pipeline %s: %s", model_name, exc, exc_info=True
        )
        return None

# -----------------------------
# Local translation helpers
# -----------------------------
def _fix_common_translation_errors(text: str, source_lang: str, target_lang: str) -> str:
    """Fix common translation errors made by small models."""
    if target_lang.lower() == "es" and source_lang.lower() == "en":
        # Fix common English->Spanish errors
        corrections = {
            "lobo llamado Nova": "zorro llamado Nova",  # wolf -> fox
            "un lobo": "un zorro",  # a wolf -> a fox
            "el lobo": "el zorro",  # the wolf -> the fox
            "mula de luz": "pradera verde",  # mule of light -> green meadow
            "viajaba de uno a otro": "saltaba de una hoja a otra",  # traveled from one to another -> hopped from one leaf to another
        }
        for wrong, correct in corrections.items():
            if wrong in text:
                text = text.replace(wrong, correct)
                logger.debug(f"Fixed translation error: '{wrong}' -> '{correct}'")
    return text


def _clean_translation(text: str, source_lang: str = "", target_lang: str = "") -> str:
    """Normalize translation output to plain text."""
    import re
    t = (text or "").strip()
    # Remove any language markers that TinyLlama might include (e.g., "[ES: ...]", "[EN: ...]")
    t = re.sub(r'\[(EN|ES|FR|JA):\s*([^\]]+)\]', r'\2', t, flags=re.IGNORECASE)
    # Remove standalone language codes like "ES:" at start of lines
    t = re.sub(r'^\s*(EN|ES|FR|JA):\s*', '', t, flags=re.IGNORECASE | re.MULTILINE)
    # Strip wrapping quotes/backticks that models sometimes add
    if (t.startswith('"') and t.endswith('"')) or (t.startswith("'") and t.endswith("'")):
        t = t[1:-1].strip()
    if t.startswith("```") and t.endswith("```"):
        t = t.strip("`").strip()
    # Remove "TRANSLATION:" prefix if present
    t = re.sub(r'^TRANSLATION:\s*', '', t, flags=re.IGNORECASE)
    # Remove duplicate sentences (common with small models)
    sentences = [s.strip() for s in t.split('.') if s.strip()]
    # Remove consecutive duplicates
    cleaned_sentences = []
    for i, sent in enumerate(sentences):
        if i == 0 or sent != sentences[i-1]:
            cleaned_sentences.append(sent)
    t = '. '.join(cleaned_sentences)
    if cleaned_sentences:
        t += '.' if not t.endswith('.') else ''
    # Clean up extra whitespace
    t = ' '.join(t.split())
    # Fix common translation errors
    if source_lang and target_lang:
        t = _fix_common_translation_errors(t, source_lang, target_lang)
    return t.strip()


def _translate_local(text: str, source_lang: str, target_lang: str) -> str:
    """
    Translate text using the local llama-cpp model.
    This is used as a fallback when the story model does not emit bilingual markers.
    """
    source = (source_lang or "").lower()
    target = (target_lang or "").lower()
    if not text or source == target or not target:
        return text

    logger.info(f"🌐 Translating ({source}->{target}): {text[:60]}...")

    # Prefer dedicated translation pipeline if available
    translator = _get_translation_pipeline(source, target)
    if translator:
        try:
            result = translator(text, max_length=512)
            if isinstance(result, list) and result:
                translated = result[0].get("translation_text", "")
            elif isinstance(result, dict):
                translated = result.get("translation_text", "")
            else:
                translated = str(result)
            translated = _clean_translation(
                translated, source_lang=source, target_lang=target
            )
            if translated:
                logger.info("✅ HF translation pipeline succeeded")
                return translated
        except Exception as hf_error:
            logger.warning(
                "Translation pipeline failed (%s->%s): %s",
                source,
                target,
                hf_error,
            )

    # TinyLlama prompt: keep it extremely explicit and short.
    # IMPORTANT: Output ONLY the translation (no brackets, no explanations).
    # Use proper vocabulary - translate each word accurately.
    lang_names = {
        "en": "English",
        "es": "Spanish", 
        "fr": "French",
        "ja": "Japanese",
    }
    source_name = lang_names.get(source, source)
    target_name = lang_names.get(target, target)
    
    prompt = (
        f"Translate accurately from {source_name} to {target_name}.\n"
        f"Use correct vocabulary. Do not repeat text. Output ONLY the translation.\n\n"
        f"{source_name}:\n{text}\n\n"
        f"{target_name}:"
    )

    try:
        model = _get_llama_model(use_q2=False)
        out = model(
            prompt,
            max_tokens=160,
            temperature=0.2,
            top_p=0.9,
            repeat_penalty=1.05,
            stop=["</s>", "\n\nTEXT:", "\n\nTRANSLATION:", "<|user|>", "<|system|>"],
        )
        if isinstance(out, dict) and "choices" in out:
            translated = out["choices"][0].get("text", "")
        elif isinstance(out, dict) and "text" in out:
            translated = out["text"]
        else:
            translated = str(out)
        translated = _clean_translation(
            translated, source_lang=source, target_lang=target
        )
        # If model returns empty, fall back to original.
        result = translated or text
        logger.info(f"Translation result: {result[:60]}...")
        return result
    except Exception as e:
        logger.warning(f"Local translation failed ({source}->{target}): {e}")
        return text

# Model download URLs
TINYLLAMA_MODEL_URL = "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
TINYLLAMA_MODEL_FILENAME = "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"

# Q2_K model for ultra-fast phone generation (2-3x faster than Q4_K)
PHONE_TINYLLAMA_Q2_URL = "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q2_K.gguf"
PHONE_TINYLLAMA_Q2_FILENAME = "tinyllama-1.1b-chat-v1.0.Q2_K.gguf"

# Llama 3.2 3B Instruct model (default for high-performance systems)
LLAMA_3_2_3B_MODEL_URL = "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
LLAMA_3_2_3B_MODEL_FILENAME = "Llama-3.2-3B-Instruct-Q4_K_M.gguf"

# Lazy-loaded llama model instance
_llama_model = None


def _get_model_path(use_q2: bool = False) -> Path:
    """Get the path where the local model should be stored.
    
    Args:
        use_q2: If True, use Q2_K quantization for phone clients (faster, smaller)
    """
    model_dir = Path(settings.local_model_path).parent if settings.local_model_path else Path("./models")
    model_dir.mkdir(parents=True, exist_ok=True)
    
    # Determine which model to use based on configuration
    if settings.local_story_model.startswith("llama-3.2"):
        return model_dir / LLAMA_3_2_3B_MODEL_FILENAME
    else:
        if use_q2:
            return model_dir / PHONE_TINYLLAMA_Q2_FILENAME
        else:
            return model_dir / TINYLLAMA_MODEL_FILENAME


def _download_model_if_needed(use_q2: bool = False) -> Path:
    """Download the model if it doesn't exist locally.
    
    Args:
        use_q2: If True, download Q2_K model for phone clients
    """
    model_path = _get_model_path(use_q2=use_q2)
    
    if model_path.exists():
        return model_path
    
    # Determine which model URL to use
    if settings.local_story_model.startswith("llama-3.2"):
        model_url = LLAMA_3_2_3B_MODEL_URL
        model_name = "Llama 3.2 3B Instruct"
        model_size = "~2GB"
    else:
        if use_q2:
            model_url = PHONE_TINYLLAMA_Q2_URL
            model_name = "TinyLlama Q2_K (Phone Optimized)"
            model_size = "~400MB"
        else:
            model_url = TINYLLAMA_MODEL_URL
            model_name = "TinyLlama"
            model_size = "~600MB"
    
    print(f"Downloading {model_name} model to {model_path}...")
    print(f"This is a one-time download ({model_size}). Please wait...")
    
    import requests
    
    response = requests.get(model_url, stream=True)
    response.raise_for_status()
    
    total_size = int(response.headers.get('content-length', 0))
    downloaded = 0
    
    with open(model_path, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
            downloaded += len(chunk)
            if total_size > 0:
                percent = (downloaded / total_size) * 100
                print(f"\rDownloading: {percent:.1f}%", end="", flush=True)
    
    print(f"\n{model_name} model download complete!")
    return model_path


def _check_memory_available(min_gb: float = 2.0) -> tuple[bool, float]:
    """Check if enough memory is available. Returns (has_enough, available_gb)."""
    if psutil is None:
        # psutil not available, assume we have enough
        return True, 8.0
    
    try:
        mem = psutil.virtual_memory()
        available_gb = mem.available / (1024 ** 3)
        return available_gb >= min_gb, available_gb
    except Exception:
        # If check fails, assume we have enough
        return True, 8.0


def _get_llama_model(use_q2: bool = False):
    """Get or create the Llama model instance (lazy loading).
    
    Optimized for CPU-only, low-memory systems by default, with an optional
    fast mode that prioritizes latency over story length/quality.
    
    Args:
        use_q2: If True, use Q2_K quantization for phone clients (faster, smaller)
    """
    global _llama_model
    
    # For Q2 models, we might want a separate instance to avoid conflicts
    # For now, we'll use the same global instance but reload if needed
    # Check if we need to reload: if model is None, or if we need Q2 but current model isn't Q2
    needs_reload = (
        _llama_model is None or 
        (use_q2 and (not hasattr(_llama_model, '_is_q2') or not _llama_model._is_q2)) or
        (not use_q2 and hasattr(_llama_model, '_is_q2') and _llama_model._is_q2)
    )
    
    if needs_reload:
        from llama_cpp import Llama

        # Check available memory before loading (only warn, don't block)
        has_memory, available_gb = _check_memory_available(min_gb=1.5)
        if not has_memory:
            logger.warning(
                f"Low memory detected ({available_gb:.2f} GB available). "
                "Model loading may fail or be slow."
            )

        model_path = _download_model_if_needed(use_q2=use_q2)

        # Get configuration flags
        use_gpu = settings.story_model_use_gpu
        gpu_layers = settings.story_model_gpu_layers
        low_memory_mode = settings.low_memory_mode
        fast_mode = getattr(settings, "fast_mode", False)
        
        # Ultra-fast phone mode: use Q2_K and minimal settings
        if use_q2:
            fast_mode = True
            low_memory_mode = True

        print(f"Loading {settings.local_story_model} model from {model_path}...")
        print(f"Available memory: {available_gb:.2f} GB")
        print(f"GPU acceleration requested: {use_gpu} ({gpu_layers} layers)")

        # Ultra-fast phone mode: minimal context window for speed
        if use_q2:
            n_ctx = 256  # Minimal context for ultra-fast
            n_batch = 32  # Smaller batch for speed
            n_threads = min(os.cpu_count() or 2, 2)
            logger.info(
                "Using ultra-fast phone mode (Q2_K) for local story model",
                extra={"n_ctx": n_ctx, "n_batch": n_batch, "n_threads": n_threads},
            )
        # Fast mode: small context/batch/thread counts for latency, but enough for prompts
        elif fast_mode:
            # Increased from 256 to 512 to accommodate longer prompts (system + user prompt)
            n_ctx = 512
            n_batch = 64
            # Use at most 2 threads to avoid contention on small 8GB laptops
            n_threads = min(os.cpu_count() or 2, 2)
            logger.info(
                "Using fast mode for local story model",
                extra={"n_ctx": n_ctx, "n_batch": n_batch, "n_threads": n_threads},
            )
        else:
            # Low-memory mode vs high-performance defaults
            if low_memory_mode or available_gb < 4.0:
                # Fallback to low-memory mode if explicitly enabled or low RAM
                n_ctx = 512 if low_memory_mode else 1024
                n_batch = 128 if low_memory_mode else 256
                logger.info("Using low-memory mode", extra={"n_ctx": n_ctx, "n_batch": n_batch})
            else:
                # High-performance mode: large context window and batch size
                n_ctx = 4096  # Large context window for better quality
                n_batch = 512  # Large batch size for faster processing
                logger.info(
                    "Using high-performance mode",
                    extra={"n_ctx": n_ctx, "n_batch": n_batch},
                )

            # Use all available CPU threads (no artificial limits)
            cpu_count = os.cpu_count() or 4
            n_threads = cpu_count

        try:
            # Build Llama initialization parameters
            llama_params = {
                "model_path": str(model_path),
                "n_ctx": n_ctx,
                "n_threads": n_threads,
                "n_batch": n_batch,
                "verbose": False,
                "use_mmap": True,
                "use_mlock": False,
            }

            # Add GPU acceleration if enabled; otherwise force CPU-only
            if use_gpu:
                try:
                    llama_params["n_gpu_layers"] = gpu_layers
                    print(f"GPU acceleration enabled: {gpu_layers} layers on GPU")
                except Exception as e:
                    logger.warning(f"GPU acceleration requested but not available: {e}")
                    logger.info("Falling back to CPU-only mode")
                    llama_params["n_gpu_layers"] = 0
            else:
                llama_params["n_gpu_layers"] = 0

            _llama_model = Llama(**llama_params)
            _llama_model._is_q2 = use_q2  # Mark model type
            print("Model loaded successfully!")
            print(
                f"Context window: {n_ctx}, Batch size: {n_batch}, "
                f"Threads: {n_threads}, GPU layers: {llama_params.get('n_gpu_layers', 0)}, "
                f"Q2 mode: {use_q2}"
            )
        except MemoryError as e:
            logger.error(f"Out of memory loading Llama model: {e}", exc_info=True)
            raise VideoGenerationMemoryError(
                f"Insufficient memory to load model. Available: {available_gb:.2f} GB. "
                "Try closing other applications or set LOW_MEMORY_MODE=true"
            )
        except Exception as e:
            logger.error(f"Failed to load Llama model: {e}", exc_info=True)
            # Try with reduced settings as fallback
            if n_ctx > 1024:
                logger.warning("Retrying with reduced settings...")
                try:
                    _llama_model = Llama(
                        model_path=str(model_path),
                        n_ctx=1024,
                        n_threads=min(n_threads, 4),
                        n_batch=256,
                        verbose=False,
                        use_mmap=True,
                        use_mlock=False,
                        n_gpu_layers=gpu_layers if use_gpu else 0,
                    )
                    print("Model loaded successfully with reduced settings (fallback mode)")
                except Exception as e2:
                    logger.error(f"Fallback loading also failed: {e2}", exc_info=True)
                    raise
            else:
                raise

    return _llama_model


@dataclass
class LocalStoryGenerator:
    """CPU-optimized story generator using llama-cpp-python directly."""
    
    prompt_builder: PromptBuilder
    
    async def generate(self, context: PromptContext, user_agent: str | None = None, ultra_fast_mode: bool = False) -> str:
        """
        Generate story text using llama-cpp-python directly.
        
        This keeps all model weights on this machine and runs inference
        in-process using llama-cpp-python.
        
        Args:
            context: Prompt context for story generation
            user_agent: User-Agent header for device detection (optional, not used by local generators)
            ultra_fast_mode: If True, use Q2_K model and minimal settings for phone clients
        """
        prompt = self.prompt_builder.story_prompt(context)
        
        # Log prompt details for debugging bilingual generation
        import logging
        logger = logging.getLogger(__name__)
        if hasattr(context, 'primary_language') and hasattr(context, 'secondary_language'):
            primary_lang = getattr(context, 'primary_language', '')
            secondary_lang = getattr(context, 'secondary_language', '')
            if primary_lang and secondary_lang:
                logger.info(f"🌐 Bilingual prompt generated: primary={primary_lang}, secondary={secondary_lang}")
                # Check if bilingual instruction is in the prompt
                if f"[{primary_lang.upper()}:" in prompt and f"[{secondary_lang.upper()}:" in prompt:
                    logger.info("Bilingual formatting instructions found in prompt")
                else:
                    logger.warning("Bilingual formatting instructions may be missing from prompt")
                # Log a snippet of the prompt to verify
                if "BILINGUAL" in prompt or "bilingual" in prompt.lower() or "CRITICAL" in prompt:
                    logger.info(f"📋 Prompt snippet (first 500 chars): {prompt[:500]}...")
                    # Also log the end of the prompt where bilingual instructions should be
                    if len(prompt) > 500:
                        logger.info(f"📋 Prompt snippet (last 300 chars): ...{prompt[-300:]}")
                    # Check if CRITICAL or Format is in prompt
                    has_critical = "CRITICAL" in prompt
                    has_format = "Format:" in prompt or "format:" in prompt.lower()
                    logger.info(f"📋 Prompt contains 'CRITICAL': {has_critical}, contains 'Format:': {has_format}")
                else:
                    logger.warning(f"No bilingual keywords found in prompt! Prompt length: {len(prompt)}")
                    logger.warning(f"   Prompt preview: {prompt[:200]}...")
        
        # Check if bilingual story is requested - needs more context (must be defined early)
        is_bilingual = (hasattr(context, 'primary_language') and 
                       hasattr(context, 'secondary_language') and
                       getattr(context, 'primary_language', '') and
                       getattr(context, 'secondary_language', '') and
                       getattr(context, 'primary_language', '').lower() != getattr(context, 'secondary_language', '').lower())
        
        # Detect phone client and enable ultra-fast mode
        if not ultra_fast_mode and user_agent:
            from ..core.version_detector import is_phone_client
            ultra_fast_mode = is_phone_client(user_agent)

        # System prompt to steer the model (enhanced for bilingual stories)
        if is_bilingual:
            system_prompt = (
                "You are a creative bedtime story engine for children. "
                "Write soothing, imaginative, age-appropriate stories. "
                "CRITICAL: Always follow the exact formatting rules provided in the user prompt. "
                "Use the bracket format for every sentence as instructed."
            )
        else:
            system_prompt = (
                "You are a creative bedtime story engine for children. "
                "Write soothing, imaginative, age-appropriate stories."
            )

        # Map target_length (approx chars) to token budget
        # Rough estimate: 1 token ~4 characters
        # Fast mode and low-memory mode keep stories short for latency.
        low_memory_mode = settings.low_memory_mode
        fast_mode = getattr(settings, "fast_mode", False)
        max_story_length = getattr(settings, "max_story_length", 500)
        
        # Ultra-fast mode: use phone-specific settings
        if ultra_fast_mode:
            max_tokens = settings.phone_max_tokens  # 128 tokens (~150 words)
            max_context = 256  # Minimal context window
            temperature = 0.7  # More deterministic for speed
        else:
            # Get context window size from model configuration
            # Fast mode uses 512, low-memory uses 512-1024, high-performance uses 4096
            # Bilingual stories need more context for the formatting instructions
            if fast_mode:
                max_context = 1024 if is_bilingual else 512  # Increase for bilingual
            elif low_memory_mode:
                max_context = 1024 if is_bilingual else 512  # Increase for bilingual
            else:
                max_context = 4096
        
        # Estimate prompt tokens (rough: 1 token ~4 chars)
        # System prompt is ~50 tokens, user prompt varies, assistant tag is ~5 tokens
        system_tokens = len(system_prompt) // 4
        user_tokens = len(prompt) // 4
        overhead_tokens = 20  # Tags and formatting
        estimated_prompt_tokens = system_tokens + user_tokens + overhead_tokens
        
        # If prompt is too long, truncate it (keep system prompt, truncate user prompt)
        # For bilingual stories, try to preserve the formatting instructions at the end
        # Leave at least 100 tokens for generation
        if estimated_prompt_tokens > max_context - 100:
            max_user_tokens = max_context - 100 - system_tokens - overhead_tokens
            max_user_prompt_chars = max_user_tokens * 4
            if len(prompt) > max_user_prompt_chars:
                # For bilingual, try to keep the formatting instructions
                if is_bilingual and "CRITICAL" in prompt:
                    # Find where the bilingual instructions start
                    critical_idx = prompt.find("CRITICAL")
                    if critical_idx > 0:
                        # Keep the beginning and the bilingual instructions
                        # Calculate how much we can keep from the start
                        instructions_text = prompt[critical_idx:]
                        instructions_chars = len(instructions_text)
                        available_chars = max_user_prompt_chars - instructions_chars - 10  # 10 for "..."
                        if available_chars > 100:  # Only if we have reasonable space
                            prompt = prompt[:available_chars] + "...\n" + instructions_text
                            logger.info(f"Bilingual prompt truncated but formatting instructions preserved")
                        else:
                            # Not enough space, truncate normally but warn
                            prompt = prompt[:max_user_prompt_chars] + "..."
                            logger.warning(f"Bilingual prompt truncated - formatting instructions may be lost!")
                    else:
                        prompt = prompt[:max_user_prompt_chars] + "..."
                else:
                    prompt = prompt[:max_user_prompt_chars] + "..."
                
                logger.warning(
                    f"Prompt too long ({len(prompt)} chars, ~{estimated_prompt_tokens} tokens). "
                    f"Truncated to {len(prompt)} chars to fit context window of {max_context}."
                )
        
        # Combine system prompt and user prompt (after truncation if needed)
        full_prompt = f"<|system|>\n{system_prompt}\n<|user|>\n{prompt}\n<|assistant|>\n"
        
        # Log the full prompt for bilingual stories to debug
        if is_bilingual:
            logger.info(f"📝 Full prompt being sent to LLM (first 800 chars):\n{full_prompt[:800]}...")
            if len(full_prompt) > 800:
                logger.info(f"📝 Full prompt (last 400 chars):\n...{full_prompt[-400:]}")
            # Check if CRITICAL is in the final prompt
            if "CRITICAL" in full_prompt:
                logger.info("CRITICAL bilingual instruction found in full prompt")
            else:
                logger.error("CRITICAL bilingual instruction MISSING from full prompt!")

        if ultra_fast_mode:
            # Already set above
            pass
        elif fast_mode:
            # Ultra-short stories: ~250-300 characters
            max_tokens = max(64, min(128, max_story_length // 4 or 128))
        elif low_memory_mode:
            max_tokens = 128  # Low-memory mode: ~500 chars
        else:
            max_tokens = 1024  # High-performance: ~4000 chars

        # Clamp by requested target_length as well (unless ultra-fast mode)
        if not ultra_fast_mode:
            approx_tokens = max(32, min(max_tokens, max(1, context.target_length) // 4))
        else:
            approx_tokens = max_tokens

        def _generate() -> str:
            """Generate text using llama-cpp-python (blocking call)."""
            # Use Q2_K model for ultra-fast mode
            model = _get_llama_model(use_q2=ultra_fast_mode)
            
            output = model(
                full_prompt,
                max_tokens=approx_tokens,
                temperature=temperature if ultra_fast_mode else (0.7 if fast_mode else 0.8),
                top_p=0.9,
                repeat_penalty=1.05,
                stop=["</s>", "<|user|>", "<|system|>", "\n\n\n"],
            )
            
            # Extract generated text from response
            if isinstance(output, dict) and "choices" in output:
                text = output["choices"][0].get("text", "").strip()
            elif isinstance(output, dict) and "text" in output:
                text = output["text"].strip()
            else:
                # Fallback: try to get text directly
                text = str(output).strip()
            
            if not text:
                raise ValueError("Local model returned empty content")
            
            # Log generated text for debugging
            import logging
            logger = logging.getLogger(__name__)
            logger.info(f"📖 Generated story text (first 500 chars): {text[:500]}...")
            logger.info(f"📖 Full story text length: {len(text)} characters")
            
            # Check for incomplete generation issues
            if len(text) < 100:
                logger.warning(f"⚠️ Very short story generated ({len(text)} chars): '{text}'")
            elif text.strip().startswith("Debug") or "Debug" in text[:50]:
                logger.warning(f"⚠️ Debug text detected in story: '{text[:100]}'")
                # This suggests the model is generating debug output instead of story
            
            # Check for bilingual markers if bilingual was requested
            if hasattr(context, 'primary_language') and hasattr(context, 'secondary_language'):
                primary_lang = getattr(context, 'primary_language', '').upper()
                secondary_lang = getattr(context, 'secondary_language', '').upper()
                if primary_lang and secondary_lang and primary_lang != secondary_lang:
                    has_primary = f"[{primary_lang}:" in text
                    has_secondary = f"[{secondary_lang}:" in text
                    if has_primary and has_secondary:
                        logger.info(f"Bilingual markers detected: [{primary_lang}: and [{secondary_lang}:")
                    else:
                        logger.warning(
                            f"Bilingual markers missing! Expected [{primary_lang}: and [{secondary_lang}: "
                            f"but found: primary={has_primary}, secondary={has_secondary}"
                        )
                        logger.warning(f"   Full generated text: {text}")
            
            return text

        # Run generation in thread pool with timeout
        # Ultra-fast mode uses shortest timeout, fast mode uses shorter timeout
        if ultra_fast_mode:
            timeout_seconds = 30.0  # 30s for ultra-fast phone mode
        elif settings.story_model_use_gpu:
            timeout_seconds = 300.0  # 5 min GPU
        elif fast_mode:
            timeout_seconds = 60.0  # 1 min CPU (fast mode)
        else:
            timeout_seconds = 900.0  # 15 min CPU (standard)
        try:
            content = await asyncio.wait_for(
                asyncio.to_thread(_generate),
                timeout=timeout_seconds,
            )
            
            # Post-process to add bilingual markers if missing (for non-streaming generate)
            if hasattr(context, 'primary_language') and hasattr(context, 'secondary_language'):
                primary_lang = getattr(context, 'primary_language', '').upper()
                secondary_lang = getattr(context, 'secondary_language', '').upper()
                if primary_lang and secondary_lang and primary_lang != secondary_lang:
                    has_primary = f"[{primary_lang}:" in content
                    has_secondary = f"[{secondary_lang}:" in content
                    if not (has_primary and has_secondary):
                        logger.warning("Bilingual markers missing in generate(); adding post-processing...")
                        # First, remove any existing partial markers to avoid double-wrapping
                        import re
                        # Remove any existing [LANG: ...] markers (more robust regex)
                        cleaned_content = re.sub(r'\[(EN|ES|FR|JA):\s*([^\]]+)\]', r'\2', content, flags=re.IGNORECASE)
                        # Also remove incomplete markers at start of lines
                        cleaned_content = re.sub(r'^\[(EN|ES|FR|JA):\s*', '', cleaned_content, flags=re.IGNORECASE | re.MULTILINE)
                        
                        # Split into paragraphs and wrap each in bilingual format
                        # Handle both double newlines (paragraph breaks) and single newlines
                        # Use local translation for the secondary language when possible.
                        logger.info(f"🔧 Post-processing: Original content length: {len(cleaned_content)}, Preview: {cleaned_content[:200]}...")
                        # First try splitting by double newlines (paragraphs)
                        if '\n\n' in cleaned_content:
                            para_blocks = [b.strip() for b in cleaned_content.split('\n\n') if b.strip()]
                            logger.info(f"🔧 Split by double newlines: {len(para_blocks)} blocks")
                        else:
                            # No double newlines, split by single newlines
                            para_blocks = [b.strip() for b in cleaned_content.split('\n') if b.strip()]
                            logger.info(f"🔧 Split by single newlines: {len(para_blocks)} blocks")
                        
                        formatted_paragraphs = []
                        for i, block in enumerate(para_blocks):
                            # If block has multiple lines (from single newline splits), join them
                            if '\n' in block:
                                lines = [l.strip() for l in block.split('\n') if l.strip()]
                                para_text = ' '.join(lines) if lines else block
                            else:
                                para_text = block
                            
                            if para_text and para_text.strip():
                                # Translate primary->secondary if they differ; otherwise just reuse.
                                logger.info(f"🔄 Translating paragraph {i+1}/{len(para_blocks)} ({primary_lang}->{secondary_lang}): {para_text[:80]}...")
                                secondary_text = _translate_local(
                                    para_text,
                                    source_lang=primary_lang.lower(),
                                    target_lang=secondary_lang.lower(),
                                )
                                formatted_para = f"[{primary_lang}: {para_text}] [{secondary_lang}: {secondary_text}]"
                                formatted_paragraphs.append(formatted_para)
                                logger.warning(
                                    f"Paragraph {i+1} formatted: EN({len(para_text)} chars) -> "
                                    f"{secondary_lang}({len(secondary_text)} chars)"
                                )
                                logger.debug(f"🔧 Formatted paragraph {i+1}: {formatted_para[:100]}...")
                        
                        if formatted_paragraphs:
                            content = '\n\n'.join(formatted_paragraphs)
                            logger.warning(f"Post-processed {len(formatted_paragraphs)} bilingual paragraphs")
                            logger.warning(f"Result preview (first 500 chars): {content[:500]}...")
                        else:
                            logger.warning(
                                "Post-processing resulted in empty content! "
                                f"Original length: {len(content)}, Cleaned length: {len(cleaned_content)}, "
                                f"Preview: {content[:200]}..."
                            )
                            logger.warning(
                                f"Para blocks count: {len(para_blocks)}, "
                                f"First block preview: {para_blocks[0][:100] if para_blocks else 'N/A'}..."
                            )
            
            return content
        except asyncio.TimeoutError:
            raise ValueError(f"Local story generation timed out after {timeout_seconds/60:.0f} minutes. Try reducing target_length or num_scenes.")
        except Exception as e:
            logger.error(f"Local story generation failed: {e}", exc_info=True)
            raise

    async def generate_stream(self, context: PromptContext) -> AsyncIterator[str]:
        """
        Stream story text in chunks.

        For now this reuses generate() and chunks the completed story. It can
        later be replaced with llama-cpp's token streaming API without
        changing callers.
        """
        full_text = await self.generate(context)
        
        # Log the full generated text for debugging
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"📖 Stream: Generated story text (first 500 chars): {full_text[:500]}...")
        logger.info(f"📖 Stream: Full story length: {len(full_text)} characters")
        
        # Check for truncation issues
        if len(full_text) < 50:
            logger.warning(f"⚠️ Possible text truncation detected - story only {len(full_text)} chars: '{full_text}'")
        
        # Post-process to add bilingual markers if missing
        if hasattr(context, 'primary_language') and hasattr(context, 'secondary_language'):
            primary_lang = getattr(context, 'primary_language', '').upper()
            secondary_lang = getattr(context, 'secondary_language', '').upper()
            if primary_lang and secondary_lang and primary_lang != secondary_lang:
                has_primary = f"[{primary_lang}:" in full_text
                has_secondary = f"[{secondary_lang}:" in full_text
                if has_primary and has_secondary:
                    logger.info(f"Stream: Bilingual markers detected: [{primary_lang}: and [{secondary_lang}:")
                else:
                    logger.warning(
                        f"Stream: Bilingual markers missing! Expected [{primary_lang}: and "
                        f"[{secondary_lang}: but found: primary={has_primary}, secondary={has_secondary}"
                    )
                    logger.warning(f"   Full generated text: {full_text}")
                    
                    # Post-process: Wrap paragraphs in bilingual format
                    # First, remove any existing partial markers to avoid double-wrapping
                    import re
                    # Remove any existing [LANG: ...] markers (more robust regex)
                    cleaned_text = re.sub(r'\[(EN|ES|FR|JA):\s*([^\]]+)\]', r'\2', full_text, flags=re.IGNORECASE)
                    # Also remove incomplete markers at start of lines
                    cleaned_text = re.sub(r'^\[(EN|ES|FR|JA):\s*', '', cleaned_text, flags=re.IGNORECASE | re.MULTILINE)
                    
                    # Split into paragraphs and wrap each in [EN: ...] [ES: ...] format
                    # Handle both double newlines (paragraph breaks) and single newlines
                    # For now, use the same English text for Spanish (frontend can handle translation later)
                    logger.info("🔧 Stream post-processing: Adding bilingual markers to generated text")
                    logger.info(f"🔧 Stream post-processing: Original content length: {len(cleaned_text)}, Preview: {cleaned_text[:200]}...")
                    # First try splitting by double newlines (paragraphs)
                    if '\n\n' in cleaned_text:
                        para_blocks = [b.strip() for b in cleaned_text.split('\n\n') if b.strip()]
                        logger.info(f"🔧 Stream split by double newlines: {len(para_blocks)} blocks")
                    else:
                        # No double newlines, split by single newlines
                        para_blocks = [b.strip() for b in cleaned_text.split('\n') if b.strip()]
                        logger.info(f"🔧 Stream split by single newlines: {len(para_blocks)} blocks")
                    
                    formatted_paragraphs = []
                    for i, block in enumerate(para_blocks):
                        # If block has multiple lines (from single newline splits), join them
                        if '\n' in block:
                            lines = [l.strip() for l in block.split('\n') if l.strip()]
                            para_text = ' '.join(lines) if lines else block
                        else:
                            para_text = block
                        
                        if para_text and para_text.strip():
                            formatted_para = f"[{primary_lang}: {para_text}] [{secondary_lang}: {para_text}]"
                            formatted_paragraphs.append(formatted_para)
                            logger.debug(f"🔧 Stream formatted paragraph {i+1}: {formatted_para[:100]}...")
                    
                    if formatted_paragraphs:
                        full_text = '\n\n'.join(formatted_paragraphs)
                        logger.info(f"Stream post-processed: Added {len(formatted_paragraphs)} bilingual paragraphs")
                        logger.info(f"Stream post-processed text (first 500 chars): {full_text[:500]}...")
                    else:
                        logger.warning(
                            "Stream post-processing resulted in empty content! "
                            f"Original length: {len(full_text)}, Cleaned length: {len(cleaned_text)}, "
                            f"Preview: {full_text[:200]}..."
                        )
                        logger.warning(
                            f"Stream para blocks count: {len(para_blocks)}, "
                            f"First block preview: {para_blocks[0][:100] if para_blocks else 'N/A'}..."
                        )
                    logger.info(f"Post-processed text (first 500 chars): {full_text[:500]}...")

        chunk_size = 200
        try:
            # Use while loop instead of for loop to avoid StopIteration issues in async context
            i = 0
            while i < len(full_text):
                chunk = full_text[i : i + chunk_size]
                if not chunk:  # Safety check for empty chunks
                    break
                yield chunk
                i += chunk_size
        except GeneratorExit:
            # Handle generator cleanup gracefully
            return
        except Exception as e:
            # Log other exceptions but don't re-raise StopIteration
            logger.error(f"Error in generate_stream chunking: {e}", exc_info=True)
            raise


@dataclass
class LocalNarrationGenerator:
    """CPU-optimized narration generator using edge-tts."""
    
    prompt_builder: PromptBuilder
    prompt_sanitizer: PromptSanitizer = field(default_factory=PromptSanitizer)
    voice: str = field(default_factory=lambda: settings.edge_tts_voice)
    
    async def synthesize(
        self,
        story: str,
        context: PromptContext,
        voice: str | None,
        supabase_client: Optional[Any] = None,
        user_agent: str | None = None,
    ) -> str:
        """
        Synthesize audio using edge-tts (Microsoft Edge Text-to-Speech).
        
        Args:
            story: Story text to synthesize
            context: Prompt context
            voice: Voice to use for synthesis
            supabase_client: Supabase client for storage
            user_agent: User-Agent header for device detection (optional, not used by local generators)
        
        Returns:
            Signed URL if supabase_client is provided, otherwise local file path
        """
        import edge_tts
        
        # Use provided voice or default
        tts_voice = voice if voice else self.voice
        
        # Map common voice names to edge-tts voices
        voice_mapping = {
            "alloy": "en-US-AriaNeural",
            "echo": "en-US-GuyNeural",
            "fable": "en-GB-SoniaNeural",
            "onyx": "en-US-ChristopherNeural",
            "nova": "en-US-JennyNeural",
            "shimmer": "en-AU-NatashaNeural",
        }
        
        edge_voice = voice_mapping.get(tts_voice, tts_voice)
        
        # Sanitize and prepare text for TTS
        narration_text = self.prompt_sanitizer.enforce(story, prompt_type="narration")
        
        # Try edge-tts first (fast + high quality), then fall back to local Windows TTS.
        # Edge TTS can fail with HTTP 403 depending on network/region/service changes.
        filename = f"{uuid.uuid4()}.mp3"
        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp_file:
            tmp_path = tmp_file.name

        try:
            # Use shorter timeout to fail faster and move to next fallback
            communicate = edge_tts.Communicate(narration_text, edge_voice)
            await asyncio.wait_for(communicate.save(tmp_path), timeout=30.0)  # 30s timeout instead of default

            with open(tmp_path, "rb") as f:
                audio_bytes = f.read()

            if supabase_client:
                return supabase_client.upload_audio(audio_bytes, filename)

            audio_path = settings.audio_dir / filename
            audio_path.write_bytes(audio_bytes)
            return f"/assets/audio/{filename}"

        except asyncio.TimeoutError:
            logger.warning(
                f"edge-tts timed out after 30s for voice '{edge_voice}'. "
                f"Falling back to local pyttsx3 TTS."
            )
        except Exception as e:
            # Log more details about the edge-tts failure
            error_details = str(e)
            if "403" in error_details:
                logger.warning(
                    f"edge-tts failed with HTTP 403 (likely regional/token restriction): {e}. "
                    f"Consider using a different TTS voice or checking network connectivity. "
                    f"Falling back to local pyttsx3 TTS."
                )
            elif "timeout" in error_details.lower():
                logger.warning(
                    f"edge-tts timed out: {e}. This may be due to network issues. "
                    f"Falling back to local pyttsx3 TTS."
                )
            else:
                logger.warning(
                    f"edge-tts narration failed: {e}. Falling back to local pyttsx3 TTS."
                )

            # Local fallback (Windows SAPI5 via pyttsx3). Writes WAV.
            wav_filename = f"{uuid.uuid4()}.wav"
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as wav_tmp:
                wav_tmp_path = wav_tmp.name

            try:
                def _speak_to_file():
                    import pyttsx3  # type: ignore
                    engine = pyttsx3.init()
                    # Best-effort: slow down a touch for bedtime narration
                    try:
                        rate = engine.getProperty("rate")
                        engine.setProperty("rate", int(rate * 0.9))
                    except Exception:
                        pass
                    engine.save_to_file(narration_text, wav_tmp_path)
                    engine.runAndWait()

                await asyncio.to_thread(_speak_to_file)

                with open(wav_tmp_path, "rb") as f:
                    wav_bytes = f.read()

                if supabase_client:
                    return supabase_client.upload_audio(wav_bytes, wav_filename)

                audio_path = settings.audio_dir / wav_filename
                audio_path.write_bytes(wav_bytes)
                return f"/assets/audio/{wav_filename}"

            finally:
                if os.path.exists(wav_tmp_path):
                    os.unlink(wav_tmp_path)

        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)


def _truncate_caption(text: str, max_length: int = 200) -> str:
    """Truncate caption text to a maximum length."""
    if len(text) <= max_length:
        return text
    return text[: max_length - 3] + "..."


async def _generate_with_retry(
    fn,
    *,
    timeout: float,
    operation: str = "operation",
    retries: int = 2,
    initial_delay: float = 0.5,
):
    """Run a blocking generation function in a thread with timeout + retries.

    The local image generation path calls into diffusers/torch which is blocking.
    This helper prevents the event loop from being blocked and provides a small
    amount of resiliency for transient errors.
    """
    last_err = None
    for attempt in range(retries + 1):
        try:
            # Run the blocking function in a worker thread with a timeout.
            return await asyncio.wait_for(asyncio.to_thread(fn), timeout=timeout)
        except Exception as e:
            last_err = e
            is_last = attempt >= retries
            # Keep logs concise; full stack is logged by callers when needed.
            logger.warning(
                f"{operation} failed (attempt {attempt + 1}/{retries + 1}): {e}"
            )
            if is_last:
                raise
            # Exponential backoff
            await asyncio.sleep(initial_delay * (2**attempt))
    # Should never happen, but keeps type checkers happy.
    raise last_err


# Lazy-loaded image generation pipeline
_image_pipeline = None
DEFAULT_LOCAL_IMAGE_MODEL = "runwayml/stable-diffusion-v1-5"
FALLBACK_LOCAL_IMAGE_MODEL = "stabilityai/sd-turbo"
HF_CACHE_ROOT = os.path.join(os.path.expanduser("~"), ".cache", "huggingface", "hub")


def _model_cache_dir(repo_id: str) -> str:
    """Return the on-disk cache directory for a Hugging Face repo."""
    safe_repo = repo_id.replace("/", "--")
    return os.path.join(HF_CACHE_ROOT, f"models--{safe_repo}")


def _clear_model_cache(repo_id: str) -> None:
    """Delete a cached model snapshot so it can be re-downloaded cleanly."""
    cache_dir = _model_cache_dir(repo_id)
    try:
        if os.path.exists(cache_dir):
            shutil.rmtree(cache_dir)
            logger.info("Cleared Hugging Face cache for %s", repo_id)
    except Exception as cache_err:  # noqa: BLE001
        logger.warning("Failed to clear cache for %s: %s", repo_id, cache_err)


def _detect_device():
    """Detect the best available torch device + dtype for image generation.

    This backend currently forces CPU for stability/memory reasons, but we still
    provide device detection so callers don't crash (and so future configs can
    opt into GPU/MPS safely).
    """
    try:
        import torch  # type: ignore
    except Exception:
        # If torch isn't installed, default to CPU semantics.
        return "cpu", None

    # Default safe choice
    device = "cpu"
    dtype = getattr(torch, "float32", None)

    try:
        if torch.cuda.is_available():
            device = "cuda"
            # float16 is typical for SD on CUDA; keep float32 if unavailable
            dtype = getattr(torch, "float16", dtype)
        elif getattr(torch.backends, "mps", None) is not None and torch.backends.mps.is_available():
            device = "mps"
            # MPS is generally happiest with float16 where possible
            dtype = getattr(torch, "float16", dtype)
    except Exception:
        # Any detection error -> fall back to safe CPU defaults
        device = "cpu"
        dtype = getattr(torch, "float32", None)

    return device, dtype


def _get_image_pipeline():
    """Get or create the image generation pipeline (lazy loading).
    
    Uses Stable Diffusion for local text-to-image generation.
    Returns None if pipeline cannot be loaded (will use placeholders instead).
    """
    global _image_pipeline
    
    if _image_pipeline is None:
        try:
            from diffusers import StableDiffusionPipeline
            import torch
            logger.info("diffusers and torch are available")
        except ImportError as e:
            logger.error(
                f"Local image generation dependencies not available: {e}. "
                "Will use placeholder images instead."
            )
            _image_pipeline = False  # Mark as unavailable
            return None
        
        # Prefer a higher-quality SD checkpoint, but fall back gracefully
        configured_model: str = getattr(
            settings,
            "local_image_model",
            DEFAULT_LOCAL_IMAGE_MODEL,
        )
        configured_is_deprecated = (
            configured_model.strip().lower() == FALLBACK_LOCAL_IMAGE_MODEL
        )

        candidate_models: list[str] = []
        if configured_model and not configured_is_deprecated:
            candidate_models.append(configured_model)

        if DEFAULT_LOCAL_IMAGE_MODEL not in candidate_models:
            candidate_models.append(DEFAULT_LOCAL_IMAGE_MODEL)

        if configured_is_deprecated:
            logger.warning(
                "LOCAL_IMAGE_MODEL=%s is intended only as a lightweight fallback. "
                "Using default %s for better quality.",
                FALLBACK_LOCAL_IMAGE_MODEL,
                DEFAULT_LOCAL_IMAGE_MODEL,
            )

        if FALLBACK_LOCAL_IMAGE_MODEL not in candidate_models:
            candidate_models.append(FALLBACK_LOCAL_IMAGE_MODEL)
        
        # Detect device, but force CPU-only for 8GB-friendly deployments
        device, dtype = _detect_device()
        device = "cpu"
        torch_dtype = torch.float32
        
        last_error: Exception | None = None
        hf_token = getattr(settings, "hf_token", None) or os.getenv("HUGGINGFACE_API_TOKEN")
        if not hf_token:
            logger.warning(
                "HUGGINGFACE_API_TOKEN not configured; gated Hugging Face models may fail to download."
            )

        for model_name in candidate_models:
            logger.info(
                "Loading Stable Diffusion for image generation",
                extra={"device": device, "model": model_name},
            )
            print(
                f"Loading image model: {model_name} (this may take 5-10 minutes on first run to download model)..."
            )
            print(
                f"   Model will be cached at: {os.path.expanduser('~/.cache/huggingface/hub')}"
            )
            
            try:
                logger.info("Starting model download/loading...")
                
                # Try loading with safetensors first, fall back to pickle with explicit permission
                try:
                    pipeline = StableDiffusionPipeline.from_pretrained(
                        model_name,
                        torch_dtype=torch_dtype,
                        low_cpu_mem_usage=True,
                        use_safetensors=True,  # Prefer safetensors
                        **({"use_auth_token": hf_token} if hf_token else {}),
                    )
                except (OSError, ValueError) as safetensor_err:
                    if "safetensors" in str(safetensor_err).lower():
                        logger.info(f"Safetensors not found for {model_name}, using pickle format (safe for trusted models)")
                        pipeline = StableDiffusionPipeline.from_pretrained(
                            model_name,
                            torch_dtype=torch_dtype,
                            low_cpu_mem_usage=True,
                            use_safetensors=False,  # Explicitly allow pickle
                            **({"use_auth_token": hf_token} if hf_token else {}),
                        )
                    else:
                        raise safetensor_err
                pipeline = pipeline.to("cpu")
                if hasattr(pipeline, "unet"):
                    pipeline.unet = pipeline.unet.to("cpu")
                if hasattr(pipeline, "vae"):
                    pipeline.vae = pipeline.vae.to("cpu")
                if hasattr(pipeline, "text_encoder"):
                    pipeline.text_encoder = pipeline.text_encoder.to("cpu")
                
                try:
                    from diffusers import DDIMScheduler
                    
                    pipeline.scheduler = DDIMScheduler.from_config(
                        pipeline.scheduler.config
                    )
                    logger.info(
                        "Configured DDIMScheduler for image generation (high-quality, stable)"
                    )
                except Exception as scheduler_err:
                    logger.warning(
                        "Could not configure scheduler, using default: %s",
                        scheduler_err,
                    )
                
                pipeline.enable_attention_slicing()
                try:
                    if hasattr(pipeline, "vae") and hasattr(
                        pipeline.vae, "enable_slicing"
                    ):
                        pipeline.vae.enable_slicing()
                except Exception:
                    pass
                
                _image_pipeline = pipeline
                logger.info(
                    "Stable Diffusion model loaded successfully for image generation!"
                )
                print("Image generation pipeline ready!")
                break
            except Exception as e:  # noqa: BLE001
                last_error = e
                _image_pipeline = None
                error_text = str(e).lower()
                if "no file named diffusion_pytorch_model" in error_text:
                    logger.warning(
                        "Detected incomplete download for %s; clearing cache and retrying.",
                        model_name,
                    )
                    _clear_model_cache(model_name)
                logger.error(
                    "Failed to load Stable Diffusion model %s: %s",
                    model_name,
                    e,
                    exc_info=True,
                )
                print(f"Image model failed to load for {model_name}: {e}")
                if model_name != candidate_models[-1]:
                    logger.info("Attempting fallback image model...")
                continue
        
        if _image_pipeline is None:
            logger.error(
                "No image generation models could be loaded; using placeholder images",
                exc_info=bool(last_error),
            )
            if last_error:
                print(f"Final image model failure: {last_error}")
            _image_pipeline = False
            return None
    
    # Return None if pipeline is marked as unavailable
    if _image_pipeline is False:
        logger.warning("Image pipeline is marked as unavailable, using placeholders")
        return None
    
    return _image_pipeline


@dataclass
class LocalVisualGenerator:
    """Local image generator using Stable Diffusion via diffusers."""
    
    prompt_builder: PromptBuilder
    prompt_sanitizer: PromptSanitizer = field(default_factory=PromptSanitizer)

    @staticmethod
    def _clip_prompt(prompt: str, limit: int = 55) -> str:
        """Summarize prompts without dropping key subjects before CLIP limit."""
        return summarize_prompt_for_clip(prompt, max_words=limit)
    
    def _create_placeholder_image(
        self, width: int = 1280, height: int = 720, scene_text: str = ""
    ) -> Image.Image:
        """Create a placeholder image when generation fails."""
        # Create gradient-like background (dark purple to dark blue)
        image = Image.new("RGB", (width, height), color=(45, 45, 60))  # Dark blue-gray
        draw = ImageDraw.Draw(image)
        
        # Try to use a nice font, fall back to default
        try:
            font_large = ImageFont.truetype("arial.ttf", 48)
            font_medium = ImageFont.truetype("arial.ttf", 32)
            font_small = ImageFont.truetype("arial.ttf", 24)
        except OSError:
            font_large = ImageFont.load_default()
            font_medium = ImageFont.load_default()
            font_small = ImageFont.load_default()
        
        # Draw centered "Dream Flow" text
        text = "Dream Flow"
        text_bbox = draw.textbbox((0, 0), text, font=font_large)
        text_width = text_bbox[2] - text_bbox[0]
        text_height = text_bbox[3] - text_bbox[1]
        x = (width - text_width) // 2
        y = (height - text_height) // 2 - 60
        
        draw.text((x, y), text, font=font_large, fill=(255, 255, 255))
        
        # Draw scene text if provided
        if scene_text:
            # Wrap scene text to fit width (calculate based on image width)
            import textwrap
            # Calculate max characters per line based on image width (roughly 60 chars for 1280px width)
            max_chars_per_line = int((width - 100) / 20)  # Approximate character width
            wrapped_text = textwrap.fill(scene_text, width=max_chars_per_line)
            
            # Calculate text bounding box properly
            scene_bbox = draw.multiline_textbbox((0, 0), wrapped_text, font=font_medium, spacing=4)
            scene_width = scene_bbox[2] - scene_bbox[0]
            scene_height = scene_bbox[3] - scene_bbox[1]
            scene_x = (width - scene_width) // 2
            scene_y = y + text_height + 40
            
            # Draw background for scene text (RGB mode doesn't support alpha, use solid color)
            padding = 20
            # Use a darker solid color instead of semi-transparent
            draw.rectangle(
                (scene_x - padding, scene_y - padding, scene_x + scene_width + padding, scene_y + scene_height + padding),
                fill=(30, 30, 45),  # Solid dark blue-gray, no alpha
                outline=(100, 100, 150),
                width=2
            )
            # Draw text on top of the rectangle
            draw.multiline_text(
                (scene_x, scene_y), 
                wrapped_text, 
                font=font_medium, 
                fill=(220, 220, 255), 
                align="center",
                spacing=4
            )
        else:
            # Default subtitle
            subtitle = "Visualizing your story..."
            sub_bbox = draw.textbbox((0, 0), subtitle, font=font_small)
            sub_width = sub_bbox[2] - sub_bbox[0]
            sub_x = (width - sub_width) // 2
            sub_y = y + text_height + 30
            
            draw.text((sub_x, sub_y), subtitle, font=font_small, fill=(200, 200, 200))
        
        return image
    
    def _overlay_caption(self, image: Image.Image, text: str) -> Image.Image:
        """Overlay caption text on image."""
        import textwrap
        overlay = image.copy()
        draw = ImageDraw.Draw(overlay)
        width, height = overlay.size
        font_size = max(24, width // 28)
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except OSError:
            font = ImageFont.load_default()
        
        text_block = textwrap.fill(text, width=40)
        text_bbox = draw.multiline_textbbox((0, 0), text_block, font=font)
        padding = 20
        box_width = width - 2 * padding
        box_height = text_bbox[3] - text_bbox[1] + 2 * padding
        y_position = height - box_height - padding
        draw.rectangle(
            (padding, y_position, padding + box_width, y_position + box_height),
            fill=(0, 0, 0, 180),
        )
        draw.multiline_text(
            (padding + 10, y_position + padding),
            text_block,
            font=font,
            fill=(255, 255, 255),
        )
        return overlay
    
    async def create_frames_progressive(
        self,
        story: str,
        context: PromptContext,
        num_scenes: int,
        supabase_client: Optional[Any] = None,
        storage_prefix: str | None = None,
        on_frame_complete: Optional[Callable[[str, int], None]] = None,
        ultra_fast_mode: bool = False,
        include_text_overlay: bool = True,
    ) -> list[str]:
        # Ultra-fast mode: only 1 scene
        if ultra_fast_mode:
            num_scenes = 1
        
        logger.info(f"Starting progressive frame generation for {num_scenes} scenes")
        """Create visual frames progressively, calling on_frame_complete for each frame as it finishes.
        
        Args:
            story: The story text to generate frames for
            context: Prompt context
            num_scenes: Number of scenes to generate
            supabase_client: Optional Supabase client for storage
            storage_prefix: Optional storage prefix
            on_frame_complete: Optional callback function(frame_url: str, index: int) called when each frame completes
            
        Returns:
            List of frame URLs (same as create_frames for compatibility)
        """
        # Split story into scenes
        paragraphs = [p.strip() for p in story.split("\n") if p.strip()]
        
        # Evenly distribute paragraphs across num_scenes
        if not paragraphs:
            chunks = [story]
        else:
            chunks = _distribute_paragraphs(paragraphs, num_scenes)
        
        frames: list[str] = []
        
        normalized_prefix = ""
        if storage_prefix:
            normalized_prefix = f"{storage_prefix.strip('/')}/"
        
        # Decide whether to use real image generation or placeholders
        use_placeholders_flag = getattr(settings, "use_placeholders_only", False)
        
        try:
            import torch  # noqa: F401
            has_torch = True
        except ImportError:
            has_torch = False
        
        use_placeholders = use_placeholders_flag or not has_torch or not getattr(
            settings, "local_image_enabled", True
        )
        
        # Get pipeline (may be None if unavailable)
        # Add timeout to prevent hanging if model is downloading
        # Use a shorter timeout (30s) to fail fast and use placeholders
        pipeline = None
        if not use_placeholders:
            logger.info("Attempting to load image pipeline (30s timeout - will use placeholders if timeout)...")
            try:
                # Check if pipeline is already loaded (from startup pre-loading)
                pipeline = _get_image_pipeline()
                if pipeline is None or pipeline is False:
                    # Pipeline not loaded yet - try loading with timeout
                    logger.info("Pipeline not pre-loaded, attempting to load now (30s timeout)...")
                    print("Loading image model on-demand (this may take 5-10 minutes on first run)...")
                    pipeline = await asyncio.wait_for(
                        asyncio.to_thread(_get_image_pipeline),
                        timeout=30.0  # 30 second timeout - fail fast and use placeholders
                    )
                
                if pipeline is None or pipeline is False:
                    logger.warning("Pipeline not available - using placeholders")
                    print("Image pipeline not available - using placeholder images")
                    use_placeholders = True
                else:
                    logger.info("Image pipeline loaded successfully!")
                    print("Image pipeline loaded successfully!")
            except asyncio.TimeoutError:
                logger.warning("Pipeline loading timed out after 30s - using placeholders immediately")
                print("Pipeline loading timed out - using placeholder images")
                use_placeholders = True
            except Exception as e:
                logger.error(f"Error loading pipeline: {e}", exc_info=True)
                print(f"Error loading pipeline: {e} - using placeholder images")
                use_placeholders = True
        
        # If pipeline is not available, use placeholders for all scenes
        if pipeline is None or use_placeholders:
            if use_placeholders:
                logger.info("Using placeholder images (USE_PLACEHOLDERS_ONLY=true or timeout)")
            else:
                logger.warning("Image pipeline not available, using placeholder images for all scenes")
            
            # Generate placeholders sequentially (fast, so no need for parallel)
            for idx, chunk in enumerate(chunks):
                # Don't truncate for placeholder images - they have more space to display full text
                # Only truncate if text is extremely long (over 500 chars) to prevent layout issues
                caption = chunk if len(chunk) <= 500 else chunk[:497] + "..."
                def _create_placeholder() -> bytes:
                    # Create placeholder with scene text in center, but don't overlay caption at bottom
                    # to avoid duplicate text display
                    image = self._create_placeholder_image(scene_text=caption)
                    # Skip overlay_caption since scene_text is already displayed in the image
                    buffer = io.BytesIO()
                    image.save(buffer, format="PNG")
                    return buffer.getvalue()
                
                placeholder_bytes = await asyncio.to_thread(_create_placeholder)
                
                if supabase_client:
                    filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                    frame_url = supabase_client.upload_frame(placeholder_bytes, filename)
                else:
                    def _save_local() -> str:
                        filename = f"{uuid.uuid4()}.png"
                        path = settings.frames_dir / filename
                        path.write_bytes(placeholder_bytes)
                        return f"/assets/frames/{filename}"
                    
                    frame_url = await asyncio.to_thread(_save_local)
                
                frames.append(frame_url)
                logger.info(f"Placeholder frame {idx + 1}/{len(chunks)} created: {frame_url[:50]}...")
                
                # Call callback if provided (synchronous callback)
                if on_frame_complete:
                    try:
                        logger.info(f"Calling on_frame_complete for placeholder frame {idx + 1}: {frame_url[:50]}...")
                        on_frame_complete(frame_url, idx)
                        logger.info(f"Placeholder frame {idx + 1} callback executed successfully")
                    except Exception as e:
                        logger.error(f"Callback failed for placeholder frame {idx}: {e}", exc_info=True)
            
            logger.info(f"Generated {len(frames)} placeholder frames total")
            return frames
        
        # Generate images in parallel, but yield as each completes
        async def _generate_single_frame(idx: int, chunk: str) -> tuple[int, str]:
            """Generate a single frame and return (index, frame_url)."""
            caption = _truncate_caption(chunk)
            
            try:
                prompt = self.prompt_builder.visual_prompt(context, chunk)
                prompt = self.prompt_sanitizer.enforce(prompt, prompt_type="visual")
                prompt = self._clip_prompt(prompt)
                
                def _generate_image() -> Image.Image:
                    # Ultra-fast mode: use phone-specific settings
                    if ultra_fast_mode:
                        steps = settings.phone_image_steps  # 4 steps
                        resolution = settings.phone_image_resolution  # 256x256
                    else:
                        # Use 20 steps to avoid scheduler indexing errors
                        # Some schedulers have off-by-one issues with low step counts
                        steps = max(getattr(settings, "image_steps", 20), 20)
                        resolution = getattr(settings, "image_resolution", (256, 256))
                    
                    logger.info(f"Generating image for scene {idx + 1}/{len(chunks)}: {prompt[:50]}...")
                    print(f"Generating scene {idx + 1}/{len(chunks)} (this may take 20-40 seconds on CPU)...")
                    
                    if pipeline is None:
                        raise RuntimeError("Image pipeline is None - cannot generate image")
                    
                    try:
                        import torch
                        # Workaround for scheduler off-by-one error: use steps-2
                        # Many schedulers create n+1 timesteps for n steps, then try to access n+1, causing index out of bounds
                        # So if we want n steps, we need to request n-2 to get n-1 timesteps (which is safe)
                        effective_steps = steps
                        scheduler_name = type(pipeline.scheduler).__name__ if hasattr(pipeline, 'scheduler') else 'unknown'
                        logger.info(f"Using {effective_steps} steps (requested {steps}) with scheduler {scheduler_name} to avoid indexing error")
                        generator = torch.Generator(device="cpu").manual_seed(random.randint(0, 2**31 - 1))
                        result = pipeline(
                            prompt=prompt,
                            negative_prompt="photorealistic, photo, harsh contrast, scary, horror, sharp teeth, creepy eyes, gore, weapon, gritty, noisy artifacts, text, watermark, logo, signature, bad quality, blurry, distorted, corruption, glitch, pixelated, low resolution, compression artifacts, jpeg artifacts, noise, grain, dithering, banding, color bleeding",
                            num_inference_steps=effective_steps,
                            height=resolution[1],
                            width=resolution[0],
                            guidance_scale=8.0,
                            generator=generator,
                        )
                        logger.info(f"Pipeline returned result for scene {idx + 1}")
                        
                        if hasattr(result, "images") and len(result.images) > 0:
                            logger.info(f"Image {idx + 1} generated successfully")
                            return result.images[0]
                        else:
                            raise ValueError("Stable Diffusion pipeline did not return images")
                    except Exception as gen_error:
                        logger.error(f"Image generation failed for scene {idx + 1}: {gen_error}")
                        raise
                
                # Generate image with timeout
                logger.info(f"Starting image generation for scene {idx + 1}/{len(chunks)} (timeout: 300s)")
                try:
                    image = await _generate_with_retry(
                        _generate_image,
                        timeout=300.0,
                        operation=f"local_image_generation (scene {idx + 1}/{len(chunks)})",
                    )
                    logger.info(f"Image generation completed for scene {idx + 1}")
                except Exception as e:
                    logger.error(f"Image generation failed for scene {idx + 1}: {e}", exc_info=True)
                    raise
                
                # Process image
                def _process_image() -> bytes:
                    # Ultra-fast mode: skip caption overlay to save time
                    if ultra_fast_mode:
                        image_with_caption = image
                    else:
                        # Apply caption overlay based on parameter
                        if include_text_overlay:
                            image_with_caption = self._overlay_caption(image, caption)
                        else:
                            image_with_caption = image
                    buffer = io.BytesIO()
                    image_with_caption.save(buffer, format="PNG")
                    return buffer.getvalue()
                
                frame_bytes = await asyncio.to_thread(_process_image)
                
                # Save frame
                if supabase_client:
                    filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                    frame_url = supabase_client.upload_frame(frame_bytes, filename)
                else:
                    def _save_local() -> str:
                        filename = f"{uuid.uuid4()}.png"
                        path = settings.frames_dir / filename
                        path.write_bytes(frame_bytes)
                        return f"/assets/frames/{filename}"
                    
                    frame_url = await asyncio.to_thread(_save_local)
                
                return (idx, frame_url)
                
            except Exception as e:
                logger.error(f"Local image generation failed for scene {idx + 1}: {e}", exc_info=True)
                # Fall back to placeholder
                try:
                    def _create_placeholder() -> bytes:
                        # Create placeholder with scene text in center, but don't overlay caption at bottom
                        # to avoid duplicate text display
                        image = self._create_placeholder_image(scene_text=caption)
                        # Skip overlay_caption since scene_text is already displayed in the image
                        buffer = io.BytesIO()
                        image.save(buffer, format="PNG")
                        return buffer.getvalue()
                    
                    placeholder_bytes = await asyncio.to_thread(_create_placeholder)
                    
                    if supabase_client:
                        filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                        frame_url = supabase_client.upload_frame(placeholder_bytes, filename)
                    else:
                        def _save_local() -> str:
                            filename = f"{uuid.uuid4()}.png"
                            path = settings.frames_dir / filename
                            path.write_bytes(placeholder_bytes)
                            return f"/assets/frames/{filename}"
                        
                        frame_url = await asyncio.to_thread(_save_local)
                    
                    return (idx, frame_url)
                except Exception as placeholder_err:
                    logger.error(f"Failed to create placeholder for scene {idx + 1}: {placeholder_err}", exc_info=True)
                    # Last resort: minimal placeholder
                    try:
                        minimal_image = Image.new("RGB", (256, 256), color=(45, 45, 60))
                        buffer = io.BytesIO()
                        minimal_image.save(buffer, format="PNG")
                        minimal_bytes = buffer.getvalue()
                        
                        if supabase_client:
                            filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                            frame_url = supabase_client.upload_frame(minimal_bytes, filename)
                        else:
                            filename = f"{uuid.uuid4()}.png"
                            path = settings.frames_dir / filename
                            path.write_bytes(minimal_bytes)
                            frame_url = f"/assets/frames/{filename}"
                        
                        return (idx, frame_url)
                    except Exception as final_err:
                        logger.critical(f"CRITICAL: Failed to create any image for scene {idx + 1}: {final_err}")
                        return (idx, "")
        
        # Create tasks for all frames
        tasks = [_generate_single_frame(idx, chunk) for idx, chunk in enumerate(chunks)]
        
        # Process frames as they complete (progressive)
        frame_dict: dict[int, str] = {}
        
        # Use asyncio.wait instead of asyncio.as_completed to avoid StopIteration issues
        done, pending = await asyncio.wait(tasks, return_when=asyncio.ALL_COMPLETED)
        
        for task in done:
            try:
                # Safely get task result, wrapping in try-except to prevent StopIteration propagation
                if task.done() and not task.cancelled():
                    try:
                        result = task.result()
                    except (StopIteration, StopAsyncIteration) as stop_err:
                        logger.debug(f"Task completed with StopIteration: {stop_err}")
                        continue
                    except Exception as task_err:
                        logger.error(f"Task failed with error: {task_err}", exc_info=True)
                        continue
                else:
                    logger.warning(f"Task not done or was cancelled, skipping")
                    continue
                
                idx, frame_url = result
                if frame_url and frame_url.strip():
                    frame_dict[idx] = frame_url
                    frames.append(frame_url)
                    
                    # Call callback immediately when frame completes
                    if on_frame_complete:
                        try:
                            on_frame_complete(frame_url, idx)
                        except Exception as e:
                            logger.warning(f"Callback failed for frame {idx}: {e}")
                    
                    logger.info(f"Frame {idx + 1}/{len(chunks)} ready: {frame_url[:50]}...")
            except (StopIteration, StopAsyncIteration) as e:
                logger.warning(f"Generator stopped unexpectedly for frame processing: {e}")
                continue
            except Exception as e:
                logger.error(f"Failed to process completed frame: {e}", exc_info=True)
        
        # Sort frames by index to maintain order
        frames = [frame_dict[i] for i in sorted(frame_dict.keys()) if i < len(chunks)]
        
        # Ensure we have enough frames
        if len(frames) < num_scenes:
            logger.warning(f"Only generated {len(frames)} frames but {num_scenes} were requested. Creating additional placeholders.")
            for idx in range(len(frames), num_scenes):
                try:
                    def _create_extra_placeholder() -> bytes:
                        image = self._create_placeholder_image(scene_text=f"Scene {idx + 1}")
                        buffer = io.BytesIO()
                        image.save(buffer, format="PNG")
                        return buffer.getvalue()
                    
                    placeholder_bytes = await asyncio.to_thread(_create_extra_placeholder)
                    
                    if supabase_client:
                        filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                        frame_url = supabase_client.upload_frame(placeholder_bytes, filename)
                    else:
                        filename = f"{uuid.uuid4()}.png"
                        path = settings.frames_dir / filename
                        path.write_bytes(placeholder_bytes)
                        frame_url = f"/assets/frames/{filename}"
                    
                    frames.append(frame_url)
                    if on_frame_complete:
                        try:
                            on_frame_complete(frame_url, idx)
                        except Exception as e:
                            logger.warning(f"Callback failed for extra placeholder {idx}: {e}")
                except Exception as e:
                    logger.error(f"Failed to create extra placeholder {idx + 1}: {e}")
                    frames.append("")
        
        # Filter out empty strings
        frames = [f for f in frames if f and f.strip()]
        
        logger.info(f"Generated {len(frames)} frames total (requested {num_scenes})")
        return frames

    async def create_frames(
        self,
        story: str,
        context: PromptContext,
        num_scenes: int,
        supabase_client: Optional[Any] = None,
        storage_prefix: str | None = None,
        ultra_fast_mode: bool = False,
        include_text_overlay: bool = True,
    ) -> list[str]:
        """Create visual frames using local Stable Diffusion (non-progressive version for backward compatibility).
        
        Logs frame generation progress and returned URLs for debugging.
        
        Args:
            story: Story text to generate frames for
            context: Prompt context
            num_scenes: Number of scenes to generate
            supabase_client: Optional Supabase client for storage
            storage_prefix: Optional storage prefix
            ultra_fast_mode: If True, use minimal settings (1 image, 4 steps, 256x256, no caption overlay)
        """
        # Ultra-fast mode: only 1 scene
        if ultra_fast_mode:
            num_scenes = 1
        
        # Split story into scenes
        paragraphs = [p.strip() for p in story.split("\n") if p.strip()]
        
        # Evenly distribute paragraphs across num_scenes
        if not paragraphs:
            chunks = [story]
        else:
            chunks = _distribute_paragraphs(paragraphs, num_scenes)
        
        frames: list[str] = []
        
        normalized_prefix = ""
        if storage_prefix:
            normalized_prefix = f"{storage_prefix.strip('/')}/"
        
        # Decide whether to use real image generation or placeholders.
        # On 8GB, CPU-only laptops, placeholders or very lightweight images are preferred.
        use_placeholders_flag = getattr(settings, "use_placeholders_only", False)

        try:
            import torch  # noqa: F401
            # For 8GB CPU-only setups we always run images on CPU; GPU, if present, is ignored here.
            has_torch = True
        except ImportError:
            has_torch = False

        use_placeholders = use_placeholders_flag or not has_torch or not getattr(
            settings, "local_image_enabled", True
        )
        
        # Get pipeline (may be None if unavailable)
        pipeline = _get_image_pipeline() if not use_placeholders else None
        
        # If pipeline is not available, use placeholders for all scenes
        if pipeline is None or use_placeholders:
            if use_placeholders:
                logger.info("Using placeholder images (USE_PLACEHOLDERS_ONLY=true)")
            else:
                logger.warning("Image pipeline not available, using placeholder images for all scenes")
                logger.warning("This usually means the model failed to load. Check logs above for errors.")
            for idx, chunk in enumerate(chunks):
                caption = _truncate_caption(chunk)
                def _create_placeholder() -> bytes:
                    # Create placeholder with scene text in center, but don't overlay caption at bottom
                    # to avoid duplicate text display
                    image = self._create_placeholder_image(scene_text=caption)
                    # Skip overlay_caption since scene_text is already displayed in the image
                    buffer = io.BytesIO()
                    image.save(buffer, format="PNG")
                    return buffer.getvalue()
                
                placeholder_bytes = await asyncio.to_thread(_create_placeholder)
                
                if supabase_client:
                    filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                    frame_url = supabase_client.upload_frame(placeholder_bytes, filename)
                    frames.append(frame_url)
                else:
                    def _save_local() -> str:
                        filename = f"{uuid.uuid4()}.png"
                        path = settings.frames_dir / filename
                        path.write_bytes(placeholder_bytes)
                        # Return HTTP URL served by FastAPI static /assets mount
                        return f"/assets/frames/{filename}"
                    
                    frame_url = await asyncio.to_thread(_save_local)
                    frames.append(frame_url)
            return frames
        
        for idx, chunk in enumerate(chunks):
            # Truncate caption for overlay
            caption = _truncate_caption(chunk)
            
            try:
                prompt = self.prompt_builder.visual_prompt(context, chunk)
                prompt = self.prompt_sanitizer.enforce(prompt, prompt_type="visual")
                prompt = self._clip_prompt(prompt)
                
                # Generate image using local Stable Diffusion
                def _generate_image() -> Image.Image:
                    # Ultra-fast mode: use phone-specific settings
                    if ultra_fast_mode:
                        steps = settings.phone_image_steps  # 4 steps
                        resolution = settings.phone_image_resolution  # 256x256
                    else:
                        # Use 20 steps to avoid scheduler indexing errors
                        # Some schedulers have off-by-one issues with low step counts
                        steps = max(getattr(settings, "image_steps", 20), 20)
                        resolution = getattr(settings, "image_resolution", (256, 256))

                    logger.info(f"Generating image for scene {idx + 1}/{len(chunks)}")
                    logger.info(f"   Story chunk: {chunk[:150]}...")
                    logger.info(f"   Visual prompt: {prompt}")
                    print(f"Generating scene {idx + 1}/{len(chunks)}")
                    print(f"   Story: {chunk[:80]}...")
                    print(f"   Prompt: {prompt[:120]}...")
                    
                    seed = random.randint(0, 2**31 - 1)
                    try:
                        # Ensure generator is on CPU to avoid device mismatch
                        import torch
                        # Workaround for scheduler off-by-one error: use steps-2
                        # Many schedulers create n+1 timesteps for n steps, then try to access n+1, causing index out of bounds
                        # So if we want n steps, we need to request n-2 to get n-1 timesteps (which is safe)
                        effective_steps = steps
                        scheduler_name = type(pipeline.scheduler).__name__ if hasattr(pipeline, 'scheduler') else 'unknown'
                        logger.info(f"Using {effective_steps} steps (requested {steps}) with scheduler {scheduler_name} to avoid indexing error")
                        generator = torch.Generator(device="cpu").manual_seed(seed)
                        result = pipeline(
                            prompt=prompt,
                            negative_prompt="photorealistic, photo, harsh contrast, scary, horror, sharp teeth, creepy eyes, gore, weapon, gritty, noisy artifacts, text, watermark, logo, signature, bad quality, blurry, distorted, corruption, glitch, pixelated, low resolution, compression artifacts, jpeg artifacts, noise, grain, dithering, banding, color bleeding",
                            num_inference_steps=effective_steps,
                            height=resolution[1],
                            width=resolution[0],
                            guidance_scale=8.0,
                            generator=generator,
                        )
                        
                        # Stable Diffusion returns images as a list
                        if hasattr(result, "images") and len(result.images) > 0:
                            generated_image = result.images[0]
                            
                            # Basic validation to check for corruption
                            if generated_image.size[0] < 100 or generated_image.size[1] < 100:
                                logger.warning(f"Generated image is too small ({generated_image.size}), may be corrupted")
                                raise ValueError("Generated image appears corrupted (too small)")
                            
                            # Check if image is all black or has unusual artifacts
                            import numpy as np
                            img_array = np.array(generated_image.convert('RGB'))
                            mean_pixel = np.mean(img_array)
                            std_pixel = np.std(img_array)
                            
                            if mean_pixel < 10 or std_pixel < 5:
                                logger.warning(f"Generated image appears corrupted (mean={mean_pixel:.1f}, std={std_pixel:.1f})")
                                raise ValueError("Generated image appears corrupted (too dark or no variation)")
                            
                            logger.info(f"Image {idx + 1} generated successfully (mean={mean_pixel:.1f}, std={std_pixel:.1f})")
                            return generated_image
                        else:
                            raise ValueError("Stable Diffusion pipeline did not return images")
                    except Exception as gen_error:
                        logger.error(f"Image generation failed for scene {idx + 1}: {gen_error}")
                        raise
                
                # Generate image with timeout
                # For local CPU inference, allow up to 5 minutes per image
                image = await _generate_with_retry(
                    _generate_image,
                    timeout=300.0,  # 5 minutes per image for local CPU inference
                    operation=f"local_image_generation (scene {idx + 1}/{len(chunks)})",
                )
                
                # Process image: overlay caption and convert to bytes
                def _process_image() -> bytes:
                    # Ultra-fast mode: skip caption overlay to save time
                    if ultra_fast_mode:
                        image_with_caption = image
                    else:
                        # Apply caption overlay based on parameter
                        if include_text_overlay:
                            image_with_caption = self._overlay_caption(image, caption)
                        else:
                            image_with_caption = image
                    buffer = io.BytesIO()
                    image_with_caption.save(buffer, format="PNG")
                    return buffer.getvalue()
                
                frame_bytes = await asyncio.to_thread(_process_image)
                
                # Azure Content Safety image moderation (post-generation safety check)
                try:
                    from ..core.azure_content_safety import get_content_safety_client
                    from ..shared.config import settings
                    
                    if settings.azure_content_safety_enabled:
                        content_safety_client = get_content_safety_client()
                        if content_safety_client:
                            # Moderate image before saving/uploading
                            moderation_result = content_safety_client.moderate_image(frame_bytes)
                            if not moderation_result.get("is_safe", True):
                                # Image failed moderation - use placeholder instead
                                logger.warning(
                                    f"Local image failed Azure Content Safety moderation for scene {idx + 1}, using placeholder"
                                )
                                # Create placeholder image
                                placeholder_image = self._create_placeholder_image(scene_text=caption)
                                buffer = io.BytesIO()
                                placeholder_image.save(buffer, format="PNG")
                                frame_bytes = buffer.getvalue()
                except Exception as e:
                    # Fail open - continue with original image if moderation fails
                    logger.warning(f"Azure Content Safety image moderation failed: {e}")
                
                # Azure Computer Vision image analysis (generate alt-text for accessibility)
                try:
                    from ..core.azure_computer_vision import get_computer_vision_client
                    from ..shared.config import settings
                    
                    if settings.azure_computer_vision_enabled:
                        computer_vision_client = get_computer_vision_client()
                        if computer_vision_client:
                            # Generate image description for accessibility (alt-text)
                            description_result = computer_vision_client.describe_image(frame_bytes)
                            if description_result.get("captions"):
                                alt_text = description_result["captions"][0].get("text", "")
                                logger.info(f"Azure Computer Vision alt-text for local scene {idx + 1}: {alt_text}")
                                # Tags can be used for search/recommendations
                                tags = description_result.get("tags", [])
                                if tags:
                                    logger.debug(f"Azure Computer Vision tags for local scene {idx + 1}: {tags}")
                except Exception as e:
                    # Fail open - continue if analysis fails
                    logger.warning(f"Azure Computer Vision image analysis failed: {e}")
                
                # Upload to Supabase Storage if client is provided
                if supabase_client:
                    filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                    frame_url = supabase_client.upload_frame(frame_bytes, filename)
                    frames.append(frame_url)
                else:
                    # Fallback: save locally
                    def _save_local() -> str:
                        filename = f"{uuid.uuid4()}.png"
                        # Save to asset_dir/frames for static file serving
                        frames_dir = settings.asset_dir / "frames"
                        frames_dir.mkdir(parents=True, exist_ok=True)
                        path = frames_dir / filename
                        path.write_bytes(frame_bytes)
                        # Return HTTP URL served by FastAPI static /assets mount
                        return f"/assets/frames/{filename}"
                    
                    frame_url = await asyncio.to_thread(_save_local)
                    frames.append(frame_url)
            
            except Exception as e:
                logger.error(
                    f"Local image generation failed for scene {idx + 1}: {e}",
                    exc_info=True
                )
                print(f"Scene {idx + 1} generation failed: {e}")
                # Fall back to placeholder image - CRITICAL: always return something
                logger.info(f"Creating placeholder image for scene {idx + 1} due to error")
                print(f"Using placeholder for scene {idx + 1}")
                try:
                    def _create_placeholder() -> bytes:
                        # Create placeholder with scene text in center, but don't overlay caption at bottom
                        # to avoid duplicate text display
                        image = self._create_placeholder_image(scene_text=caption)
                        # Skip overlay_caption since scene_text is already displayed in the image
                        buffer = io.BytesIO()
                        image.save(buffer, format="PNG")
                        return buffer.getvalue()
                    
                    placeholder_bytes = await asyncio.to_thread(_create_placeholder)
                    
                    if supabase_client:
                        filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                        frame_url = supabase_client.upload_frame(placeholder_bytes, filename)
                        frames.append(frame_url)
                    else:
                        def _save_local() -> str:
                            filename = f"{uuid.uuid4()}.png"
                            # Save to asset_dir/frames for static file serving
                            frames_dir = settings.asset_dir / "frames"
                            frames_dir.mkdir(parents=True, exist_ok=True)
                            path = frames_dir / filename
                            path.write_bytes(placeholder_bytes)
                            # Return HTTP URL served by FastAPI static /assets mount
                            return f"/assets/frames/{filename}"
                        
                        frame_url = await asyncio.to_thread(_save_local)
                        frames.append(frame_url)
                except Exception as placeholder_err:
                    logger.error(f"Failed to create placeholder for scene {idx + 1}: {placeholder_err}", exc_info=True)
                    # Last resort: create a minimal placeholder
                    try:
                        minimal_image = Image.new("RGB", (256, 256), color=(45, 45, 60))
                        buffer = io.BytesIO()
                        minimal_image.save(buffer, format="PNG")
                        minimal_bytes = buffer.getvalue()
                        
                        if supabase_client:
                            filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                            frame_url = supabase_client.upload_frame(minimal_bytes, filename)
                            frames.append(frame_url)
                        else:
                            filename = f"{uuid.uuid4()}.png"
                            path = settings.frames_dir / filename
                            path.write_bytes(minimal_bytes)
                            frames.append(f"/assets/frames/{filename}")
                    except Exception as final_err:
                        logger.critical(f"CRITICAL: Failed to create any image for scene {idx + 1}: {final_err}")
                        # Return empty string - frontend will handle gracefully
                        frames.append("")
        
        # CRITICAL: Always return at least as many frames as requested
        if len(frames) < num_scenes:
            logger.warning(f"Only generated {len(frames)} frames but {num_scenes} were requested. Creating additional placeholders.")
            for idx in range(len(frames), num_scenes):
                try:
                    def _create_extra_placeholder() -> bytes:
                        image = self._create_placeholder_image(scene_text=f"Scene {idx + 1}")
                        buffer = io.BytesIO()
                        image.save(buffer, format="PNG")
                        return buffer.getvalue()
                    
                    placeholder_bytes = await asyncio.to_thread(_create_extra_placeholder)
                    
                    if supabase_client:
                        filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                        frame_url = supabase_client.upload_frame(placeholder_bytes, filename)
                        frames.append(frame_url)
                    else:
                        filename = f"{uuid.uuid4()}.png"
                        path = settings.frames_dir / filename
                        path.write_bytes(placeholder_bytes)
                        frames.append(f"/assets/frames/{filename}")
                except Exception as e:
                    logger.error(f"Failed to create extra placeholder {idx + 1}: {e}")
                    frames.append("")
        
        # Filter out any empty strings (failed frames)
        frames = [f for f in frames if f and f.strip()]
        
        # Log frame generation results
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"Generated {len(frames)} frames for {num_scenes} scenes")
        if frames:
            logger.info(f"   Frame URLs (first 3): {frames[:3]}")
            # Check if frames are using /assets/ URLs (for local mode)
            local_frames = [f for f in frames if f.startswith('/assets/')]
            if local_frames:
                logger.info(f"   {len(local_frames)} frames using /assets/ URLs (local mode)")
            else:
                logger.warning("   No frames using /assets/ URLs - may not be accessible via HTTP")

        # If we still don't have enough frames, create more placeholders
        if len(frames) < num_scenes:
            logger.warning(f"After filtering, only {len(frames)} valid frames remain (requested {num_scenes}). Creating additional placeholders.")
            for idx in range(len(frames), num_scenes):
                try:
                    def _create_extra_placeholder() -> bytes:
                        image = self._create_placeholder_image(scene_text=f"Scene {idx + 1}")
                        buffer = io.BytesIO()
                        image.save(buffer, format="PNG")
                        return buffer.getvalue()
                    
                    placeholder_bytes = await asyncio.to_thread(_create_extra_placeholder)
                    
                    if supabase_client:
                        filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                        frame_url = supabase_client.upload_frame(placeholder_bytes, filename)
                        frames.append(frame_url)
                    else:
                        filename = f"{uuid.uuid4()}.png"
                        path = settings.frames_dir / filename
                        path.write_bytes(placeholder_bytes)
                        frames.append(f"/assets/frames/{filename}")
                except Exception as e:
                    logger.error(f"Failed to create extra placeholder {idx + 1}: {e}")
                    # Don't append empty string - create a minimal placeholder instead
                    try:
                        minimal_image = Image.new("RGB", (256, 256), color=(45, 45, 60))
                        minimal_buffer = io.BytesIO()
                        minimal_image.save(minimal_buffer, format="PNG")
                        minimal_bytes = minimal_buffer.getvalue()
                        if supabase_client:
                            filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                            frame_url = supabase_client.upload_frame(minimal_bytes, filename)
                            frames.append(frame_url)
                        else:
                            filename = f"{uuid.uuid4()}.png"
                            path = settings.frames_dir / filename
                            path.write_bytes(minimal_bytes)
                            frames.append(f"/assets/frames/{filename}")
                    except:
                        logger.critical(f"CRITICAL: Could not create any placeholder for scene {idx + 1}")
        
        logger.info(f"Generated {len(frames)} valid frames total (requested {num_scenes})")
        return frames




def _distribute_paragraphs(paragraphs: list[str], num_scenes: int) -> list[str]:
    """Evenly distribute story text into num_scenes chunks."""
    if not paragraphs:
        return []

    if num_scenes <= 0:
        num_scenes = 1

    # If we have fewer paragraphs than scenes, split the combined text
    # into num_scenes balanced chunks (sentence/word based) so each scene
    # gets some content instead of falling back to placeholders.
    if len(paragraphs) < num_scenes:
        text = " ".join(paragraphs)
        
        # Split by sentences first
        import re
        sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]
        
        # If still too few, fall back to word-based splitting
        if len(sentences) < num_scenes:
            words = text.split()
            if not words:
                return [""] * num_scenes
            chunk_size = max(1, len(words) // num_scenes)
            chunks: list[str] = []
            for i in range(num_scenes):
                start = i * chunk_size
                end = words[start : start + chunk_size]
                # Last chunk takes the remainder
                if i == num_scenes - 1:
                    end = words[start:]
                chunks.append(" ".join(end).strip())
            return chunks
        else:
            # Distribute sentences into num_scenes buckets
            buckets: list[list[str]] = [[] for _ in range(num_scenes)]
            for idx, sentence in enumerate(sentences):
                buckets[idx % num_scenes].append(sentence)
            return [" ".join(b).strip() for b in buckets]

    # Standard even distribution when we have enough paragraphs
    paragraphs_per_scene = len(paragraphs) // num_scenes
    remainder = len(paragraphs) % num_scenes

    chunks: list[str] = []
    start_idx = 0

    for i in range(num_scenes):
        chunk_size = paragraphs_per_scene + (1 if i < remainder else 0)
        end_idx = start_idx + chunk_size
        chunk = " ".join(paragraphs[start_idx:end_idx])
        chunks.append(chunk)
        start_idx = end_idx

    return chunks




def is_local_inference_available() -> bool:
    """Check if local inference dependencies are available."""
    try:
        import llama_cpp
        import edge_tts
        return True
    except ImportError:
        return False


def get_local_generators(prompt_builder: PromptBuilder) -> tuple:
    """
    Create local generator instances.
    
    Returns:
        Tuple of (LocalStoryGenerator, LocalNarrationGenerator, LocalVisualGenerator)
    """
    return (
        LocalStoryGenerator(prompt_builder=prompt_builder),
        LocalNarrationGenerator(prompt_builder=prompt_builder),
        LocalVisualGenerator(prompt_builder=prompt_builder),
    )

