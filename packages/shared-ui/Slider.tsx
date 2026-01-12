"use client";

import React from "react";
import * as designSystem from "@dream-flow/design-system";

const { colors, typography, spacing } = designSystem;

interface SliderProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  style?: React.CSSProperties;
}

export function Slider({ label, style, ...props }: SliderProps) {
  return (
    <div style={{ width: "100%", ...style }}>
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
      <input
        type="range"
        style={{
          width: "100%",
          height: "6px",
          background: colors.background.glass,
          outline: "none",
          cursor: "pointer",
        }}
        {...props}
      />
    </div>
  );
}

