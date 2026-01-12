"use client";

import React from "react";
import * as designSystem from "@dream-flow/design-system";

const { colors, typography, spacing, borderRadius } = designSystem;

interface ChipProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
  selected?: boolean;
  onClick?: () => void;
  style?: React.CSSProperties;
}

export function Chip({
  children,
  selected = false,
  onClick,
  style,
  ...props
}: ChipProps) {
  return (
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        padding: `${spacing.s}px ${spacing.m}px`,
        background: selected
          ? `linear-gradient(135deg, ${colors.primary.purple}26, ${colors.secondary.cyan}26)`
          : colors.background.glass,
        border: `1px solid ${selected ? colors.primary.purple : colors.border.subtle}`,
        borderRadius: borderRadius.full,
        color: selected ? colors.text.primary : colors.text.secondary,
        fontSize: typography.fontSize.bodySmall,
        fontFamily: typography.fontFamily.primary,
        cursor: onClick ? "pointer" : "default",
        transition: "all 0.2s ease",
        ...style,
      }}
      onClick={onClick}
      {...props}
    >
      {children}
    </div>
  );
}

