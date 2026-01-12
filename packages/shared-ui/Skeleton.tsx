"use client";

import React from "react";
import * as designSystem from "@dream-flow/design-system";

const { colors, borderRadius, spacing } = designSystem;

interface SkeletonProps {
  width?: string | number;
  height?: string | number;
  variant?: "text" | "circular" | "rectangular";
  lines?: number;
  style?: React.CSSProperties;
}

export function Skeleton({
  width,
  height,
  variant = "rectangular",
  lines,
  style,
}: SkeletonProps) {
  const baseStyle: React.CSSProperties = {
    backgroundColor: colors.background.surface,
    borderRadius:
      variant === "circular"
        ? borderRadius.full
        : variant === "text"
        ? borderRadius.small
        : borderRadius.medium,
    width: width || (variant === "circular" ? height : "100%"),
    height: height || (variant === "text" ? "1em" : "1rem"),
    animation: "pulse 1.5s ease-in-out infinite",
    ...style,
  };

  if (lines && lines > 1) {
    return (
      <div style={{ display: "flex", flexDirection: "column", gap: spacing.s }}>
        {Array.from({ length: lines }).map((_, index) => (
          <div
            key={index}
            style={{
              ...baseStyle,
              width: index === lines - 1 ? "80%" : "100%",
            }}
          />
        ))}
        <style>{`
          @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
          }
        `}</style>
      </div>
    );
  }

  return (
    <>
      <div style={baseStyle} />
      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
      `}</style>
    </>
  );
}

