"use client";

import React, { useEffect, useRef } from "react";

interface AdBannerProps {
  hasAds: boolean;
  style?: React.CSSProperties;
  className?: string;
}

// Ad service helper functions
function shouldShowAds(hasAds: boolean): boolean {
  if (typeof window === "undefined") return false;
  const adsEnabled = process.env.NEXT_PUBLIC_ADS_ENABLED !== "false";
  const publisherId = process.env.NEXT_PUBLIC_ADSENSE_PUBLISHER_ID;
  return adsEnabled && hasAds && !!publisherId;
}

function getPublisherId(): string | null {
  if (typeof window === "undefined") return null;
  return process.env.NEXT_PUBLIC_ADSENSE_PUBLISHER_ID || null;
}

function loadAdSenseScript(): void {
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
}

function pushAd(adElement: HTMLElement): void {
  if (typeof window === "undefined" || !(window as any).adsbygoogle) {
    return;
  }

  try {
    ((window as any).adsbygoogle = (window as any).adsbygoogle || []).push({});
  } catch (e) {
    console.error("Error pushing ad:", e);
  }
}

export function AdBanner({ hasAds, style, className }: AdBannerProps) {
  const adRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!shouldShowAds(hasAds)) {
      return;
    }

    // Load AdSense script if needed
    loadAdSenseScript();

    // Wait for script to load, then push ad
    const checkAndPush = () => {
      if (adRef.current && (window as any).adsbygoogle) {
        try {
          pushAd(adRef.current);
        } catch (e) {
          console.error("Error initializing ad:", e);
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
  }, [hasAds]);

  if (!shouldShowAds(hasAds)) {
    return null;
  }

  const publisherId = getPublisherId();

  return (
    <div
      ref={adRef}
      style={{
        minHeight: 90,
        width: "100%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        ...style,
      }}
      className={className}
    >
      <ins
        className="adsbygoogle"
        style={{
          display: "block",
          width: "100%",
          minHeight: 90,
        }}
        data-ad-client={publisherId || ""}
        data-ad-slot="1234567890" // Replace with actual ad slot ID
        data-ad-format="auto"
        data-full-width-responsive="true"
      />
    </div>
  );
}
