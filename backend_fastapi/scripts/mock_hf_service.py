"""
Mock HuggingFace Inference API Service
Simulates the HuggingFace Inference API for local development.
Matches the structure of https://router.huggingface.co (api-inference.huggingface.co is deprecated)
"""
import os
import base64
import io
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, Response
import numpy as np
from PIL import Image, ImageDraw
import json

app = FastAPI(title="Mock HuggingFace Inference API")


@app.get("/")
async def root():
    return {"message": "Mock HuggingFace Inference API"}


@app.post("/models/{model_id:path}")
async def inference(model_id: str, request: Request):
    """
    Mock inference endpoint that mimics HuggingFace Inference API.
    Supports text generation, text-to-audio, and text-to-image.
    Matches the endpoint structure: POST /models/{model_id}
    """
    try:
        body = await request.json()
    except:
        body = {}
    
    # Determine task type from model_id
    if "llama" in model_id.lower() or "story" in model_id.lower() or "text" in model_id.lower():
        # Text generation - HuggingFace API uses the model endpoint directly
        prompt = body.get("inputs", "")
        if isinstance(prompt, list):
            prompt = prompt[0] if prompt else ""
        parameters = body.get("parameters", {})
        max_new_tokens = parameters.get("max_new_tokens", 100)
        
        # Generate mock story text
        mock_story = (
            f"[MOCK STORY] Based on the prompt: '{prompt[:50] if prompt else 'default'}...', "
            "here is a soothing bedtime story. "
            "Once upon a time, in a peaceful land far away, "
            "there lived a gentle character who loved to explore. "
        ) * (max_new_tokens // 50)
        
        return JSONResponse(content={"generated_text": mock_story[:max_new_tokens]})
    
    elif "bark" in model_id.lower() or "tts" in model_id.lower() or "audio" in model_id.lower():
        # Text-to-audio - return mock WAV file
        text = body.get("inputs", "")
        if isinstance(text, list):
            text = text[0] if text else ""
        parameters = body.get("parameters", {})
        voice = parameters.get("voice", "alloy")
        
        # Generate a simple mock audio (silence with metadata)
        sample_rate = 22050
        duration = 2.0  # 2 seconds
        samples = int(sample_rate * duration)
        
        # Generate silence (zeros) as mock audio
        audio_data = np.zeros(samples, dtype=np.float32)
        
        # Convert to bytes (simple WAV format)
        wav_header = (
            b'RIFF' + (36 + len(audio_data) * 2).to_bytes(4, 'little') +
            b'WAVE' + b'fmt ' + (16).to_bytes(4, 'little') +
            (1).to_bytes(2, 'little') + (1).to_bytes(2, 'little') +
            sample_rate.to_bytes(4, 'little') +
            (sample_rate * 2).to_bytes(4, 'little') +
            (2).to_bytes(2, 'little') + (16).to_bytes(2, 'little') +
            b'data' + (len(audio_data) * 2).to_bytes(4, 'little')
        )
        
        audio_bytes = wav_header + audio_data.tobytes()
        
        return Response(content=audio_bytes, media_type="audio/wav")
    
    elif "flux" in model_id.lower() or "image" in model_id.lower() or "stable-diffusion" in model_id.lower():
        # Text-to-image - return mock image
        prompt = body.get("inputs", "")
        if isinstance(prompt, list):
            prompt = prompt[0] if prompt else ""
        
        # Generate a simple colored image
        width, height = 512, 512
        img = Image.new('RGB', (width, height), color=(135, 206, 250))  # Sky blue
        
        # Add some simple pattern
        draw = ImageDraw.Draw(img)
        draw.ellipse([100, 100, 400, 400], fill=(255, 255, 200), outline=(255, 200, 100), width=5)
        
        # Convert to bytes
        img_bytes = io.BytesIO()
        img.save(img_bytes, format='PNG')
        img_bytes.seek(0)
        
        return JSONResponse(content={
            "image": base64.b64encode(img_bytes.read()).decode('utf-8')
        })
    
    else:
        # Default to text generation for unknown models
        prompt = body.get("inputs", "")
        if isinstance(prompt, list):
            prompt = prompt[0] if prompt else ""
        parameters = body.get("parameters", {})
        max_new_tokens = parameters.get("max_new_tokens", 100)
        mock_text = f"[MOCK] Generated text for: {prompt[:50] if prompt else 'default'}" * (max_new_tokens // 50)
        return JSONResponse(content={"generated_text": mock_text[:max_new_tokens]})


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8001))
    uvicorn.run(app, host="0.0.0.0", port=port)

