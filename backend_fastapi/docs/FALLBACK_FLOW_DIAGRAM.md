# AI Inference Fallback Flow Diagram

## Two-Level Fallback Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     APPLICATION STARTUP                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                   ┌──────────────────────┐
                   │  Read AI_INFERENCE   │
                   │  _MODE Configuration │
                   └──────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
        ┌─────────┐     ┌─────────┐     ┌─────────┐
        │  cloud  │     │  server │     │  phone  │
        │  _first │     │  _first │     │  _first │
        └─────────┘     └─────────┘     └─────────┘
              │               │               │
              └───────────────┼───────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              LEVEL 1: INITIALIZATION FALLBACK                    │
│                 (get_generators function)                        │
└─────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            │ Try each in fallback_chain order │
            └─────────────────┬─────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   ┌─────────┐          ┌─────────┐          ┌─────────┐
   │  Cloud  │          │  Local  │          │  Mobile │
   │   HF    │          │  GGUF   │          │ TFLite  │
   └─────────┘          └─────────┘          └─────────┘
        │                     │                     │
        │                     │                     │
   ┌────┴────┐           ┌────┴────┐           ┌────┴────┐
   │SUCCESS? │           │SUCCESS? │           │SUCCESS? │
   └────┬────┘           └────┬────┘           └────┬────┘
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │ First Success     │
                    │ OR                │
                    │ Raise Error       │
                    └─────────┬─────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    GENERATORS INITIALIZED                        │
│              (story_gen, narration_gen, visual_gen)             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   STORY GENERATION REQUEST                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                   ┌──────────────────────┐
                   │  Try Primary         │
                   │  story_gen.generate()│
                   └──────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │    SUCCESS?       │
                    └─────────┬─────────┘
                    YES │     │ NO
                        │     │
                        │     ▼
                        │ ┌───────────────────────────────────┐
                        │ │  LEVEL 2: RUNTIME FALLBACK        │
                        │ │  (_get_fallback_story_generator)  │
                        │ └───────────────────────────────────┘
                        │                  │
                        │     ┌────────────┴────────────┐
                        │     │ Check allow_fallback    │
                        │     └────────────┬────────────┘
                        │                  │
                        │         ┌────────┴────────┐
                        │         │ Fallback        │
                        │         │ Enabled?        │
                        │         └────────┬────────┘
                        │         YES │    │ NO
                        │             │    │
                        │             │    └──> RAISE ERROR
                        │             │
                        │             ▼
                        │    ┌─────────────────────┐
                        │    │ Try Next in Chain   │
                        │    │ (skip failed one)   │
                        │    └─────────────────────┘
                        │             │
                        │    ┌────────┴────────┐
                        │    │ Generator       │
                        │    │ Available?      │
                        │    └────────┬────────┘
                        │    YES │    │ NO
                        │        │    │
                        │        │    └──> Try Next → ... → None
                        │        │
                        │        ▼
                        │  ┌──────────────────┐
                        │  │ Use Fallback     │
                        │  │ Generator        │
                        │  └──────────────────┘
                        │        │
                        └────────┴─────────┐
                                           │
                                           ▼
                                  ┌────────────────┐
                                  │  Story Text    │
                                  │  Generated     │
                                  └────────────────┘
                                           │
                    ┌──────────────────────┴──────────────────────┐
                    │                                             │
                    ▼                                             ▼
        ┌───────────────────────┐                   ┌───────────────────────┐
        │ NARRATION GENERATION  │                   │  VISUAL GENERATION    │
        │                       │                   │                       │
        │ Try narration_gen     │                   │ Try visual_gen        │
        │   ↓                   │                   │   ↓                   │
        │ Fails?                │                   │ Fails?                │
        │   ↓                   │                   │   ↓                   │
        │ _get_fallback_        │                   │ _get_fallback_        │
        │ narration_generator   │                   │ visual_generator      │
        │   ↓                   │                   │   ↓                   │
        │ Try fallback chain    │                   │ Try fallback chain    │
        │   ↓                   │                   │   ↓                   │
        │ Return audio or ""    │                   │ Try placeholders      │
        │ (audio optional)      │                   │   ↓                   │
        │                       │                   │ Return frames         │
        └───────────────────────┘                   └───────────────────────┘
                    │                                             │
                    └──────────────────┬──────────────────────────┘
                                       │
                                       ▼
                            ┌──────────────────┐
                            │  COMPLETE STORY  │
                            │  (text + audio   │
                            │   + frames)      │
                            └──────────────────┘
```

## Fallback Chain Examples

### Mode: cloud_first

```
INITIALIZATION:
Cloud HF → Local GGUF → Native Mobile
   ✓

RUNTIME (if Cloud fails):
Story:     Cloud HF (failed) → Local GGUF → Native Mobile
Narration: Cloud HF (failed) → Local GGUF → Native Mobile → Return ""
Visual:    Cloud HF (failed) → Local GGUF → Native Mobile → Placeholders
```

### Mode: server_first (default)

```
INITIALIZATION:
Local GGUF → Cloud HF → Native Mobile
   ✓

RUNTIME (if Local fails):
Story:     Local GGUF (failed) → Cloud HF → Native Mobile
Narration: Local GGUF (failed) → Cloud HF → Native Mobile → Return ""
Visual:    Local GGUF (failed) → Cloud HF → Native Mobile → Placeholders
```

### Mode: cloud_only

```
INITIALIZATION:
Cloud HF
   ✓

RUNTIME (if Cloud fails):
Story:     Cloud HF (failed) → ❌ RAISE ERROR (fallback disabled)
Narration: Cloud HF (failed) → ❌ RAISE ERROR (fallback disabled)
Visual:    Cloud HF (failed) → ❌ RAISE ERROR (fallback disabled)
```

## Provider Capabilities

| Provider | Story | Narration | Visual | Speed | Privacy |
|----------|-------|-----------|--------|-------|---------|
| Cloud HF | ✓ | ✓ | ✓ | Fast (5-10s) | Low |
| Local GGUF | ✓ | ✓ (edge-tts) | ✓ (SD) | Slow (60s+) | High |
| Native Mobile | ✓ | ✓ | ✓ | Medium | High |
| Apple | ✓ | ✓ | ✓ | Fast | High |
| Placeholders | ✗ | ✗ | ✓ | Instant | N/A |

## Decision Tree: Which Mode to Use?

```
                    ┌─────────────────────┐
                    │ Need guaranteed     │
                    │ fast performance?   │
                    └──────────┬──────────┘
                          YES  │  NO
                               │
              ┌────────────────┴────────────────┐
              │                                 │
              ▼                                 ▼
     ┌─────────────────┐              ┌─────────────────┐
     │ Have HF token?  │              │ Privacy         │
     │                 │              │ priority?       │
     └────────┬────────┘              └────────┬────────┘
         YES  │  NO                       YES  │  NO
              │                                │
              ▼                                │
     ┌─────────────────┐              ┌───────┴────────┐
     │  cloud_first    │              │                │
     │  (recommended)  │              ▼                ▼
     └─────────────────┘    ┌──────────────┐  ┌──────────────┐
                            │ server_only  │  │ server_first │
                            │              │  │  (default)   │
                            └──────────────┘  └──────────────┘
```

## Error Handling Flow

```
┌────────────────┐
│ Generation     │
│ Attempt        │
└────────┬───────┘
         │
    ┌────┴────┐
    │ ERROR?  │
    └────┬────┘
    YES  │  NO → Success
         │
         ▼
┌─────────────────┐
│ Check fallback  │
│ allowed?        │
└────────┬────────┘
         │
    ┌────┴────┐
    │ YES     │  NO → Raise HTTPException
    │         │
    ▼         ▼
┌─────────────────┐
│ Try fallback    │
│ generator       │
└────────┬────────┘
         │
    ┌────┴────┐
    │ SUCCESS?│
    └────┬────┘
    YES  │  NO
         │   └──────> Try next in chain
         │                    │
         ▼                    │
   ┌──────────┐               │
   │ Continue │ <─────────────┘
   │ with     │      (or exhaust chain)
   │ result   │
   └──────────┘
         │
         ▼
   ┌──────────┐
   │ SUCCESS  │
   └──────────┘
```

## Configuration Matrix

| Mode | Primary | Fallback 1 | Fallback 2 | Use Case |
|------|---------|------------|------------|----------|
| cloud_first | Cloud | Local | Mobile | Production (fast + reliable) |
| server_first | Local | Cloud | Mobile | Dev (privacy + fallback) |
| phone_first | Mobile | Local | Cloud | Mobile app (offline-first) |
| cloud_only | Cloud | - | - | Production (fast only) |
| server_only | Local | - | - | Privacy-critical |
| phone_only | Mobile | - | - | Offline mobile app |

---

**Legend:**
- ✓ = Success, continue
- ❌ = Failure, stop
- → = Fallback attempt
- "" = Return empty (graceful degradation)
