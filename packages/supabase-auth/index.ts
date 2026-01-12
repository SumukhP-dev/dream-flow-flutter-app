// Client-side Supabase client
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  // Use fallback values if not configured (for development)
  const url = supabaseUrl || "https://demo.supabase.co";
  const key = supabaseAnonKey || "demo-key";

  if (!supabaseUrl || !supabaseAnonKey) {
    console.warn(
      "Supabase environment variables not set. Using demo values. Authentication will not work."
    );
  }

  return createBrowserClient(url, key);
}

// Get access token for API requests
export async function getAccessToken(): Promise<string | null> {
  const supabase = createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  return session?.access_token ?? null;
}
