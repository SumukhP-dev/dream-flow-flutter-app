import asyncio
from app.core.prompting import PromptBuilder, PromptContext
from app.core.local_services import LocalVisualGenerator

story = """Once upon a time, in a serene grove, there lived a fox named Nova. She loved watching the moon paint the leaves with silver light.

One night, while Nova slept, her nose twitched at a gentle glow drifting through the trees. She followed it and found a ring of fluttering fireflies.

They whispered that the grove was dreaming, and Nova could help it stay calm by gathering little lights before dawn.

Nova twirled with the fireflies, scooping their glow into a lantern until the grove sighed with relief. She curled beneath a cedar tree, smiling in the new quiet."""

context = PromptContext(
    prompt="Please illustrate Nova's moonlit adventure",
    theme="Study Grove",
    target_length=400,
    profile=None,
)

async def main():
    builder = PromptBuilder()
    generator = LocalVisualGenerator(prompt_builder=builder)
    frames = await generator.create_frames_progressive(
        story,
        context,
        num_scenes=4,
        storage_prefix=None,
    )
    print("Generated frame URLs:")
    for url in frames:
        print(url)

if __name__ == "__main__":
    asyncio.run(main())
