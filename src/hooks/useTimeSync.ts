import { useState, useEffect, useRef, useCallback } from "react";

export type TimeSource = "gnss" | "device";
export type SyncStatus = "acquiring" | "synced" | "drift-warning" | "unavailable";

export interface SyncedTime {
  hours: number;
  minutes: number;
  seconds: number;
  milliseconds: number;
  timeSource: TimeSource;
  syncStatus: SyncStatus;
}

export function useTimeSync(gaFramTidEnabled: boolean, gaFramTidOffsetMin: number) {
  const [syncedTime, setSyncedTime] = useState<SyncedTime>({
    hours: 0, minutes: 0, seconds: 0, milliseconds: 0,
    timeSource: "device", syncStatus: "acquiring",
  });

  const gpsOffsetRef = useRef<number | null>(null); // ms difference: gpsTime - Date.now()
  const lastGpsOffsetRef = useRef<number | null>(null);
  const timeSourceRef = useRef<TimeSource>("device");
  const syncStatusRef = useRef<SyncStatus>("acquiring");
  const watchIdRef = useRef<number | null>(null);

  // Start GPS watch
  useEffect(() => {
    if (!("geolocation" in navigator)) {
      timeSourceRef.current = "device";
      syncStatusRef.current = "unavailable";
      return;
    }

    syncStatusRef.current = "acquiring";

    const timeout = window.setTimeout(() => {
      // If no GPS fix after 10s, fall back to device clock
      if (syncStatusRef.current === "acquiring") {
        timeSourceRef.current = "device";
        syncStatusRef.current = "unavailable";
      }
    }, 10000);

    watchIdRef.current = navigator.geolocation.watchPosition(
      (position) => {
        const gpsTime = position.timestamp;
        const deviceTime = Date.now();
        const offset = gpsTime - deviceTime;

        // Drift warning: if offset changed by more than 1s from last known
        if (lastGpsOffsetRef.current !== null && Math.abs(offset - lastGpsOffsetRef.current) > 1000) {
          syncStatusRef.current = "drift-warning";
        } else {
          syncStatusRef.current = "synced";
        }

        lastGpsOffsetRef.current = gpsOffsetRef.current;
        gpsOffsetRef.current = offset;
        timeSourceRef.current = "gnss";
      },
      () => {
        // Permission denied or error
        if (syncStatusRef.current === "acquiring") {
          timeSourceRef.current = "device";
          syncStatusRef.current = "unavailable";
        }
      },
      { enableHighAccuracy: true, maximumAge: 1000, timeout: 5000 }
    );

    return () => {
      clearTimeout(timeout);
      if (watchIdRef.current !== null) {
        navigator.geolocation.clearWatch(watchIdRef.current);
      }
    };
  }, []);

  // Animation frame loop for time display
  useEffect(() => {
    let raf: number;

    const tick = () => {
      const now = Date.now();
      const offset = gpsOffsetRef.current ?? 0;
      const correctedMs = now + offset;

      // Apply gå-fram-tid offset
      const gftOffsetMs = gaFramTidEnabled ? gaFramTidOffsetMin * 60 * 1000 : 0;
      const displayMs = correctedMs + gftOffsetMs;

      const date = new Date(displayMs);
      setSyncedTime({
        hours: date.getHours(),
        minutes: date.getMinutes(),
        seconds: date.getSeconds(),
        milliseconds: date.getMilliseconds(),
        timeSource: timeSourceRef.current,
        syncStatus: syncStatusRef.current,
      });

      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [gaFramTidEnabled, gaFramTidOffsetMin]);

  // Expose a function to get the current synced time in ms (for beep scheduling)
  const getSyncedNowMs = useCallback(() => {
    const now = Date.now();
    const offset = gpsOffsetRef.current ?? 0;
    const gftOffsetMs = gaFramTidEnabled ? gaFramTidOffsetMin * 60 * 1000 : 0;
    return now + offset + gftOffsetMs;
  }, [gaFramTidEnabled, gaFramTidOffsetMin]);

  return { syncedTime, getSyncedNowMs };
}
