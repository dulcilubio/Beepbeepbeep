#!/usr/bin/env python3
"""Capture the App Store screenshot set from the simulator.

The app is seeded directly through its UserDefaults plist — an invented start
list timed off the wall clock, so every scene shows runners about to go. Names,
clubs and the competition are placeholders, never real entrants.

    python3 tools/screenshots.py <path-to-startclock.app> <output-dir> \\
        <iphone-udid> <ipad-udid> [--rotate]

Landscape: rotate both simulators first (Simulator, Cmd+Left), then pass
--rotate, which turns the captured frames upright. The framebuffer stays
portrait-shaped however the device is held, so without it the images come out
on their side.

The control strip auto-hides a few seconds after launch, so it is absent from
these shots; to get it, tap the screen and capture within the second.
"""

import datetime
import json
import pathlib
import plistlib
import subprocess
import sys
import time

BUNDLE = "se.erikfrick.startclock"

NAMES = [
    ("Anna Andersson", "Granliden OK", "H21"), ("Bertil Berg", "Sjölunda OK", "D16"),
    ("Cecilia Carlsson", "Hagaby IF", "D45"), ("David Dahl", "Ekeby OK", "H80"),
    ("Elin Ek", "Norrvik OK", "H65"), ("Fredrik Falk", "Tallåsens OK", "D70"),
    ("Greta Gran", "Kvarnbäcken SK", "H70"), ("Hugo Holm", "Björkby SK", "H14"),
    ("Ida Isaksson", "Granliden OK", "D80"), ("Johan Jansson", "Sjölunda OK", "H12"),
    ("Karin Krantz", "Hagaby IF", "H10"), ("Lars Lind", "Ekeby OK", "D55"),
    ("Maja Malm", "Norrvik OK", "H50"), ("Nils Nyström", "Tallåsens OK", "D35"),
    ("Olga Ohlsson", "Kvarnbäcken SK", "H35"), ("Per Persson", "Björkby SK", "H40"),
]

SCENES = {
    "1-startlist": {"clockFont": "sfpro", "bannerTextScale": 1.5},
    "2-lead-time": {"clockFont": "sfpro", "bannerTextScale": 1.4,
                    "gaFramTidEnabled": True, "gaFramTidOffsetMin": 3},
    "3-outdoor":   {"clockFont": "sfpro", "bannerTextScale": 1.5, "invertedMode": True},
    "4-analog":    {"clockFont": "analog", "bannerTextScale": 1.3},
    "5-flapboard": {"clockFont": "flapBoard", "bannerTextScale": 1.3},
}


def sh(*args):
    return subprocess.run(args, capture_output=True, text=True)


def start_list():
    """Four runners a minute for ten minutes, starting one minute ago."""
    now = datetime.datetime.now()
    base = now.replace(second=0, microsecond=0) - datetime.timedelta(minutes=1)
    entries = []
    for minute in range(10):
        when = base + datetime.timedelta(minutes=minute)
        centis = (when.hour * 3600 + when.minute * 60) * 100
        for name, club, cls in NAMES[(minute * 4) % len(NAMES):][:4]:
            entries.append({"name": name, "club": club, "start": centis, "className": cls})
    # Foundation encodes dates as seconds since the 2001 reference date.
    stamp = now.timestamp() - datetime.datetime(2001, 1, 1).timestamp()
    return json.dumps({"name": "Höstträffen 2026", "importedAt": stamp,
                       "entries": entries}).encode()


def seed(udid, extra):
    container = sh("xcrun", "simctl", "get_app_container", udid, BUNDLE, "data").stdout.strip()
    prefs = pathlib.Path(container) / "Library/Preferences"
    prefs.mkdir(parents=True, exist_ok=True)
    values = {
        "eventorOfflineList": start_list(),
        "eventorURL": "https://eventor.se/event/56028/start-list",
        "beepEnabled": True, "startInterval": 60, "clockBold": True,
    }
    values.update(extra)
    with open(prefs / f"{BUNDLE}.plist", "wb") as f:
        plistlib.dump(values, f)


def capture(udid, device, scene, extra, out, rotate):
    sh("xcrun", "simctl", "terminate", udid, BUNDLE)
    time.sleep(1)
    seed(udid, extra)
    now = datetime.datetime.now()
    sh("xcrun", "simctl", "status_bar", udid, "override",
       "--time", now.strftime("%H:%M"), "--batteryState", "charged",
       "--batteryLevel", "100", "--wifiBars", "3")
    sh("xcrun", "simctl", "launch", udid, BUNDLE)
    time.sleep(9)  # let the chrome auto-hide
    path = out / f"{device}-{scene}.png"
    sh("xcrun", "simctl", "io", udid, "screenshot", str(path))
    if rotate:
        sh("sips", "-r", "270", str(path))
    print(f"  {path.name}")


def main():
    args = [a for a in sys.argv[1:] if a != "--rotate"]
    rotate = "--rotate" in sys.argv
    if len(args) != 4:
        sys.exit(__doc__)
    app, out = args[0], pathlib.Path(args[1])
    out.mkdir(parents=True, exist_ok=True)

    for device, udid in [("iphone-6.9", args[2]), ("ipad-13", args[3])]:
        print(device)
        sh("xcrun", "simctl", "boot", udid)
        sh("xcrun", "simctl", "bootstatus", udid, "-b")
        sh("xcrun", "simctl", "install", udid, app)
        sh("xcrun", "simctl", "privacy", udid, "grant", "location", BUNDLE)
        for scene, extra in SCENES.items():
            capture(udid, device, scene, extra, out, rotate)
        sh("xcrun", "simctl", "status_bar", udid, "clear")


if __name__ == "__main__":
    main()
