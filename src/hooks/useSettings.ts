import { useState, useCallback, useEffect } from "react";

export interface Settings {
  beepsEnabled: boolean;
  gaFramTidEnabled: boolean;
  gaFramTidOffset: number; // 0-5 minutes
  showStatusBar: boolean;
  countdownBeepHz: number;
  countdownBeepMs: number;
  goBeepHz: number;
  goBeepMs: number;
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
