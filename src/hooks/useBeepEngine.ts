import { useEffect, useRef } from "react";
import { playBeep, ensureAudioResumed } from "@/lib/audioEngine";
import type { Settings } from "./useSettings";
import type { SyncStatus } from "./useTimeSync";

export function useBeepEngine(
  getSyncedNowMs: () => number,
  settings: Settings,
  syncStatus: SyncStatus
) {
  const lastBeepSecondRef = useRef<number>(-1);
  const timerRef = useRef<number | null>(null);

  useEffect(() => {
    if (!settings.beepsEnabled || syncStatus === "acquiring") {
      return;
    }

    const scheduleNext = () => {
      const nowMs = getSyncedNowMs();
      const date = new Date(nowMs);
      const sec = date.getSeconds();
      const ms = date.getMilliseconds();

      // Calculate ms until next second boundary
      const msUntilNextSec = 1000 - ms;

      timerRef.current = window.setTimeout(() => {
        const currentMs = getSyncedNowMs();
        const currentDate = new Date(currentMs);
        const currentSec = currentDate.getSeconds();

        // Avoid double-beeping the same second
        if (currentSec !== lastBeepSecondRef.current) {
          lastBeepSecondRef.current = currentSec;

          if (currentSec >= 55 && currentSec <= 59) {
            // Countdown beeps
            playBeep(settings.countdownBeepHz, settings.countdownBeepMs);
          } else if (currentSec === 0) {
            // Go beep
            playBeep(settings.goBeepHz, settings.goBeepMs);
          }
        }

        scheduleNext();
      }, Math.max(msUntilNextSec - 20, 10)); // Fire slightly early for precision
    };

    scheduleNext();

    return () => {
      if (timerRef.current !== null) {
        clearTimeout(timerRef.current);
      }
    };
  }, [settings.beepsEnabled, settings.countdownBeepHz, settings.countdownBeepMs, settings.goBeepHz, settings.goBeepMs, syncStatus, getSyncedNowMs]);
}
