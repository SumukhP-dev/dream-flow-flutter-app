"use client";

import React, { useState } from "react";
import { Button } from "./Button";
import * as designSystem from "@dream-flow/design-system";

const { colors, typography, spacing, borderRadius } = designSystem;

interface ShareButtonProps {
  storyId: string;
  storyTitle: string;
  storyTheme: string;
  storyText?: string;
  thumbnailUrl?: string;
  onShare?: () => void;
  variant?: "primary" | "secondary" | "text";
  size?: "small" | "medium" | "large";
}

export function ShareButton({
  storyId,
  storyTitle,
  storyTheme,
  storyText,
  thumbnailUrl,
  onShare,
  variant = "secondary",
  size = "medium",
}: ShareButtonProps) {
  const [isSharing, setIsSharing] = useState(false);

  const handleShare = async () => {
    setIsSharing(true);
    try {
      const shareData: ShareData = {
        title: `${storyTheme} - Dream Flow`,
        text: storyText
          ? `${storyTitle}\n\n${storyText.substring(0, 200)}...`
          : `Check out my Dream Flow story: ${storyTitle}`,
        url: `${typeof window !== "undefined" ? window.location.origin : ""}/app/session/${storyId}`,
      };

      if (thumbnailUrl) {
        try {
          const response = await fetch(thumbnailUrl);
          const blob = await response.blob();
          const file = new File([blob], "story-thumbnail.jpg", { type: "image/jpeg" });
          shareData.files = [file];
        } catch (e) {
          console.warn("Failed to load thumbnail for share:", e);
        }
      }

      if (navigator.share && navigator.canShare && navigator.canShare(shareData)) {
        await navigator.share(shareData);
      } else {
        // Fallback: copy to clipboard
        await navigator.clipboard.writeText(
          `${shareData.title}\n${shareData.text}\n${shareData.url}`
        );
        alert("Story link copied to clipboard!");
      }

      onShare?.();
    } catch (error: any) {
      if (error.name !== "AbortError") {
        console.error("Share failed:", error);
        // Fallback: copy to clipboard
        try {
          await navigator.clipboard.writeText(
            `${window.location.origin}/app/session/${storyId}`
          );
          alert("Story link copied to clipboard!");
        } catch (e) {
          console.error("Clipboard copy failed:", e);
        }
      }
    } finally {
      setIsSharing(false);
    }
  };

  const handleSocialShare = (platform: "twitter" | "facebook" | "reddit") => {
    const url = encodeURIComponent(
      `${typeof window !== "undefined" ? window.location.origin : ""}/app/session/${storyId}`
    );
    const text = encodeURIComponent(`Check out my Dream Flow story: ${storyTitle}`);
    
    const shareUrls = {
      twitter: `https://twitter.com/intent/tweet?text=${text}&url=${url}`,
      facebook: `https://www.facebook.com/sharer/sharer.php?u=${url}`,
      reddit: `https://reddit.com/submit?title=${text}&url=${url}`,
    };

    window.open(shareUrls[platform], "_blank", "width=600,height=400");
    onShare?.();
  };

  return (
    <div style={{ display: "flex", gap: spacing.s, alignItems: "center" }}>
      <Button
        variant={variant}
        size={size}
        onClick={handleShare}
        isLoading={isSharing}
      >
        {isSharing ? "Sharing..." : "Share"}
      </Button>
      
      <div style={{ display: "flex", gap: spacing.xs }}>
        <button
          onClick={() => handleSocialShare("twitter")}
          style={{
            padding: spacing.xs,
            background: "none",
            border: "none",
            cursor: "pointer",
            fontSize: typography.fontSize.titleMedium,
          }}
          aria-label="Share on Twitter"
        >
          🐦
        </button>
        <button
          onClick={() => handleSocialShare("facebook")}
          style={{
            padding: spacing.xs,
            background: "none",
            border: "none",
            cursor: "pointer",
            fontSize: typography.fontSize.titleMedium,
          }}
          aria-label="Share on Facebook"
        >
          📘
        </button>
        <button
          onClick={() => handleSocialShare("reddit")}
          style={{
            padding: spacing.xs,
            background: "none",
            border: "none",
            cursor: "pointer",
            fontSize: typography.fontSize.titleMedium,
          }}
          aria-label="Share on Reddit"
        >
          🤖
        </button>
      </div>
    </div>
  );
}

