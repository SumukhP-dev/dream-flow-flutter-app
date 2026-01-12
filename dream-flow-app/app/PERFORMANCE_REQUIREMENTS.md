# Model Performance Requirements

## Constraints

### Runtime Requirements
- **Total time per story**: ≤30 seconds (including all components)
- **Parallel execution**: Images and audio must run in parallel
- **CPU-only**: Optimized for devices without Tensor/Neural Engine chips

### Storage Requirements
- **Total model size**: ≤1.2GB (must fit on phone)
- **Story model**: ≤100MB (optimized for fast loading)
- **Image models**: ≤1GB total

### Performance Targets

| Component | Target Time | Notes |
|-----------|-------------|-------|
| Story Generation | <10 seconds | Sequential, must complete first |
| Image Generation | <20 seconds | Runs in parallel with audio (4 images) |
| Audio Generation | <5 seconds | Runs in parallel with images |
| **Total** | **≤30 seconds** | With parallel execution |

## Model Selection

### Story Generation Models (Choose Fastest Available)

**Recommended (fastest to slowest):**

1. **GPT-2 Tiny** (28M params, ~30MB quantized)
   - Fastest option
   - Good quality for bedtime stories
   - Target: ~5-8 seconds per story

2. **MobileBERT** (25M params, ~25MB quantized)
   - Alternative fast option
   - Target: ~6-9 seconds per story

3. **DistilGPT-2** (82M params, ~50MB quantized)
   - Fallback if faster models unavailable
   - Target: ~8-12 seconds per story

### Image Generation Models

**Requirements:**
- Must generate 4 images in <20 seconds total
- ~5 seconds per image
- Can run in parallel with audio

**Recommended:**
- **Stable Diffusion Turbo Lite** (smallest variant, ~800MB)
- Quantized models for faster inference
- Reduced resolution (384x384 instead of 512x512)
- Fewer inference steps (10 instead of 20)

### Audio Generation

✅ **Native TTS APIs** (no model needed)
- iOS: AVSpeechSynthesizer
- Android: Android TTS API
- Target: <5 seconds
- Already optimized

## Optimization Strategies

### 1. Model Size Reduction
- Use INT8 quantization (4x size reduction)
- Choose smaller model variants
- Remove unnecessary components

### 2. Inference Speed
- Reduce max tokens for story generation (200 instead of 400)
- Reduce image resolution (384x384 instead of 512x512)
- Reduce inference steps (10 instead of 20)
- Use CPU-optimized model formats

### 3. Parallel Execution
- Story generation: Sequential (must complete first)
- Images + Audio: Run in parallel using `Future.wait()`
- Overlaps execution to reduce total time

### 4. Caching
- Cache generated stories
- Pre-load models on app start
- Reuse model instances

## Implementation

The app uses `ParallelGenerationService` to coordinate parallel execution:

```dart
// Sequential: Story generation (~8s)
final story = await generateStory(...);

// Parallel: Images + Audio (overlapped, ~20s max)
final results = await Future.wait([
  generateImages(...),  // ~20s
  generateAudio(...),   // ~5s (overlaps)
]);
```

Total time: ~25-30 seconds (meets requirement)

## Monitoring

The service logs generation times:
- Story generation time
- Parallel generation time
- Total time
- Warnings if exceeds 30s target

Check logs to verify performance targets are met.

## Model Configuration

Current settings in `model_config.dart`:
- Story model: GPT-2 Tiny (optimized for speed)
- Image model: Stable Diffusion Turbo Lite
- Reduced sizes and inference parameters

Update model choices if performance targets are not met.

