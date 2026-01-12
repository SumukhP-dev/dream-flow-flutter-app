"use client";

import React, { useEffect, useState } from "react";
import * as designSystem from "@dream-flow/design-system";

const { colors, typography, spacing, borderRadius } = designSystem;

export type ToastType = "success" | "error" | "warning" | "info";

export interface Toast {
  id: string;
  message: string;
  type: ToastType;
  duration?: number;
}

interface ToastProps {
  toast: Toast;
  onDismiss: (id: string) => void;
}

function ToastComponent({ toast, onDismiss }: ToastProps) {
  const [isExiting, setIsExiting] = useState(false);

  useEffect(() => {
    if (toast.duration && toast.duration > 0) {
      const timer = setTimeout(() => {
        setIsExiting(true);
        setTimeout(() => onDismiss(toast.id), 300);
      }, toast.duration);
      return () => clearTimeout(timer);
    }
  }, [toast.id, toast.duration, onDismiss]);

  const typeStyles: Record<ToastType, React.CSSProperties> = {
    success: {
      backgroundColor: `${colors.status.success}26`,
      borderColor: colors.status.success,
      color: colors.status.success,
    },
    error: {
      backgroundColor: `${colors.status.error}26`,
      borderColor: colors.status.error,
      color: colors.status.error,
    },
    warning: {
      backgroundColor: `${colors.status.warning}26`,
      borderColor: colors.status.warning,
      color: colors.status.warning,
    },
    info: {
      backgroundColor: `${colors.primary.purple}26`,
      borderColor: colors.primary.purple,
      color: colors.primary.purple,
    },
  };

  const icons: Record<ToastType, string> = {
    success: "✓",
    error: "✕",
    warning: "⚠",
    info: "ℹ",
  };

  return (
    <div
      style={{
        ...typeStyles[toast.type],
        border: `1px solid`,
        borderRadius: borderRadius.medium,
        padding: `${spacing.m}px ${spacing.l}px`,
        marginBottom: spacing.s,
        display: "flex",
        alignItems: "center",
        gap: spacing.m,
        minWidth: "300px",
        maxWidth: "500px",
        boxShadow: "0 4px 12px rgba(0, 0, 0, 0.3)",
        backdropFilter: "blur(10px)",
        opacity: isExiting ? 0 : 1,
        transform: isExiting ? "translateX(100%)" : "translateX(0)",
        transition: "all 0.3s ease",
        cursor: "pointer",
      }}
      onClick={() => {
        setIsExiting(true);
        setTimeout(() => onDismiss(toast.id), 300);
      }}
      role="alert"
      aria-live="polite"
    >
      <span
        style={{
          fontSize: typography.fontSize.titleMedium,
          fontWeight: typography.fontWeight.bold,
        }}
      >
        {icons[toast.type]}
      </span>
      <span
        style={{
          flex: 1,
          fontSize: typography.fontSize.bodyMedium,
          color: colors.text.primary,
        }}
      >
        {toast.message}
      </span>
      <button
        onClick={(e) => {
          e.stopPropagation();
          setIsExiting(true);
          setTimeout(() => onDismiss(toast.id), 300);
        }}
        style={{
          background: "transparent",
          border: "none",
          color: colors.text.secondary,
          cursor: "pointer",
          fontSize: typography.fontSize.titleMedium,
          padding: spacing.xs,
          lineHeight: 1,
        }}
        aria-label="Dismiss notification"
      >
        ×
      </button>
    </div>
  );
}

interface ToastContainerProps {
  toasts: Toast[];
  onDismiss: (id: string) => void;
}

export function ToastContainer({ toasts, onDismiss }: ToastContainerProps) {
  if (toasts.length === 0) return null;

  return (
    <div
      style={{
        position: "fixed",
        top: spacing.xl,
        right: spacing.xl,
        zIndex: 10000,
        display: "flex",
        flexDirection: "column",
        pointerEvents: "none",
      }}
    >
      {toasts.map((toast) => (
        <div key={toast.id} style={{ pointerEvents: "auto" }}>
          <ToastComponent toast={toast} onDismiss={onDismiss} />
        </div>
      ))}
    </div>
  );
}

// Hook for managing toasts
export function useToast() {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const showToast = (
    message: string,
    type: ToastType = "info",
    duration: number = 5000
  ) => {
    const id = `toast-${Date.now()}-${Math.random()}`;
    const newToast: Toast = { id, message, type, duration };
    setToasts((prev) => [...prev, newToast]);
    return id;
  };

  const dismissToast = (id: string) => {
    setToasts((prev) => prev.filter((toast) => toast.id !== id));
  };

  const ToastProvider = () => (
    <ToastContainer toasts={toasts} onDismiss={dismissToast} />
  );

  return { showToast, dismissToast, ToastProvider };
}

