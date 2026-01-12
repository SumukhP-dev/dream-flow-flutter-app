"use client";

import React from "react";
import * as designSystem from "@dream-flow/design-system";

const { colors, typography, spacing, borderRadius } = designSystem;

interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  options: Array<{ value: string; label: string }>;
  style?: React.CSSProperties;
}

export function Select({ label, options, style, ...props }: SelectProps) {
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
      <select
        style={{
          width: "100%",
          padding: `${spacing.m}px ${spacing.l}px`,
          background: colors.background.glass,
          border: `1px solid ${colors.border.subtle}`,
          borderRadius: borderRadius.medium,
          color: colors.text.primary,
          fontSize: typography.fontSize.bodyMedium,
          fontFamily: typography.fontFamily.primary,
          outline: "none",
          cursor: "pointer",
          ...style,
        }}
        {...props}
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </div>
  );
}

