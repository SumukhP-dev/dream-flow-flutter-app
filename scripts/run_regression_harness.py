#!/usr/bin/env python3
"""
CLI script to run the story pipeline regression harness.

Usage:
    python run_regression_harness.py
    python run_regression_harness.py --verbose
    python run_regression_harness.py --prompt ocean_adventure
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path
from unittest.mock import MagicMock

# Mock moviepy before importing app modules (required for services.py)
sys.modules['moviepy'] = MagicMock()
sys.modules['moviepy.editor'] = MagicMock()

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent))

from tests.test_story_pipeline_regression import (
    CANNED_PROMPTS,
    RegressionResult,
    check_length,
    check_scene_count,
    check_tone_keywords,
    check_tone_violations,
    count_words,
    create_mock_narration_generator,
    create_mock_story_generator,
    create_mock_visual_generator,
    generate_mock_story,
)
from app.prompting import PromptBuilder
from app.schemas import StoryRequest


async def run_single_test(test_case: dict, verbose: bool = False) -> RegressionResult:
    """Run a single regression test case."""
    prompt_name = test_case["name"]
    prompt = test_case["prompt"]
    theme = test_case["theme"]
    target_length = test_case["target_length"]
    num_scenes = test_case["num_scenes"]
    profile = test_case["profile"]
    expected_tone_keywords = test_case["expected_tone_keywords"]
    expected_word_range = test_case["expected_word_count_range"]
    
    if verbose:
        print(f"\n{'='*60}")
        print(f"Testing: {prompt_name}")
        print(f"Prompt: {prompt}")
        print(f"Theme: {theme}, Target Length: {target_length}, Scenes: {num_scenes}")
        print(f"{'='*60}")
    
    # Generate mock story
    mock_story = generate_mock_story(prompt, theme, target_length, profile)
    
    # Create mocked generators
    story_gen = create_mock_story_generator(prompt_name, mock_story)
    visual_gen = create_mock_visual_generator(num_scenes)
    narration_gen = create_mock_narration_generator()
    
    # Create context
    builder = PromptBuilder()
    request = StoryRequest(
        prompt=prompt,
        theme=theme,
        target_length=target_length,
        num_scenes=num_scenes,
        profile=profile,
    )
    context = builder.to_context(request)
    
    # Run pipeline (mocked)
    story_text = await story_gen.generate(context)
    frames = await visual_gen.create_frames(story_text, context, num_scenes)
    audio_url = await narration_gen.synthesize(story_text, context, None)
    
    if verbose:
        print(f"\nGenerated Story ({count_words(story_text)} words):")
        print("-" * 60)
        print(story_text[:200] + "..." if len(story_text) > 200 else story_text)
        print("-" * 60)
    
    # Run checks
    errors = []
    warnings = []
    
    # Check tone keywords
    missing_keywords = check_tone_keywords(story_text, expected_tone_keywords)
    if missing_keywords:
        warnings.append(f"Missing expected tone keywords: {', '.join(missing_keywords)}")
    
    # Check tone violations
    tone_errors, guardrail_violations = check_tone_violations(story_text)
    errors.extend(tone_errors)
    if guardrail_violations:
        for violation in guardrail_violations:
            errors.append(f"Guardrail violation: {violation.category} - {violation.detail}")
    
    # Check length
    length_errors = check_length(story_text, target_length, expected_word_range)
    errors.extend(length_errors)
    
    # Check scene count
    scene_errors = check_scene_count(frames, num_scenes)
    errors.extend(scene_errors)
    
    # Collect metrics
    metrics = {
        "word_count": count_words(story_text),
        "target_length": target_length,
        "scene_count": len(frames),
        "expected_scenes": num_scenes,
        "exclamation_count": story_text.count("!"),
        "all_caps_chunks": len([w for w in story_text.split() if len(w) > 5 and w.isupper()]),
        "guardrail_violations": len(guardrail_violations),
    }
    
    result = RegressionResult(
        prompt_name=prompt_name,
        passed=len(errors) == 0,
        errors=errors,
        warnings=warnings,
        metrics=metrics,
    )
    
    if verbose:
        print(f"\nResults:")
        if result.passed:
            print("  [PASSED]")
        else:
            print("  [FAILED]")
        if result.errors:
            print("  Errors:")
            for error in result.errors:
                print(f"    - {error}")
        if result.warnings:
            print("  Warnings:")
            for warning in result.warnings:
                print(f"    - {warning}")
        print(f"  Metrics: {json.dumps(result.metrics, indent=4)}")
    
    return result


async def main():
    """Main entry point for CLI."""
    parser = argparse.ArgumentParser(
        description="Run story pipeline regression harness",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show detailed output for each test",
    )
    parser.add_argument(
        "--prompt",
        type=str,
        help="Run a specific prompt by name",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON",
    )
    
    args = parser.parse_args()
    
    # Select test cases
    if args.prompt:
        test_cases = [tc for tc in CANNED_PROMPTS if tc["name"] == args.prompt]
        if not test_cases:
            print(f"Error: Prompt '{args.prompt}' not found")
            print(f"Available prompts: {', '.join(tc['name'] for tc in CANNED_PROMPTS)}")
            sys.exit(1)
    else:
        test_cases = CANNED_PROMPTS
    
    print(f"Running regression harness on {len(test_cases)} prompt(s)...")
    
    # Run all tests
    results = []
    for test_case in test_cases:
        result = await run_single_test(test_case, verbose=args.verbose)
        results.append(result)
    
    # Summary
    passed = sum(1 for r in results if r.passed)
    failed = len(results) - passed
    
    if args.json:
        # Output as JSON
        output = {
            "summary": {
                "total": len(results),
                "passed": passed,
                "failed": failed,
            },
            "results": [
                {
                    "prompt_name": r.prompt_name,
                    "passed": r.passed,
                    "errors": r.errors,
                    "warnings": r.warnings,
                    "metrics": r.metrics,
                }
                for r in results
            ],
        }
        print(json.dumps(output, indent=2))
    else:
        # Human-readable summary
        print(f"\n{'='*60}")
        print("SUMMARY")
        print(f"{'='*60}")
        print(f"Total: {len(results)}")
        print(f"Passed: {passed}")
        print(f"Failed: {failed}")
        
        if failed > 0:
            print(f"\nFailed tests:")
            for result in results:
                if not result.passed:
                    print(f"\n  {result.prompt_name}:")
                    for error in result.errors:
                        print(f"    [ERROR] {error}")
                    print(f"    Metrics: {result.metrics}")
    
    # Exit with error code if any tests failed
    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    asyncio.run(main())

