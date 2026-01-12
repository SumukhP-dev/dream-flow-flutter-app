"use client";

import React, { useState } from "react";
import * as designSystem from "@dream-flow/design-system";

const { colors, typography, spacing, borderRadius } = designSystem;

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  children: React.ReactNode;
  variant?: "primary" | "secondary" | "text";
  size?: "small" | "medium" | "large";
  isLoading?: boolean;
  style?: React.CSSProperties;
}

export function Button({
  children,
  variant = "primary",
  size = "medium",
  isLoading = false,
  style,
  disabled,
  ...props
}: ButtonProps) {
  const baseStyle: React.CSSProperties = {
    border: "none",
    borderRadius: borderRadius.medium,
    cursor: disabled || isLoading ? "not-allowed" : "pointer",
    fontFamily: typography.fontFamily.primary,
    fontWeight: typography.fontWeight.semibold,
    transition: "all 0.2s ease",
    opacity: disabled || isLoading ? 0.6 : 1,
    position: "relative",
    overflow: "hidden",
    outline: "none",
    ...style,
  };

  const sizeStyles: Record<typeof size, React.CSSProperties> = {
    small: {
      padding: `${spacing.s}px ${spacing.m}px`,
      fontSize: typography.fontSize.bodySmall,
    },
    medium: {
      padding: `${spacing.m}px ${spacing.l}px`,
      fontSize: typography.fontSize.bodyMedium,
    },
    large: {
      padding: `${spacing.l}px ${spacing.xl}px`,
      fontSize: typography.fontSize.bodyLarge,
    },
  };

  const variantStyles: Record<typeof variant, React.CSSProperties> = {
    primary: {
      background: `linear-gradient(135deg, ${colors.primary.purple} 0%, ${colors.primary.blue} 100%)`,
      color: colors.text.primary,
    },
    secondary: {
      background: "transparent",
      color: colors.text.primary,
      border: `1px solid ${colors.border.default}`,
    },
    text: {
      background: "transparent",
      color: colors.text.primary,
    },
  };

  const [isHovered, setIsHovered] = useState(false);
  const [isFocused, setIsFocused] = useState(false);

  const hoverStyles: React.CSSProperties = isHovered && !disabled && !isLoading
    ? {
        transform: "translateY(-1px)",
        boxShadow: "0 4px 12px rgba(139, 92, 246, 0.4)",
      }
    : {};

  const focusStyles: React.CSSProperties = isFocused && !disabled
    ? {
        outline: `2px solid ${colors.border.focus}`,
        outlineOffset: "2px",
      }
    : {};

  return (
    <button
      style={{
        ...baseStyle,
        ...sizeStyles[size],
        ...variantStyles[variant],
        ...hoverStyles,
        ...focusStyles,
      }}
      disabled={disabled || isLoading}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      onFocus={() => setIsFocused(true)}
      onBlur={() => setIsFocused(false)}
      aria-label={props["aria-label"] || (typeof children === "string" ? children : undefined)}
      aria-busy={isLoading}
      aria-disabled={disabled || isLoading}
      role="button"
      tabIndex={disabled || isLoading ? -1 : 0}
      {...props}
    >
      {isLoading ? (
        <span style={{ display: "flex", alignItems: "center", gap: spacing.s }}>
          <span
            style={{
              width: 16,
              height: 16,
              border: `2px solid currentColor`,
              borderTopColor: "transparent",
              borderRadius: "50%",
              animation: "spin 0.6s linear infinite",
              display: "inline-block",
            }}
          />
          Loading...
        </span>
      ) : (
        children
      )}
      <style>{`
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
      `}</style>
    </button>
  );
}

