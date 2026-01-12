/// Builds prompts for on-device ML models, mirroring the Python backend's logic.
class PromptBuilder {
  /// System prompt to guide the story generation model.
  /// This is copied from `backend_fastapi/app/core/local_services.py`.
  String storySystemPrompt() {
    return "You are a creative bedtime story engine for children. "
        "Write soothing, imaginative, age-appropriate stories.";
  }

  // You can add other prompt-building methods here as needed, for example,
  // to construct the full user prompt from context, similar to the Python version.
}
