// Server-side Supabase utilities
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function getServerSession() {
  const cookieStore = await cookies();
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    return null;
  }

  // Validate URL format
  try {
    new URL(supabaseUrl);
  } catch (e) {
    console.error("Invalid Supabase URL provided for server session:", supabaseUrl, e);
    return null;
  }

  // Check if using placeholder values
  if (supabaseUrl.includes("your-project.supabase.co") || supabaseAnonKey === "your-anon-key") {
    return null;
  }

  try {
    const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // The `setAll` method was called from a Server Component.
            // This can be ignored if you have middleware refreshing
            // user sessions.
          }
        },
      },
    });

    const {
      data: { session },
    } = await supabase.auth.getSession();

    return session;
  } catch (e) {
    console.error("Error fetching server session:", e);
    return null;
  }
}

