-- Create story templates table
-- Stores pre-defined story themes and templates that can be retrieved at runtime
CREATE TABLE IF NOT EXISTS story_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  emoji TEXT NOT NULL,
  description TEXT NOT NULL,
  mood TEXT NOT NULL,
  routine TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('focus', 'family', 'unwind')),
  is_featured BOOLEAN DEFAULT FALSE,
  sample_story_text TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS story_templates_category_idx ON story_templates(category);
CREATE INDEX IF NOT EXISTS story_templates_featured_idx ON story_templates(is_featured);
CREATE INDEX IF NOT EXISTS story_templates_title_idx ON story_templates(title);

-- Enable Row Level Security
ALTER TABLE story_templates ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow public read access to story templates
CREATE POLICY "Anyone can view story templates"
  ON story_templates
  FOR SELECT
  USING (true);

-- Insert sample story templates from the existing JSON data
INSERT INTO story_templates (title, emoji, description, mood, routine, category, is_featured, sample_story_text) VALUES
-- Focus category
('Study Grove', '🌿', 'Tranquil forest with gentle streams, rustling leaves, and distant bird songs.', 'Focused and clear', 'Deep breathing and intention setting', 'focus', true, 
'Once upon a time, in the heart of Study Grove, gentle streams carried whispers of ancient wisdom. The trees swayed softly, their leaves rustling with secrets of focus and clarity. Here, in this tranquil sanctuary, thoughts became clear as the flowing water, and the mind found its perfect rhythm for learning and growth.'),

('Focus Falls', '💧', 'Cascading waterfall with rhythmic sounds in a secluded, peaceful setting.', 'Centered and attentive', 'Mindful listening and concentration', 'focus', false,
'In the hidden valley of Focus Falls, water cascades down crystalline rocks, creating a melody that guides wandering minds to perfect attention. The rhythmic sounds wash away distractions, leaving behind a serene focus that flows as naturally as the waterfall itself.'),

('Zen Garden', '🪨', 'Minimalist Japanese garden with raked sand patterns and soft wind chimes.', 'Calm and present', 'Meditation and quiet reflection', 'focus', false,
'Within the sacred walls of the Zen Garden, every grain of sand holds purpose, every stone carries meaning. The gentle wind chimes sing of mindfulness, while the perfectly raked patterns remind us that in simplicity, we find the deepest concentration and peace.'),

-- Family category  
('Family Hearth', '🔥', 'Warm living room with crackling fireplace, cozy blankets, and shared stories.', 'Warm and connected', 'Gathering together for storytime', 'family', true,
'Around the Family Hearth, golden flames danced with stories of love and togetherness. Cozy blankets wrapped the family in warmth while the crackling fire provided the perfect soundtrack for shared adventures. Here, bonds grew stronger with every tale told and every moment cherished together.'),

('Campfire Chronicles', '🏕️', 'Outdoor campfire setting with stars above, perfect for family adventures.', 'Adventurous and together', 'Sharing tales under the night sky', 'family', false,
'Under the vast canopy of twinkling stars, the Campfire Chronicles came alive. Families gathered around the glowing embers, sharing stories that sparked imagination and strengthened bonds. The night sky listened as adventures were born and memories were made in the warm circle of firelight.'),

('Storybook Nook', '📚', 'Enchanted library corner with floating books and a magical reading space.', 'Curious and imaginative', 'Cozy reading and discovery', 'family', false,
'In the magical Storybook Nook, books floated gently through the air, their pages whispering tales of wonder. Families nestled into the enchanted reading corner, where every story came alive and imagination knew no bounds. Here, the love of reading was passed from heart to heart, generation to generation.'),

-- Unwind category
('Oceanic Serenity', '🌊', 'Peaceful beach at night with gentle waves and distant seagull calls.', 'Peaceful and relaxed', 'Listening to the rhythm of the ocean', 'unwind', true,
'As twilight painted the sky in soft pastels, Oceanic Serenity revealed its magic. Gentle waves lapped the shore in perfect rhythm, while distant seagulls sang their evening song. The ocean breathed slowly, deeply, teaching all who listened the art of true relaxation and inner peace.'),

('Starlit Sanctuary', '✨', 'Celestial garden with bioluminescent river paths under a star-filled sky.', 'Dreamy and serene', 'Breathing ritual by the window', 'unwind', false,
'In the ethereal Starlit Sanctuary, bioluminescent rivers wound through celestial gardens, their gentle glow reflecting the stars above. This magical place existed between dreams and reality, where every breath aligned with the cosmic rhythm, and serenity flowed like starlight through the soul.'),

('Whispering Woods', '🌲', 'Forest spirits hum lullabies with your spirit guide in a tranquil grove.', 'Grounded with soft curiosity', 'Herbal tea and journaling', 'unwind', false,
'Deep within the Whispering Woods, ancient forest spirits hummed gentle lullabies that carried on the evening breeze. Spirit guides emerged from the shadows, offering wisdom and comfort to weary travelers. Here, in this tranquil grove, the soul found its grounding and the heart discovered its quiet song.'),

('Aurora Dreams', '🌌', 'Northern lights swirl above floating lagoons in an ethereal landscape.', 'In awe, ready to unwind', 'Stretching + gratitude whisper', 'unwind', false,
'Above the floating lagoons of Aurora Dreams, the northern lights painted impossible colors across the sky. The ethereal landscape shimmered with otherworldly beauty, inspiring awe and wonder while gently preparing the spirit for the most peaceful of slumbers. Here, gratitude and beauty danced together in perfect harmony.');