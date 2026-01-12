"use client";

import React, { useEffect, useState } from "react";
import * as designSystem from "@dream-flow/design-system";

const { colors, typography, spacing, borderRadius } = designSystem;

interface AdInterstitialProps {
  hasAds: boolean;
  onClose: () => void;
  show: boolean;
}

export function AdInterstitial({ hasAds, onClose, show }: AdInterstitialProps) {
  const [adLoaded, setAdLoaded] = useState(false);
  const adRef = React.useRef<HTMLDivElement>(null);

  // Ad service helper functions
  const shouldShowAdsCheck = () => {
    if (typeof window === "undefined") return false;
    const adsEnabled = process.env.NEXT_PUBLIC_ADS_ENABLED !== "false";
    const publisherId = process.env.NEXT_PUBLIC_ADSENSE_PUBLISHER_ID;
    return adsEnabled && hasAds && !!publisherId;
  };

  const getPublisherId = () => {
    if (typeof window === "undefined") return null;
    return process.env.NEXT_PUBLIC_ADSENSE_PUBLISHER_ID || null;
  };

  const loadAdSenseScript = () => {
    if (typeof window === "undefined") return;
    
    const publisherId = getPublisherId();
    if (!publisherId) return;

    // Check if already loaded
    if (document.querySelector('script[src*="adsbygoogle"]')) {
      return;
    }

    const script = document.createElement("script");
    script.src = `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${publisherId}`;
    script.async = true;
    script.crossOrigin = "anonymous";
    document.head.appendChild(script);
  };

  const pushAd = (adElement: HTMLElement) => {
    if (typeof window === "undefined" || !(window as any).adsbygoogle) {
      return;
    }

    try {
      ((window as any).adsbygoogle = (window as any).adsbygoogle || []).push({});
    } catch (e) {
      console.error("Error pushing ad:", e);
    }
  };

  useEffect(() => {
    if (!show || !shouldShowAdsCheck()) {
      return;
    }

    // Load AdSense script if needed
    loadAdSenseScript();

    // Wait for script to load, then push ad
    const checkAndPush = () => {
      if (adRef.current && (window as any).adsbygoogle) {
        try {
          pushAd(adRef.current);
          setAdLoaded(true);
        } catch (e) {
          console.error("Error initializing interstitial ad:", e);
        }
      } else if (adRef.current) {
        // Retry after a short delay if script not loaded yet
        setTimeout(checkAndPush, 100);
      }
    };

    // Initial check
    checkAndPush();

    // Also check when script loads
    const script = document.querySelector('script[src*="adsbygoogle"]');
    if (script) {
      script.addEventListener("load", checkAndPush);
      return () => script.removeEventListener("load", checkAndPush);
    }
  }, [show, hasAds]);

  if (!show || !shouldShowAdsCheck()) {
    return null;
  }

  const publisherId = getPublisherId();

  return (
    <div
      style={{
        position: "fixed",
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: "rgba(0, 0, 0, 0.8)",
        zIndex: 10000,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: spacing.xl,
      }}
      onClick={onClose}
    >
      <div
        style={{
          backgroundColor: colors.background.primary,
          borderRadius: borderRadius.large,
          padding: spacing.xl,
          maxWidth: 600,
          width: "100%",
          position: "relative",
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <button
          onClick={onClose}
          style={{
            position: "absolute",
            top: spacing.m,
            right: spacing.m,
            background: "none",
            border: "none",
            fontSize: typography.fontSize.titleLarge,
            color: colors.text.secondary,
            cursor: "pointer",
            padding: spacing.xs,
          }}
          aria-label="Close ad"
        >
          ×
        </button>
        <h3
          style={{
            fontSize: typography.fontSize.titleMedium,
            fontWeight: typography.fontWeight.bold,
            color: colors.text.primary,
            marginBottom: spacing.m,
          }}
        >
          Ad-Supported Content
        </h3>
        <p
          style={{
            fontSize: typography.fontSize.bodyMedium,
            color: colors.text.secondary,
            marginBottom: spacing.l,
          }}
        >
          This content is supported by ads. Upgrade to Premium to enjoy ad-free stories.
        </p>
        <div
          ref={adRef}
          style={{
            minHeight: 250,
            width: "100%",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            marginBottom: spacing.m,
          }}
        >
          {!adLoaded && (
            <div
              style={{
                color: colors.text.tertiary,
                fontSize: typography.fontSize.bodySmall,
              }}
            >
              Loading ad...
            </div>
          )}
          <ins
            className="adsbygoogle"
            style={{
              display: "block",
              width: "100%",
              minHeight: 250,
            }}
            data-ad-client={publisherId || ""}
            data-ad-slot="0987654321" // Replace with actual interstitial ad slot ID
            data-ad-format="auto"
          />
        </div>
        <button
          onClick={onClose}
          style={{
            width: "100%",
            padding: `${spacing.m}px ${spacing.l}px`,
            background: `linear-gradient(135deg, ${colors.primary.purple} 0%, ${colors.primary.blue} 100%)`,
            border: "none",
            borderRadius: borderRadius.medium,
            color: colors.text.primary,
            fontSize: typography.fontSize.bodyMedium,
            fontWeight: typography.fontWeight.medium,
            cursor: "pointer",
          }}
        >
          Continue
        </button>
      </div>
    </div>
  );
}

