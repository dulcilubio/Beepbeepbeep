

# startclock — Implementation Plan

## Summary
Build the orienteering start clock PWA: fullscreen time display with GPS sync, countdown beeps, gå-fram-tid mode, and settings screen.

## Architecture

```text
src/
├── hooks/
│   ├── useTimeSync.ts        # GPS/device clock sync engine
│   ├── useBeepEngine.ts      # Web Audio API beep scheduling
│   ├── useWakeLock.ts        # Screen Wake Lock API
│   └── useSettings.ts        # localStorage-persisted settings
├── components/
│   ├── ClockDisplay.tsx      # Large hh:mm:ss display
│   ├── StatusBar.tsx         # Time source + sync status + gå-fram-tid indicator
│   ├── BottomBar.tsx         # Beep toggle + settings button
│   └── SettingsScreen.tsx    # Full settings panel (sheet/dialog)
├── lib/
│   └── audioEngine.ts        # Web Audio oscillator helpers
└── pages/
    └── Index.tsx             # Main screen composition
```

## Step-by-step

### 1. Settings hook & persistence
- `useSettings` hook with localStorage backing
- State: `beepsEnabled` (bool), `gaFramTidEnabled` (bool), `gaFramTidOffset` (0-5 min, default 3), `showStatusBar` (bool, default true), `countdownBeepHz` (default 880), `countdownBeepMs` (default 100), `goBeepHz` (default 1760), `goBeepMs` (default 300)

### 2. Time sync engine (`useTimeSync`)
- Request Geolocation API with `enableHighAccuracy: true`
- Calculate offset: `gpsTimestamp - performance.now()` to derive accurate wall clock
- Track sync state: `acquiring` → `synced` / `device-clock` (fallback)
- Continuously poll GPS (watchPosition) and update offset
- Drift warning if offset change > ±1s
- Apply gå-fram-tid offset to displayed time
- Return: `{ hours, minutes, seconds, timeSource, syncStatus }`

### 3. Beep engine (`useBeepEngine`)
- Web Audio API: create `OscillatorNode` for each beep
- Schedule beeps at ss=55-59 (countdown) and ss=00 (go-beep) of the **synced** time (including gå-fram-tid offset)
- Use `AudioContext.currentTime` for precise scheduling
- Countdown beep: configurable Hz/duration (default 880Hz/100ms)
- Go-beep: higher frequency, longer (default 1760Hz/300ms)
- Suspend beeps while sync status is "acquiring"
- Require user interaction to unlock AudioContext (tap-to-start or beep toggle)

### 4. Wake Lock (`useWakeLock`)
- Request `navigator.wakeLock.request('screen')` on mount
- Re-acquire on visibility change

### 5. Main screen UI (`Index.tsx`)
- **ClockDisplay**: Fullscreen centered `hh:mm:ss` in JetBrains Mono, white on black, responsive font sizing (`clamp()` or viewport units)
- **StatusBar** (top): Small muted text showing time source (GNSS/Device), sync status (Acquiring.../Synced/Drift Warning), gå-fram-tid indicator (+3 min). Hideable via settings.
- **BottomBar** (bottom): Beep on/off toggle (left), Settings gear icon (right). Min 44px touch targets.

### 6. Settings screen
- Slide-up sheet (using existing Sheet component)
- Sections: Time Source (read-only display), Gå-fram-tid (toggle + offset slider 0-5), Audio (beep toggle + Hz/duration sliders), Display (show/hide status bar)
- Changes apply immediately, persisted to localStorage

### 7. PWA setup
- Add `manifest.json` (name: "startclock", display: standalone, theme: #000000, icons)
- Configure `vite-plugin-pwa` (already in deps) with iframe/preview guard per Lovable PWA guidelines
- Service worker for offline caching with `devOptions: { enabled: false }`

### 8. Polish
- Update `index.html` title/meta to "startclock"
- Visual flash on go-beep second (subtle green pulse)
- Handle geolocation permission denial gracefully with user guidance message

## Technical Notes
- No NTP client in browser JS — for PWA, fallback is device clock (NTP is native-only). Could add `worldtimeapi.org` fetch as a rough NTP proxy.
- GPS time from Geolocation API: `position.timestamp` is milliseconds since epoch — compare with `Date.now()` to compute offset.
- Beep scheduling: use `setTimeout` aligned to next target second via synced time, with `AudioContext.currentTime` for sub-ms precision.
- All audio requires user gesture to unlock — the beep toggle tap serves this purpose.

