# Unit Tests for Dream Flow Backend

This directory contains comprehensive unit tests for all features implemented in the 5 main tasks.

## Test Files

### 1. `test_prompting.py` (Existing)
Tests for PromptBuilder and StoryGenerator:
- PromptContext profile snippet generation
- PromptBuilder prompt generation (story, narration, visual)
- StoryGenerator with different contexts and profiles
- Brand rules and tone enforcement

### 2. `test_services.py` (New)
Tests for service generators and utility functions:

#### TestDistributeParagraphs
- Even distribution of paragraphs across scenes
- Handling remainder paragraphs
- Edge cases (empty, fewer paragraphs than scenes, zero scenes)

#### TestTruncateCaption
- Caption truncation with ellipsis
- Short text handling
- Exact length handling

#### TestRunWithRetry
- Successful execution on first attempt
- Retry on connection errors
- Timeout error handling
- Rate limit error retry
- Max retries exceeded

#### TestVisualGenerator
- Frame creation with Supabase upload (returns signed URLs)
- Frame creation without Supabase (fallback to local paths)
- Placeholder fallback on HuggingFace errors
- Scene chunking functionality
- Timeout handling
- Placeholder image creation
- Caption overlay

#### TestNarrationGenerator
- Audio synthesis with Supabase upload
- Audio synthesis without Supabase (fallback)
- Timeout handling
- Retry on connection errors

#### TestStoryGeneratorTimeout
- Timeout error handling
- Retry on connection errors

### 3. `test_supabase_client.py` (New)
Tests for SupabaseClient operations:

#### TestSupabaseClientInitialization
- Valid settings initialization
- Missing URL error handling
- Missing service role key error handling

#### TestSupabaseClientSessions
- Session creation
- Getting session by ID
- Getting user sessions with pagination

#### TestSupabaseClientSessionAssets
- Creating single session asset
- Creating multiple assets in batch
- Invalid asset type error handling
- Getting session assets
- Filtering assets by type

#### TestSupabaseClientStorage
- File upload to storage
- Getting signed URLs
- Audio upload (returns signed URL)
- Video upload (returns signed URL)
- Frame upload (returns signed URL)
- Error handling for signed URL generation

#### TestSupabaseClientProfile
- Profile upsert operation

### 4. `test_story_pipeline_regression.py` (New)
Regression harness for story pipeline:

#### Regression Tests
- Runs ~10 canned prompts through mocked generators
- Catches drift in:
  - **Tone**: Brand tone keywords, guardrail violations, exclamation points, all caps
  - **Length**: Word count vs target_length (within expected ranges)
  - **Scene counts**: Number of frames generated vs expected num_scenes
- Deterministic mock story generation based on input parameters
- Comprehensive metrics collection for each test case

#### Usage
```bash
# Run all regression tests
pytest tests/test_story_pipeline_regression.py -v

# Run specific test
pytest tests/test_story_pipeline_regression.py::test_regression_harness -v

# Run via CLI script
python run_regression_harness.py
python run_regression_harness.py --verbose
python run_regression_harness.py --prompt ocean_adventure
python run_regression_harness.py --json
```

### 5. `test_main_integration.py` (New)
Integration tests for the main FastAPI endpoint:

#### TestStoryGenerationEndpoint
- Full story generation with Supabase persistence
- Story generation without user_id (no persistence)
- Timeout error handling
- Guardrail violation handling
- Persistence error doesn't fail request
- Missing HuggingFace token error
- Health endpoint

#### TestStoryGenerationWithChunking
- Story generation with multiple scenes (chunking)
- Session assets include all frames

## Running Tests

### Run all tests:
```bash
pytest tests/ -v
```

### Run specific test file:
```bash
pytest tests/test_services.py -v
pytest tests/test_supabase_client.py -v
pytest tests/test_main_integration.py -v
pytest tests/test_prompting.py -v
```

### Run specific test class:
```bash
pytest tests/test_services.py::TestVisualGenerator -v
```

### Run specific test:
```bash
pytest tests/test_services.py::TestVisualGenerator::test_create_frames_with_supabase_upload -v
```

### Run regression harness:
```bash
# Via pytest
pytest tests/test_story_pipeline_regression.py -v

# Via CLI script (standalone)
python run_regression_harness.py
python run_regression_harness.py --verbose
python run_regression_harness.py --prompt ocean_adventure --verbose
python run_regression_harness.py --json
```

## Test Coverage

These tests cover all 5 main tasks:

1. ✅ **Persist generated stories to Supabase tables**
   - Session creation
   - Session asset creation (batch)
   - Profile upsert
   - Error handling

2. ✅ **Make HuggingFace calls async-safe with timeouts**
   - Timeout handling with `asyncio.wait_for`
   - Retry logic with exponential backoff
   - Error type detection and handling
   - Max retries enforcement

3. ✅ **Serve media via Supabase Storage signed URLs**
   - Audio upload and signed URL generation
   - Video upload and signed URL generation
   - Frame upload and signed URL generation
   - Fallback to local paths when Supabase unavailable

4. ✅ **Improve VisualGenerator scene chunking fallback**
   - Paragraph distribution across scenes
   - Placeholder image fallback on errors
   - Caption truncation
   - Chunking edge cases

5. ✅ **Add PromptBuilder + generator unit tests**
   - Comprehensive PromptBuilder tests (existing)
   - StoryGenerator tests (existing)
   - Additional timeout/retry tests (new)

## Dependencies

Tests require:
- `pytest`
- `pytest-asyncio`
- `pytest-mock` (for mocking)
- `fastapi` (for TestClient)
- `PIL` (for image testing)

Note: Some tests may require additional dependencies like `websockets` for Supabase client tests. These are runtime dependencies and don't affect test correctness.

## Notes

- All async functions are properly tested with `@pytest.mark.asyncio`
- Mocking is used extensively to avoid external API calls
- Tests are isolated and don't depend on external services
- Error cases are thoroughly tested
- Edge cases are covered (empty inputs, timeouts, connection errors)

