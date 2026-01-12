/**
 * Dream Flow Consumer API Client
 */

import { getAccessToken } from "@dream-flow/supabase-auth";
import type {
  StoryGenerationRequest,
  StoryResponse,
  SessionHistoryResponse,
  FeedbackRequest,
  FeedbackResponse,
  SubscriptionResponse,
  UsageQuotaResponse,
  StoryPresetsResponse,
} from "./types";

export class DreamFlowClient {
  private baseUrl: string;

  constructor(
    baseUrl: string = process.env.NEXT_PUBLIC_BACKEND_URL ||
      "http://localhost:8080"
  ) {
    this.baseUrl = baseUrl;
  }

  private async getHeaders(): Promise<HeadersInit> {
    const headers: HeadersInit = {
      "Content-Type": "application/json",
    };

    const token = await getAccessToken();
    if (token) {
      headers["Authorization"] = `Bearer ${token}`;
    }

    return headers;
  }

  async generateStory(
    request: StoryGenerationRequest,
    options?: { tempSessionId?: string }
  ): Promise<StoryResponse> {
    try {
      // Add timeout for story generation (15 minutes - local inference can be slow)
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 15 * 60 * 1000); // 15 minutes

      try {
        const headers = await this.getHeaders();
        // Add temp session ID header if provided (for progressive updates)
        if (options?.tempSessionId) {
          (headers as Record<string, string>)["X-Temp-Session-Id"] = options.tempSessionId;
        }
        
        const response = await fetch(`${this.baseUrl}/api/v1/story`, {
          method: "POST",
          headers,
          body: JSON.stringify(request),
          signal: controller.signal,
        });
        clearTimeout(timeoutId);

        if (!response.ok) {
        let errorMessage = "Failed to generate story";
        let upgradeRequired = false;
        try {
          const contentType = response.headers.get("content-type");
          if (contentType && contentType.includes("application/json")) {
            const error = await response.json();
            // Safely extract error message
            if (typeof error === "string") {
              errorMessage = error;
            } else if (error && typeof error === "object") {
              // Handle nested error objects (FastAPI returns {detail: {error: "...", model_id: "...", details: "..."}})
              if (error.detail) {
                if (typeof error.detail === "string") {
                  errorMessage = error.detail;
                } else if (typeof error.detail === "object") {
                  errorMessage = error.detail.message || error.detail.error || JSON.stringify(error.detail);
                  upgradeRequired = error.detail.upgrade_required === true;
                } else {
                  errorMessage = JSON.stringify(error.detail);
                }
              } else {
                errorMessage =
                  error.message ||
                  error.error ||
                  (typeof error.toString === "function" && error.toString() !== "[object Object]"
                    ? error.toString()
                    : JSON.stringify(error));
                upgradeRequired = error.upgrade_required === true;
              }
            }
          } else {
            // Try to get text response
            const text = await response.text();
            errorMessage = text.trim() || `HTTP ${response.status}: ${response.statusText}`;
          }
        } catch (parseError) {
          // If we can't parse the response, use status code
          if (response.status === 503) {
            errorMessage = "The story generation service is temporarily unavailable. This may be due to high demand or service maintenance. Please try again in a few moments.";
          } else if (response.status === 422) {
            errorMessage = "Invalid request. Please check your input and try again.";
          } else if (response.status === 429) {
            errorMessage = "Too many requests. Please wait a moment before trying again.";
          } else if (response.status === 403) {
            errorMessage = "This theme is locked. Upgrade to Premium to unlock all themes!";
            upgradeRequired = true;
          } else {
            errorMessage = `HTTP ${response.status}: ${response.statusText || "Service Unavailable"}`;
          }
        }
        const error = new Error(errorMessage) as Error & { upgradeRequired?: boolean };
        if (upgradeRequired) {
          error.upgradeRequired = true;
        }
        throw error;
      }

        return response.json();
      } catch (fetchError: any) {
        clearTimeout(timeoutId);
        if (fetchError.name === "AbortError") {
          throw new Error(
            "Story generation timed out. The request took longer than 15 minutes. Please try again with a shorter story or fewer scenes."
          );
        }
        throw fetchError;
      }
    } catch (error: any) {
      if (error instanceof TypeError && error.message.includes("fetch")) {
        throw new Error(
          `Network error: Unable to connect to backend at ${this.baseUrl}. Please ensure the backend server is running.`
        );
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(
        typeof error === "string" ? error : JSON.stringify(error)
      );
    }
  }

  async getHistory(limit: number = 10): Promise<SessionHistoryResponse> {
    try {
      const response = await fetch(
        `${this.baseUrl}/api/v1/history?limit=${limit}`,
        {
          method: "GET",
          headers: await this.getHeaders(),
        }
      );

      if (!response.ok) {
        let errorMessage = "Failed to fetch story history";
        try {
          const error = await response.json();
          errorMessage =
            error.detail ||
            error.message ||
            error.error ||
            JSON.stringify(error);
        } catch {
          try {
            const text = await response.text();
            errorMessage =
              text || `HTTP ${response.status}: ${response.statusText}`;
          } catch {
            errorMessage = `HTTP ${response.status}: ${response.statusText}`;
          }
        }
        throw new Error(errorMessage);
      }

      return response.json();
    } catch (error: any) {
      if (error instanceof TypeError && error.message.includes("fetch")) {
        throw new Error(
          `Network error: Unable to connect to backend at ${this.baseUrl}. Please ensure the backend server is running.`
        );
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(
        typeof error === "string" ? error : JSON.stringify(error)
      );
    }
  }

  async submitFeedback(feedback: FeedbackRequest): Promise<FeedbackResponse> {
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/feedback`, {
        method: "POST",
        headers: await this.getHeaders(),
        body: JSON.stringify(feedback),
      });

      if (!response.ok) {
        let errorMessage = "Failed to submit feedback";
        try {
          const error = await response.json();
          errorMessage =
            error.detail ||
            error.message ||
            error.error ||
            JSON.stringify(error);
        } catch {
          try {
            const text = await response.text();
            errorMessage =
              text || `HTTP ${response.status}: ${response.statusText}`;
          } catch {
            errorMessage = `HTTP ${response.status}: ${response.statusText}`;
          }
        }
        throw new Error(errorMessage);
      }

      return response.json();
    } catch (error: any) {
      if (error instanceof TypeError && error.message.includes("fetch")) {
        throw new Error(
          `Network error: Unable to connect to backend at ${this.baseUrl}. Please ensure the backend server is running.`
        );
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(
        typeof error === "string" ? error : JSON.stringify(error)
      );
    }
  }

  async getSubscription(): Promise<SubscriptionResponse> {
    const response = await fetch(`${this.baseUrl}/api/v1/subscription`, {
      method: "GET",
      headers: await this.getHeaders(),
    });

    if (!response.ok) {
      const error = await response
        .json()
        .catch(() => ({ detail: "Failed to fetch subscription" }));
      throw new Error(error.detail || "Failed to fetch subscription");
    }

    return response.json();
  }

  async getUsageQuota(): Promise<UsageQuotaResponse> {
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/subscription/quota`, {
        method: "GET",
        headers: await this.getHeaders(),
      });

      if (!response.ok) {
        let errorMessage = "Failed to fetch usage quota";
        try {
          const error = await response.json();
          errorMessage =
            error.detail ||
            error.message ||
            error.error ||
            JSON.stringify(error);
        } catch {
          try {
            const text = await response.text();
            errorMessage =
              text || `HTTP ${response.status}: ${response.statusText}`;
          } catch {
            errorMessage = `HTTP ${response.status}: ${response.statusText}`;
          }
        }
        throw new Error(errorMessage);
      }

      return response.json();
    } catch (error: any) {
      if (error instanceof TypeError && error.message.includes("fetch")) {
        throw new Error(
          `Network error: Unable to connect to backend at ${this.baseUrl}. Please ensure the backend server is running.`
        );
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(
        typeof error === "string" ? error : JSON.stringify(error)
      );
    }
  }

  async getPresets(userId?: string): Promise<StoryPresetsResponse> {
    try {
      const url = new URL(`${this.baseUrl}/api/v1/presets`);
      if (userId) {
        url.searchParams.append("user_id", userId);
      }

      const response = await fetch(url.toString(), {
        method: "GET",
        headers: await this.getHeaders(),
      });

      if (!response.ok) {
        const error = await response
          .json()
          .catch(() => ({ detail: "Failed to fetch presets" }));
        throw new Error(error.detail || "Failed to fetch presets");
      }

      return response.json();
    } catch (error: any) {
      if (error instanceof TypeError && error.message.includes("fetch")) {
        throw new Error(
          `Network error: Unable to connect to backend at ${this.baseUrl}. Please ensure the backend server is running.`
        );
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(
        typeof error === "string" ? error : JSON.stringify(error)
      );
    }
  }
}

