import { useEffect, useRef } from "react";

export function useWakeLock() {
  const refs = useRef<{ wakeLock: WakeLockSentinel | null; video: HTMLVideoElement | null }>({
    wakeLock: null,
    video: null,
  });

  useEffect(() => {
    const requestWakeLock = async () => {
      try {
        if ("wakeLock" in navigator) {
          refs.current.wakeLock = await navigator.wakeLock.request("screen");
          return true;
        }
      } catch {}
      return false;
    };

    const startVideoFallback = () => {
      if (refs.current.video) return;
      const video = document.createElement("video");
      video.setAttribute("playsinline", "");
      video.setAttribute("muted", "");
      video.muted = true;
      video.loop = true;
      video.style.cssText =
        "position:fixed;top:-1px;left:-1px;width:1px;height:1px;opacity:0.01;pointer-events:none;z-index:-1";
      // Tiny silent mp4
      video.src =
        "data:video/mp4;base64,AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAAhtZGF0AAAA1m1vb3YAAABsbXZoZAAAAAAAAAAAAAAAAAAAA+gAAAAAAAEAAAEAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAABidWR0YQAAAFptZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAAC1pbG9jAAAARAAAAQAAAAAAAQAAAAAAAQAAAAAAAAAAAAEAAAAsaXBycAAAABRpcGNvAAAAFGlzcGUAAAAAAAAAAAAAAAAQcGl4aQ==";
      document.body.appendChild(video);
      video.play().catch(() => {});
      refs.current.video = video;
    };

    const init = async () => {
      const gotLock = await requestWakeLock();
      if (!gotLock) startVideoFallback();
    };

    init();

    const handleVisibility = async () => {
      if (document.visibilityState === "visible") {
        const gotLock = await requestWakeLock();
        if (!gotLock && !refs.current.video) startVideoFallback();
        refs.current.video?.play().catch(() => {});
      }
    };

    document.addEventListener("visibilitychange", handleVisibility);

    return () => {
      document.removeEventListener("visibilitychange", handleVisibility);
      refs.current.wakeLock?.release().catch(() => {});
      if (refs.current.video) {
        refs.current.video.pause();
        refs.current.video.remove();
        refs.current.video = null;
      }
    };
  }, []);
}
