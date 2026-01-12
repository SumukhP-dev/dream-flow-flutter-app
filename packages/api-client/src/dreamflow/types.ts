/**
 * Dream Flow API Types
 * Matching FastAPI schemas from backend_fastapi/app/dreamflow/schemas.py
 */

export interface StoryProfileInput {
  mood: string;
  routine: string;
  preferences?: string[];
  favorite_characters?: string[];
  calming_elements?: string[];
}

export interface StoryGenerationRequest {
  prompt: string;
  theme: string;
  target_length?: number;
  num_scenes?: number;
  voice?: string;
  profile?: StoryProfileInput;
  child_mode?: boolean;
  child_profile_id?: string;
}

export interface AssetUrls {
  video?: string;
  audio?: string;
  frames?: string[];
  video_url?: string;
  audio_url?: string;
  thumbnail_url?: string;
  // Progressive loading URLs (optional)
  video_progressive?: Record<string, string>;
  audio_progressive?: Record<string, string>;
  frames_progressive?: Array<Record<string, string>>;
}

export interface StoryResponse {
  session_id?: string;
  story_text: string;
  theme: string;
  assets: AssetUrls;
}

export interface SessionHistoryItem {
  session_id: string;
  theme: string;
  prompt: string;
  thumbnail_url?: string;
  created_at: string;
}

export interface SessionHistoryResponse {
  sessions: SessionHistoryItem[];
  total: number;
}

export interface FeedbackRequest {
  session_id: string;
  rating?: number;
  feedback_text?: string;
  liked?: boolean;
}

export interface FeedbackResponse {
  success: boolean;
  message: string;
}

export interface SubscriptionResponse {
  id: string;
  user_id: string;
  tier: "free" | "premium" | "family";
  status: "active" | "cancelled" | "expired" | "past_due";
  has_ads: boolean; // True for free tier, False for paid tiers
  current_period_start: string;
  current_period_end: string;
  cancel_at_period_end?: boolean;
  cancelled_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface UsageQuotaResponse {
  tier: "free" | "premium" | "family";
  quota: number; // Always unlimited (999999) for all tiers now
  has_ads: boolean; // True for free tier, False for paid tiers
  current_count: number; // For analytics only
  period_type: "daily" | "weekly" | "monthly";
  can_generate: boolean; // Always true - unlimited for all tiers
  error_message?: string | null; // Deprecated - always null
}

export interface ThemePreset {
  title: string;
  emoji: string;
  description: string;
  mood: string;
  routine: string;
  category: string;
  is_locked?: boolean;
}

export interface StoryPresetsResponse {
  themes: ThemePreset[];
  featured: ThemePreset[];
}

