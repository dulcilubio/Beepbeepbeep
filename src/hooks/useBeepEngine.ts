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
        const interval = settings.startInterval;

        // Avoid double-beeping the same second
        if (currentSec !== lastBeepSecondRef.current) {
          lastBeepSecondRef.current = currentSec;

          // Calculate if this second is a "go" second (multiple of interval)
          const isGoSec = currentSec % interval === 0;
          // Countdown beeps: 5 seconds before each go second
          const secsUntilGo = (interval - (currentSec % interval)) % interval;
          const isCountdownSec = secsUntilGo >= 1 && secsUntilGo <= 5;

          if (isCountdownSec) {
            playBeep(settings.countdownBeepHz, settings.countdownBeepMs);
          } else if (isGoSec) {
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
  }, [settings.beepsEnabled, settings.countdownBeepHz, settings.countdownBeepMs, settings.goBeepHz, settings.goBeepMs, settings.startInterval, syncStatus, getSyncedNowMs]);
}
