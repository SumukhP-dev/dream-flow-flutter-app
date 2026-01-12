"use client";

import React from "react";
import * as designSystem from "@dream-flow/design-system";

const { colors, typography, spacing, borderRadius } = designSystem;

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  style?: React.CSSProperties;
  error?: string;
  success?: boolean;
  showCharCount?: boolean;
  maxLength?: number;
}

export function Input({
  label,
  style,
  error,
  success,
  showCharCount,
  maxLength,
  ...props
}: InputProps) {
  const value = props.value as string | undefined;
  const charCount = value?.length || 0;

  return (
    <div style={{ width: "100%" }}>
      {label && (
        <label
          style={{
            display: "block",
            color: colors.text.secondary,
            fontSize: typography.fontSize.labelMedium,
            fontWeight: typography.fontWeight.medium,
            marginBottom: spacing.s,
          }}
        >
          {label}
        </label>
      )}
      <div style={{ position: "relative" }}>
        <input
          style={{
            width: "100%",
            padding: `${spacing.m}px ${spacing.l}px`,
            background: colors.background.glass,
            border: `1px solid ${
              error
                ? colors.border.error
                : success
                ? colors.status.success
                : colors.border.subtle
            }`,
            borderRadius: borderRadius.medium,
            color: colors.text.primary,
            fontSize: typography.fontSize.bodyMedium,
            fontFamily: typography.fontFamily.primary,
            outline: "none",
            transition: "all 0.2s ease",
            ...style,
          }}
          onFocus={(e) => {
            e.target.style.borderColor = error
              ? colors.border.error
              : success
              ? colors.status.success
              : colors.border.focus;
          }}
          onBlur={(e) => {
            e.target.style.borderColor = error
              ? colors.border.error
              : success
              ? colors.status.success
              : colors.border.subtle;
          }}
          maxLength={maxLength}
          aria-invalid={error ? "true" : undefined}
          aria-describedby={error ? `${props.id}-error` : undefined}
          {...props}
        />
        {success && (
          <span
            style={{
              position: "absolute",
              right: spacing.m,
              top: "50%",
              transform: "translateY(-50%)",
              color: colors.status.success,
              fontSize: typography.fontSize.titleMedium,
            }}
            aria-label="Valid input"
          >
            ✓
          </span>
        )}
      </div>
      {(error || showCharCount) && (
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            marginTop: spacing.xs,
          }}
        >
          {error && (
            <span
              id={props.id ? `${props.id}-error` : undefined}
              style={{
                color: colors.status.error,
                fontSize: typography.fontSize.bodySmall,
              }}
              role="alert"
            >
              {error}
            </span>
          )}
          {showCharCount && maxLength && (
            <span
              style={{
                color:
                  charCount > maxLength * 0.9
                    ? colors.status.warning
                    : colors.text.tertiary,
                fontSize: typography.fontSize.bodySmall,
                marginLeft: "auto",
              }}
            >
              {charCount} / {maxLength}
            </span>
          )}
        </div>
      )}
    </div>
  );
}

