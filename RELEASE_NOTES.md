# startclock 1.1 (build 3)

## App Store Connect — "What's New in This Version"

### Svenska

```
Startlistor och deltagarnamn

• Hämta startlistan från Liveresultat, eller importera den från Eventor i appens
  egen webbläsare. Namnen visas vid rätt minut, med klass.
• Filtrera på en eller flera klasser.
• Gå-fram-tid: låt klockan gå före så att leden kallas fram i tid.
• Namnen skalas med ett nyp på skärmen, och hela startgruppen får plats – även
  när trettio löpare startar samma minut.
• Nya urtavlor, som du väljer genom att se dem: analog, fällindikator, digital,
  och varianter som bara visar minuter eller sekunder.
• Utomhusläge och full ljusstyrka direkt på klockskärmen.
• Klockan syns på låsskärmen när den går i bakgrunden – ett tryck tar dig
  tillbaka.
• Stöd för iPad och iPhone med iOS 16.

Rättningar
• Tidssynkningen kunde bli upp till en minut fel om den första GPS-positionen
  var cachad. Klockan kräver nu flera samstämmiga positioner, och visar hur
  mycket den justerats.
• Ljudet kom inte tillbaka efter ett inkommande samtal. Det gör det nu, av sig
  självt.
• Tävlingslistan kunde vara tom på grund av trasig data från Liveresultat.
• Klassnamnen försvann när appen startades om.
• Högre kontrast i både mörkt och ljust läge.
```

### English

```
Start lists and runner names

• Load the start list from Liveresultat, or import it from Eventor in the app's
  own browser. Names appear on the right minute, with their class.
• Filter by one or several classes.
• Lead time: run the clock ahead so runners are called forward in time.
• Pinch to size the names, and the whole starting group fits on screen — even
  when thirty runners share a minute.
• New clock faces, chosen by looking at them: analogue, flap board, digital, and
  single-unit faces showing only minutes or seconds.
• Outdoor mode and full brightness right on the clock screen.
• The running clock appears on the Lock Screen when it is in the background —
  one tap brings it back.
• Supports iPad and iPhone on iOS 16.

Fixes
• Time sync could be up to a minute off when the first GPS fix was a cached one.
  The clock now requires several fixes to agree, and shows how far it has been
  corrected.
• Audio did not return after an incoming call. It now does, by itself.
• The competition list could come up empty because of malformed data from
  Liveresultat.
• Class names disappeared when the app was restarted.
• Higher contrast in both dark and light mode.
```

## Screenshots

`screenshots/` holds the sizes App Store Connect requires, captured from the
Release build on simulators:

| Folder | Device | Orientation | Size |
|---|---|---|---|
| `screenshots/iphone-6.9/` | iPhone 17 Pro Max | portrait | 1320 x 2868 |
| `screenshots/iphone-6.9-landscape/` | iPhone 17 Pro Max | landscape | 2868 x 1320 |
| `screenshots/ipad-13/` | iPad Pro 13-inch | portrait | 2064 x 2752 |
| `screenshots/ipad-13-landscape/` | iPad Pro 13-inch | landscape | 2752 x 2064 |

Five scenes in each: start list, lead time, outdoor mode, analogue face, flap
board. Each set carries a sixth as well — the clock-style picker with all twelve
faces running live (portrait), and the control strip with the beeps on
(landscape).

Landscape is how the clock is actually used at a start, so lead with those.

Notes before uploading them:
- The names, clubs and competition in the shots are invented placeholders, not
  real entrants.
- On iPhone the Dynamic Island shows the Now Playing pill, because the clock
  really is playing audio. It is honest, but crop or retake on a device if a
  cleaner status bar is wanted.

## Full changelog

```
008af3e  Prepare build 3: signing team, export compliance
84636c7  Fit a whole start group on screen instead of hiding runners
60701d8  Show the clock on the Lock Screen, add outdoor and brightness controls
4254241  Raise contrast in both modes
995992a  Order the banner by start time, and keep the clock on screen
321cc48  Focus the banner on who has not started, and let the names be resized
854e52e  Pick the clock face by looking at it
f9663be  Repair malformed liveresultat JSON, and add a unit test target
3aa58ac  Add start lists, multi-class filtering, iOS 16 support and versioning
4217d54  Fix two field failures: clock off by a minute, audio dead after a call
319a8ba  Stop tracking Xcode per-user state
```
