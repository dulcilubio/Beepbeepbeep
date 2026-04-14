import { useEffect, useRef } from "react";

// Tiny base64-encoded silent video (1-second black, no audio)
const SILENT_VIDEO_SRC =
  "data:video/mp4;base64,AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAAhtZGF0AAAA1m1vb3YAAABsbXZoZAAAAAAAAAAAAAAAAAAAA+gAAAAAAAEAAAEAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAABidWR0YQAAAFptZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAAC1pbG9jAAAARAAAAQAAAAAAAQAAAAAAAQAAAAAAAAAAAAEAAAAsaXBycAAAABRpcGNvAAAAFGlzcGUAAAAAAAAAAAAAAAAQcGl4aQ==";

export function useWakeLock() {
  const wakeLockRef = useRef<WakeLockSentinel | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);

  useEffect(() => {
    let wakeLockSupported = "wakeLock" in navigator;

    const requestWakeLock = async () => {
      try {
        if (wakeLockSupported) {
          wakeLockRef.current = await navigator.wakeLock.request("screen");
          return true;
        }
      } catch {
        // Wake Lock failed — fall through to video fallback
      }
      return false;
    };

    const startVideoFallback = () => {
      if (videoRef.current) return; // already running
      const video = document.createElement("video");
      video.setAttribute("playsinline", "");
      video.setAttribute("muted", "");
      video.muted = true;
      video.loop = true;
      video.style.cssText =
        "position:fixed;top:-1px;left:-1px;width:1px;height:1px;opacity:0.01;pointer-events:none;z-index:-1";
      video.src = SILENT_VIDEO_SRC;
      document.body.appendChild(video);
      video.play().catch(() => {});
      videoRef.current = video;
    };

    const init = async () => {
      const gotLock = await requestWakeLock();
      if (!gotLock) {
        startVideoFallback();
      }
    };

    init();

    const handleVisibility = async () => {
      if (document.visibilityState === "visible") {
        const gotLock = await requestWakeLock();
        if (!gotLock && !videoRef.current) {
          startVideoFallback();
        }
        // Resume video if it was paused
        videoRef.current?.play().catch(() => {});
      }
    };

    document.addEventListener("visibilitychange", handleVisibility);

    return () => {
      document.removeEventListener("visibilitychange", handleVisibility);
      wakeLockRef.current?.release().catch(() => {});
      if (videoRef.current) {
        videoRef.current.pause();
        videoRef.current.remove();
        videoRef.current = null;
      }
    };
  }, []);
}
