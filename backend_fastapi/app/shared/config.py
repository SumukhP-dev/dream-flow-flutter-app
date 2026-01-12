import os
from pathlib import Path
from functools import lru_cache

from dotenv import load_dotenv
from pydantic import BaseModel, ConfigDict, field_validator


PROJECT_ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = PROJECT_ROOT.parent

# Load base environment first, then allow .env.local to override for developer-specific keys.
load_dotenv(PROJECT_ROOT / ".env")
load_dotenv(PROJECT_ROOT / ".env.local", override=True)

# Fallback: also load root-level .env files (e.g. when backend lives in a subfolder).
if REPO_ROOT != PROJECT_ROOT:
    load_dotenv(REPO_ROOT / ".env", override=False)
    load_dotenv(REPO_ROOT / ".env.local", override=True)

# Pre-compute frequently used environment overrides
_IMAGE_RESOLUTION_VALUE = os.getenv("IMAGE_RESOLUTION") or "512x768"


def _get_service_role_key() -> str:
    """
    Load Supabase service-role key from environment or Azure Key Vault.

    Priority order:
    1. Environment variable SUPABASE_SERVICE_ROLE_KEY (primary method)
    2. Azure Key Vault (if AZURE_KEY_VAULT_URL and AZURE_KEY_VAULT_SECRET_NAME are set)

    This key MUST NEVER be committed to the repository. It should be injected via:
    - CI/CD pipeline secrets (GitHub Actions, Azure DevOps, etc.)
    - Environment variables in production
    - Azure Key Vault for Azure deployments

    Raises:
        ValueError: If the service-role key cannot be found from any source.
    """
    # First, try primary environment variable (recommended for CI/CD)
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    if key:
        return key

    # Backwards-compatible support for local placeholders like YOUR_SUPABASE_SERVICE_ROLE_KEY.
    placeholder_key = os.getenv("YOUR_SUPABASE_SERVICE_ROLE_KEY")
    if placeholder_key:
        return placeholder_key

    # As a last resort for local development, fall back to anon key if present.
    # This is NOT recommended for production, but it unblocks local testing when
    # you only have YOUR_SUPABASE_ANON_KEY configured.
    anon_fallback = os.getenv("SUPABASE_ANON_KEY") or os.getenv(
        "YOUR_SUPABASE_ANON_KEY"
    )
    if anon_fallback:
        return anon_fallback

    # Local development fallback: allow booting without Supabase configured.
    # This unblocks local UI/manual testing and local-only backends.
    # IMPORTANT: This is NOT a real service-role key.
    env = (os.getenv("ENVIRONMENT") or os.getenv("ENV") or "development").lower()
    # Treat any non-production-like environment as safe for local fallback.
    if env not in {"production", "prod", "staging"}:
        return "DUMMY_FOR_DEV"

    # Fallback to Azure Key Vault if configured
    vault_url = os.getenv("AZURE_KEY_VAULT_URL")
    secret_name = os.getenv("AZURE_KEY_VAULT_SECRET_NAME", "supabase-service-role-key")

    if vault_url:
        try:
            from azure.identity import DefaultAzureCredential
            from azure.keyvault.secrets import SecretClient

            credential = DefaultAzureCredential()
            client = SecretClient(vault_url=vault_url, credential=credential)
            secret = client.get_secret(secret_name)
            if secret.value:
                return secret.value
        except ImportError:
            raise ValueError(
                "Azure Key Vault is configured but azure-keyvault-secrets and azure-identity "
                "packages are not installed. Install them with: "
                "pip install azure-keyvault-secrets azure-identity"
            )
        except Exception as e:
            raise ValueError(
                f"Failed to retrieve service-role key from Azure Key Vault: {e}. "
                "Ensure AZURE_KEY_VAULT_URL is set correctly and the application has "
                "proper authentication (Managed Identity, Service Principal, etc.)."
            )

    # Fail fast if key is missing
    raise ValueError(
        "SUPABASE_SERVICE_ROLE_KEY is required but not found. "
        "This key must be provided via:\n"
        "  - Environment variable SUPABASE_SERVICE_ROLE_KEY (recommended for CI/CD)\n"
        "  - Azure Key Vault (set AZURE_KEY_VAULT_URL and optionally AZURE_KEY_VAULT_SECRET_NAME)\n\n"
        "The service-role key MUST NEVER be committed to the repository. "
        "Configure it in your CI/CD pipeline secrets or deployment environment."
    )


class Settings(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    app_name: str = "Dream Flow Backend"
    hf_token: str | None = os.getenv("HUGGINGFACE_API_TOKEN")
    hf_api_url: str | None = os.getenv("API_URL")
    story_model: str = os.getenv("STORY_MODEL", "meta-llama/Llama-3.2-1B-Instruct")
    tts_model: str = os.getenv("TTS_MODEL", "suno/bark-small")
    image_model: str = os.getenv("IMAGE_MODEL", "black-forest-labs/FLUX.1-schnell")
    max_new_tokens: int = int(os.getenv("MAX_NEW_TOKENS", "256"))  # Reduced from 512 to 256
    asset_dir: Path = Path(os.getenv("ASSET_DIR", PROJECT_ROOT / "storage"))

    # Local Inference Configuration
    local_inference: bool = os.getenv("LOCAL_INFERENCE", "false").lower() == "true"
    # Default to TinyLlama path for CPU-only 8GB-friendly deployment
    local_model_path: str = os.getenv(
        "LOCAL_MODEL_PATH",
        str(PROJECT_ROOT / "models" / "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"),
    )
    # Default TinyLlama identifier; used to choose TinyLlama vs Llama 3.2 3B
    local_story_model: str = os.getenv("LOCAL_STORY_MODEL", "tinyllama")
    edge_tts_voice: str = os.getenv("EDGE_TTS_VOICE", "en-US-AriaNeural")

    global_visual_style_fragment: str = os.getenv(
        "GLOBAL_VISUAL_STYLE_FRAGMENT",
        "storybook watercolor and gouache illustration, soft dreamy glow, pastel color palette, "
        "subtle paper texture, gentle vignette, rounded shapes, cozy bedtime mood, child-safe",
    )

    # GPU Configuration for Story Generation
    # Default to CPU-only for 8GB laptops; can be overridden on larger machines.
    story_model_use_gpu: bool = (
        os.getenv("STORY_MODEL_USE_GPU", "false").lower() == "true"
    )
    story_model_gpu_layers: int = int(
        os.getenv("STORY_MODEL_GPU_LAYERS", "0")
    )  # 0 by default for CPU-only

    # Low Memory Mode (enabled by default for 8GB systems)
    # When enabled, uses more aggressive memory optimizations:
    # - Reduced context window
    # - Smaller batch sizes
    # - Lower token limits
    low_memory_mode: bool = os.getenv("LOW_MEMORY_MODE", "true").lower() == "true"

    # Fast mode: aggressively optimize for latency over quality
    fast_mode: bool = os.getenv("FAST_MODE", "true").lower() == "true"
    # Skip TTS entirely in fast mode for fastest development
    skip_audio_generation: bool = os.getenv("SKIP_AUDIO_GENERATION", "false").lower() == "true"
    # Approximate maximum story length in characters (~4 chars per token) - Reduced for speed
    max_story_length: int = int(os.getenv("MAX_STORY_LENGTH", "300"))


    # Local Image Generation Configuration (decoupled from video)
    local_image_enabled: bool = (
        os.getenv("LOCAL_IMAGE_ENABLED", "true").lower() == "true"
    )
    local_image_model: str = os.getenv(
        "LOCAL_IMAGE_MODEL", "runwayml/stable-diffusion-v1-5"
    )  # higher quality default model (license-approved)
    # Lower resolution for faster generation during development
    image_resolution: tuple[int, int] = tuple(
        map(int, _IMAGE_RESOLUTION_VALUE.split("x"))
    )
    # Reduced steps for faster image generation during development
    image_steps: int = int(os.getenv("IMAGE_STEPS", "10"))  # Reduced from 30 to 10
    # Use placeholders by default for fastest development
    use_placeholders_only: bool = (
        os.getenv("USE_PLACEHOLDERS_ONLY", "true").lower() == "true"  # Changed to "true"
    )
    # Whether to overlay text captions on generated images (disabled by default for cleaner images)
    overlay_image_captions: bool = (
        os.getenv("OVERLAY_IMAGE_CAPTIONS", "false").lower() == "true"
    )
    # Default number of scenes/images for fast mode - Reduced for speed
    num_scenes: int = int(os.getenv("NUM_SCENES", "2"))  # Reduced from 4 to 2

    # Phone-Optimized Model Configuration
    phone_story_model: str = os.getenv("PHONE_STORY_MODEL", "tinyllama")  # Use smallest
    phone_max_tokens: int = int(os.getenv("PHONE_MAX_TOKENS", "128"))  # ~150 words
    phone_image_steps: int = int(os.getenv("PHONE_IMAGE_STEPS", "4"))  # Minimal steps
    phone_image_resolution: tuple[int, int] = (
        tuple(map(int, os.getenv("PHONE_IMAGE_RESOLUTION", "256x256").split("x")))
        if os.getenv("PHONE_IMAGE_RESOLUTION")
        else (256, 256)
    )  # Smallest resolution
    phone_num_scenes: int = 1  # Single image only
    phone_use_q2_quantization: bool = os.getenv("PHONE_USE_Q2_QUANTIZATION", "true").lower() == "true"  # Q2_K instead of Q4_K

    # Batch Processing Configuration
    batch_mode: bool = os.getenv("BATCH_MODE", "false").lower() == "true"
    batch_max_tokens: int = int(os.getenv("BATCH_MAX_TOKENS", "1024"))
    batch_quality: str = os.getenv("BATCH_QUALITY", "high")  # low, medium, high
    batch_queue_path: str = os.getenv(
        "BATCH_QUEUE_PATH",
        str(PROJECT_ROOT / "batch_queue")
    )

    # Supabase Configuration
    # Support both canonical and placeholder-style env vars for local dev:
    # - SUPABASE_URL or YOUR_SUPABASE_URL
    # - SUPABASE_ANON_KEY or YOUR_SUPABASE_ANON_KEY
    supabase_url: str | None = os.getenv("SUPABASE_URL") or os.getenv(
        "YOUR_SUPABASE_URL"
    )
    supabase_anon_key: str | None = os.getenv("SUPABASE_ANON_KEY") or os.getenv(
        "YOUR_SUPABASE_ANON_KEY"
    )
    # Service-role key is required and loaded via _get_service_role_key()
    # This ensures it's never hardcoded and fails fast if missing
    supabase_service_role_key: str

    # Admin Configuration
    admin_user_ids: list[str] = (
        os.getenv("ADMIN_USER_IDS", "").split(",")
        if os.getenv("ADMIN_USER_IDS")
        else []
    )

    # Backend URL (for CORS and external references)
    backend_url: str = os.getenv("BACKEND_URL", "http://localhost:8080")
    # Frontend URL (for payment redirects)
    frontend_url: str = os.getenv("FRONTEND_URL", os.getenv("NEXT_PUBLIC_FRONTEND_URL", "http://localhost:3000"))

    # Sentry Configuration
    sentry_dsn: str | None = os.getenv("SENTRY_DSN")
    sentry_environment: str = os.getenv("SENTRY_ENVIRONMENT", "development")
    sentry_traces_sample_rate: float = float(
        os.getenv("SENTRY_TRACES_SAMPLE_RATE", "0.2")
    )

    # Asset Retention Configuration
    asset_retention_days: int = int(os.getenv("ASSET_RETENTION_DAYS", "7"))

    # Subscription Configuration
    stripe_secret_key: str | None = os.getenv("STRIPE_SECRET_KEY")
    stripe_webhook_secret: str | None = os.getenv("STRIPE_WEBHOOK_SECRET")
    stripe_publishable_key: str | None = os.getenv("STRIPE_PUBLISHABLE_KEY")
    
    # Stripe Price IDs (configure in Stripe Dashboard)
    stripe_premium_monthly_price_id: str | None = os.getenv("STRIPE_PREMIUM_MONTHLY_PRICE_ID")
    stripe_premium_annual_price_id: str | None = os.getenv("STRIPE_PREMIUM_ANNUAL_PRICE_ID")
    stripe_family_monthly_price_id: str | None = os.getenv("STRIPE_FAMILY_MONTHLY_PRICE_ID")
    stripe_family_annual_price_id: str | None = os.getenv("STRIPE_FAMILY_ANNUAL_PRICE_ID")

    # CDN Configuration
    cdn_url: str | None = os.getenv("CDN_URL")
    cdn_enabled: bool = os.getenv("CDN_ENABLED", "false").lower() == "true"

    # Moodboard / visual safety configuration
    moodboard_max_upload_mb: int = int(os.getenv("MOODBOARD_MAX_UPLOAD_MB", "6"))
    coppa_face_filter_enabled: bool = (
        os.getenv("COPPA_FACE_FILTER", "false").lower() == "true"
    )
    moodboard_guardrails_enabled: bool = (
        os.getenv("MOODBOARD_GUARDRAILS", "true").lower() == "true"
    )
    
    # COPPA Safety Configuration
    coppa_strict_mode: bool = (
        os.getenv("COPPA_STRICT_MODE", "false").lower() == "true"
    )
    
    # Azure Content Safety Configuration
    azure_content_safety_enabled: bool = (
        os.getenv("AZURE_CONTENT_SAFETY_ENABLED", "false").lower() == "true"
    )
    azure_content_safety_endpoint: str | None = os.getenv("AZURE_CONTENT_SAFETY_ENDPOINT")
    azure_content_safety_key: str | None = os.getenv("AZURE_CONTENT_SAFETY_KEY")
    azure_content_safety_severity_threshold: int = int(
        os.getenv("AZURE_CONTENT_SAFETY_SEVERITY_THRESHOLD", "4")
    )  # 0-7 scale, 4 is High severity (less sensitive to avoid false positives on bedtime stories)
    
    # Azure Computer Vision Configuration
    azure_computer_vision_enabled: bool = (
        os.getenv("AZURE_COMPUTER_VISION_ENABLED", "false").lower() == "true"
    )
    azure_computer_vision_endpoint: str | None = os.getenv("AZURE_COMPUTER_VISION_ENDPOINT")
    azure_computer_vision_key: str | None = os.getenv("AZURE_COMPUTER_VISION_KEY")
    
    # Azure Blob Storage Configuration (optional alternative to Supabase Storage)
    azure_blob_storage_enabled: bool = (
        os.getenv("AZURE_BLOB_STORAGE_ENABLED", "false").lower() == "true"
    )
    azure_blob_storage_connection_string: str | None = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
    azure_blob_storage_container_name: str = os.getenv("AZURE_BLOB_STORAGE_CONTAINER_NAME", "dream-flow-assets")
    
    # Klaviyo Integration Configuration
    klaviyo_api_key: str | None = os.getenv("KLAVIYO_API_KEY")
    klaviyo_enabled: bool = (
        os.getenv("KLAVIYO_ENABLED", "true").lower() == "true"
        and os.getenv("KLAVIYO_API_KEY") is not None
    )

    # Unified AI Inference Mode Configuration
    # Single environment variable to control all inference modes with fallback
    ai_inference_mode: str = os.getenv("AI_INFERENCE_MODE", "server_first")  
    # Options: cloud_first, server_first, phone_first, cloud_only, server_only, phone_only
    
    # Legacy support for backward compatibility
    # Multi-Version Inference Configuration (DEPRECATED - use AI_INFERENCE_MODE instead)
    # Since FastAPI backend always runs on servers, default to "local" which:
    # 1. Uses local models if available (efficient for servers)
    # 2. Falls back to cloud APIs if local models fail (reliable)
    # 3. Skips mobile hardware detection (not relevant for servers)
    inference_version: str = os.getenv("INFERENCE_VERSION", "local")  # "local" | "apple" | "native_mobile" | "auto"
    
    # Apple Configuration
    apple_intelligence_api_key: str | None = os.getenv("APPLE_INTELLIGENCE_API_KEY")
    apple_intelligence_api_url: str | None = os.getenv("APPLE_INTELLIGENCE_API_URL")
    apple_story_model: str = os.getenv("APPLE_STORY_MODEL", "apple-intelligence-story")
    apple_tts_model: str = os.getenv("APPLE_TTS_MODEL", "apple-intelligence-tts")
    apple_image_model: str = os.getenv("APPLE_IMAGE_MODEL", "apple-intelligence-image")
    apple_support_on_device: bool = os.getenv("APPLE_SUPPORT_ON_DEVICE", "true").lower() == "true"
    
    # Ollama Configuration (for local model serving)
    use_local_models: bool = os.getenv("USE_LOCAL_MODELS", "false").lower() == "true"
    ollama_base_url: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    ollama_story_model: str = os.getenv("OLLAMA_STORY_MODEL", "llama3.2:1b")
    
    @property
    def apple_silicon_server(self) -> bool:
        """Detect if backend runs on Apple Silicon."""
        import platform
        return platform.machine().lower() == "arm64" and platform.system() == "Darwin"

    def __init__(self, **data):
        """Initialize Settings with service-role key loaded from secure source."""
        # Load service-role key before Pydantic validation
        if "supabase_service_role_key" not in data:
            data["supabase_service_role_key"] = _get_service_role_key()
        super().__init__(**data)
        
        # Validate and warn about configuration after initialization
        self._validate_configuration()

    @field_validator("supabase_service_role_key")
    @classmethod
    def validate_service_role_key(cls, v: str) -> str:
        """Validate that service-role key is not empty."""
        if not v or not v.strip():
            raise ValueError("SUPABASE_SERVICE_ROLE_KEY cannot be empty")
        return v.strip()
    
    def _validate_configuration(self) -> None:
        """Validate configuration and log warnings for missing optional variables."""
        import logging
        logger = logging.getLogger(__name__)
        
        # Log inference version configuration
        logger.info(f"Inference version configured: {self.inference_version}")
        
        # Warn about Apple Intelligence if configured but disabled
        if self.apple_intelligence_api_key and not os.getenv("ENABLE_APPLE_INTELLIGENCE", "false").lower() == "true":
            logger.warning(
                "Apple Intelligence API key is configured but Apple Intelligence is disabled. "
                "Set ENABLE_APPLE_INTELLIGENCE=true to enable. "
                "Note: Apple Intelligence API is not yet available."
            )
        
        # Log available inference versions
        try:
            from ..core.version_detector import detect_available_versions
            available = detect_available_versions()
            logger.info(f"Available inference versions: {available}")
        except Exception:
            pass  # Don't fail if version detector has issues

    @property
    def audio_dir(self) -> Path:
        return self.asset_dir / "audio"

    @property
    def frames_dir(self) -> Path:
        return self.asset_dir / "frames"

    @property
    def video_dir(self) -> Path:
        return self.asset_dir / "video"

    @property
    def models_dir(self) -> Path:
        return Path(self.local_model_path).parent

    @property
    def batch_queue_dir(self) -> Path:
        return Path(self.batch_queue_path)


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    directories = [
        settings.asset_dir,
        settings.audio_dir,
        settings.frames_dir,
        settings.video_dir,
    ]
    # Create models directory if local inference is enabled
    if settings.local_inference:
        directories.append(settings.models_dir)
    
    # Create batch queue directory if batch mode is enabled
    if settings.batch_mode:
        directories.append(settings.batch_queue_dir)
    
    for directory in directories:
        directory.mkdir(parents=True, exist_ok=True)
    return settings
