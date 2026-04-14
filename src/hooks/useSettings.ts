import { useState, useCallback, useEffect } from "react";

export type ClockFont = "jetbrains" | "fira" | "source";

export const CLOCK_FONTS: Record<ClockFont, { label: string; family: string }> = {
  jetbrains: { label: "JetBrains Mono", family: "'JetBrains Mono', monospace" },
  fira: { label: "Fira Code", family: "'Fira Code', monospace" },
  source: { label: "Source Code Pro", family: "'Source Code Pro', monospace" },
};

export interface Settings {
  beepsEnabled: boolean;
  gaFramTidEnabled: boolean;
  gaFramTidOffset: number; // 0-5 minutes
  showStatusBar: boolean;
  countdownBeepHz: number;
  countdownBeepMs: number;
  goBeepHz: number;
  goBeepMs: number;
  clockFont: ClockFont;
  startInterval: number; // 10-60 seconds, step 10
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
  startInterval: 60,
};

const STORAGE_KEY = "startclock-settings";

function loadSettings(): Settings {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return { ...DEFAULTS, ...JSON.parse(raw) };
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
