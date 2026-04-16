import { useState, useCallback, useEffect } from "react";

export type ClockFont = "jetbrains" | "ibm" | "space";

export const CLOCK_FONTS: Record<ClockFont, { label: string; family: string }> = {
  jetbrains: { label: "JetBrains Mono", family: "'JetBrains Mono', monospace" },
  ibm: { label: "IBM Plex Mono", family: "'IBM Plex Mono', monospace" },
  space: { label: "Space Mono", family: "'Space Mono', monospace" },
};

export interface Settings {
  beepsEnabled: boolean;
  gaFramTidEnabled: boolean;
  gaFramTidOffset: number;
  showStatusBar: boolean;
  countdownBeepHz: number;
  countdownBeepMs: number;
  goBeepHz: number;
  goBeepMs: number;
  clockFont: ClockFont;
  clockBold: boolean;
  startInterval: number;
  invertedMode: boolean;
}

const DEFAULTS: Settings = {
  beepsEnabled: true,
  gaFramTidEnabled: false,
  gaFramTidOffset: 3,
  showStatusBar: true,
  countdownBeepHz: 880,
  countdownBeepMs: 100,
  goBeepHz: 1760,
  goBeepMs: 300,
  clockFont: "jetbrains",
  clockBold: false,
  startInterval: 60,
  invertedMode: false,
};

const STORAGE_KEY = "startclock-settings";

function normalizeClockFont(value: unknown): ClockFont {
  if (value === "jetbrains" || value === "ibm" || value === "space") return value;
  if (value === "fira") return "ibm";
  if (value === "source") return "space";
  return DEFAULTS.clockFont;
}

function loadSettings(): Settings {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<Settings> & { clockFont?: string };
      return {
        ...DEFAULTS,
        ...parsed,
        clockFont: normalizeClockFont(parsed.clockFont),
      };
    }
  } catch {}
  return { ...DEFAULTS };
}

export function useSettings() {
  const [settings, setSettingsState] = useState<Settings>(loadSettings);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
  }, [settings]);

  const updateSettings = useCallback((patch: Partial<Settings>) => {
    setSettingsState((prev) => ({ ...prev, ...patch }));
  }, []);

  return { settings, updateSettings };
}
