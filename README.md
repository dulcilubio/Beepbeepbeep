# StartClock

En orienteringsklocka (startklocka) byggd som progressiv webbapp (PWA) med React och TypeScript.

## Funktioner

- **Realtidsklocka** — Visar aktuell tid i HH:MM:SS-format, maximerad för läsbarhet på avstånd
- **GPS/GNSS-tidssynk** — Synkroniserar klockan med GPS-tid via Web Geolocation API för exakt tidvisning
- **Startintervall** — Konfigurerbart intervall (10–60 sek) med visuell markering av startsekunder (grön färg)
- **Nedräkningsljud** — Automatiska pip-ljud inför varje startminut med konfigurerbar frekvens och längd
- **Gå-fram-tid** — Valfri tidsförskjutning (0–5 min) för att visa framtida tid
- **Tre monospace-typsnitt** — JetBrains Mono, IBM Plex Mono och Space Mono med bold-alternativ
- **Inverterat läge** — Ljus bakgrund med mörk text för utomhusbruk i starkt ljus
- **Skärmvakenhållning** — Håller skärmen tänd via Wake Lock API + osynlig videoloop som fallback
- **PWA-stöd** — Installerbar som app med offline-funktion, manifest och service worker
- **Statusfält** — Visar tidskälla (GNSS/Device), synkstatus och gå-fram-tid-offset

## Teknikstack

- React 18 + TypeScript 5
- Vite 5
- Tailwind CSS v3
- Web Audio API (pip-ljud)
- Wake Lock API + video-fallback
- @fontsource för lokal typsnittsbundling

## Användning

Appen är designad för orienterings- och skidstartar. Placera enheten synligt vid startplatsen — klockan fyller skärmen och visar exakt tid med automatiska startpip.
