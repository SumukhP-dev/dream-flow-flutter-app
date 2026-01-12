// Design system exports
export const colors = {
  // Primary colors
  primary: {
    purple: "#8B5CF6",
    blue: "#3B82F6",
  },
  // Secondary colors
  secondary: {
    cyan: "#06B6D4",
    skyBlue: "#0EA5E9",
  },
  // Background colors
  background: {
    primary: "#0A0A0A",
    secondary: "#05020C",
    tertiary: "#07040F",
    gradientStart: "#120E2B",
    surface: "#1A1A1A",
    glass: "rgba(255, 255, 255, 0.04)",
  },
  // Text colors
  text: {
    primary: "#FFFFFF",
    secondary: "rgba(255, 255, 255, 0.9)",
    tertiary: "rgba(255, 255, 255, 0.75)",
    quaternary: "rgba(255, 255, 255, 0.7)",
    disabled: "rgba(255, 255, 255, 0.6)",
    muted: "rgba(255, 255, 255, 0.65)",
    grey: "#BDBDBD",
  },
  // Border colors
  border: {
    default: "rgba(255, 255, 255, 0.2)",
    focus: "#8B5CF6",
    error: "#FF0000",
    subtle: "rgba(255, 255, 255, 0.1)",
  },
  // Status colors
  status: {
    success: "#16A34A",
    error: "#FF0000",
    errorAccent: "#FF5252",
    warning: "#F59E0B",
    info: "#3B82F6",
  },
};

export const typography = {
  fontFamily: {
    primary: "Inter, system-ui, -apple-system, sans-serif",
    secondary: "Georgia, serif",
  },
  fontSize: {
    headlineLarge: "32px",
    titleLarge: "28px",
    titleMedium: "24px",
    titleSmall: "20px",
    bodyLarge: "18px",
    bodyMedium: "16px",
    bodySmall: "14px",
    labelLarge: "16px",
    labelMedium: "14px",
    labelSmall: "12px",
  },
  fontWeight: {
    light: 300,
    regular: 400,
    medium: 500,
    semibold: 600,
    bold: 700,
  },
  lineHeight: {
    tight: "1.2",
    normal: "1.5",
    relaxed: "1.75",
  },
};

export const spacing = {
  xs: 4,
  s: 8,
  m: 16,
  l: 24,
  xl: 32,
  xxl: 48,
  xxxl: 64,
  xxxxl: 96,
  xxxxxl: 128,
};

export const borderRadius = {
  small: "4px",
  medium: "8px",
  large: "12px",
  xl: "16px",
  xxl: "24px",
  full: "9999px",
};

export const gradients = {
  radial: {
    purple: {
      color: "#8B5CF6",
      opacity: 0.3,
    },
    blue: {
      color: "#3B82F6",
      opacity: 0.25,
    },
    cyan: {
      color: "#06B6D4",
      opacity: 0.2,
    },
  },
  linear: {
    purpleToBlue: "linear-gradient(135deg, #8B5CF6 0%, #3B82F6 100%)",
    blueToCyan: "linear-gradient(135deg, #3B82F6 0%, #06B6D4 100%)",
    purpleToCyan: "linear-gradient(135deg, #8B5CF6 0%, #06B6D4 100%)",
  },
};
