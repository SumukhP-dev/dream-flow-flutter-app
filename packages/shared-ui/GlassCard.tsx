"use client";

import React, { useState } from "react";
import * as designSystem from "@dream-flow/design-system";

const { colors, borderRadius, spacing } = designSystem;

interface GlassCardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
  style?: React.CSSProperties;
}

export function GlassCard({ children, style, ...props }: GlassCardProps) {
  const [isHovered, setIsHovered] = useState(false);
  const [isFocused, setIsFocused] = useState(false);

  const hoverStyles: React.CSSProperties = isHovered
    ? {
        transform: "translateY(-2px)",
        boxShadow: "0 12px 40px rgba(0, 0, 0, 0.4)",
        borderColor: colors.border.default,
      }
    : {};

  const focusStyles: React.CSSProperties = isFocused
    ? {
        outline: `2px solid ${colors.border.focus}`,
        outlineOffset: "2px",
      }
    : {};

  return (
    <div
      style={{
        background: colors.background.glass,
        backdropFilter: "blur(10px)",
        borderRadius: borderRadius.large,
        border: `1px solid ${colors.border.subtle}`,
        padding: spacing.xl,
        boxShadow: "0 8px 32px rgba(0, 0, 0, 0.3)",
        transition: "all 0.2s ease",
        ...hoverStyles,
        ...focusStyles,
        ...style,
      }}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      onFocus={() => setIsFocused(true)}
      onBlur={() => setIsFocused(false)}
      tabIndex={0}
      {...props}
    >
      {children}
    </div>
  );
}

