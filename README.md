# Posture Check

A small World of Warcraft: Forever addon that reminds you to sit up straight. A bar fills over a configurable time while a character's posture slowly gets worse. When the bar is full, a sound plays (a bell by default).

The bar label and the warning message can be changed, so the timer works for other reminders too. With the **Beer** preset it becomes a drinking pace timer: everyone in the party sets the same timer length, and the warning (optionally posted in party/raid chat) says when your pint should be finished.

Three characters are available:

- **Lazy Peon (3D)** uses the game's own Lazy Peon model. He works, then stands around, sits down, falls asleep, and turns into a sack.
- **Pixel orc** is a hand-made pixel-art orc seen from the front. He breathes and blinks while his head sinks, his shoulders round and his belly pushes out; then he gets drowsy, dozes off (with a floating "z"), and turns into a sack of potatoes.
- **Pint of beer** is a pixel-art pint glass with a foamy head. The beer drains as time runs out, leaving foam rings on the glass. When it is empty the glass spins upside down and blinks, and the timer waits until you click the glass for the next pint.

The peon and the orc go through the same stages: drowsy at 50%, asleep at 75%, and a sack at 90%.

## Install

Copy the `PostureCheck` folder into the game's `Interface/AddOns/` folder.

The addon also runs on Classic Era: copy the same folder into `_classic_era_/Interface/AddOns/`.

| Client | TOC file | Interface |
| --- | --- | --- |
| WoW: Forever | `PostureCheck.toc` | `16001` |
| Classic Era | `PostureCheck_Vanilla.toc` | `11509` |

Classic Era loads the `_Vanilla` TOC first and ignores the other one. If a client flags the addon as out of date, check the current value with `/dump select(4, GetBuildInfo())` and update `## Interface:` in that client's TOC. Keep the file lists in both TOCs the same.

Releases are built with the BigWigs packager (see `.pkgmeta`), which fills in `@project-version@` in the TOCs.

## Usage

- **Timer window:** drag to move it (unless locked), right-click to restart the timer, and hover to see the time left. When the pint is empty, click the glass to start the next one.
- **Minimap button:** left-click opens the settings, right-click restarts the timer, and drag moves the button around the minimap. It can be hidden in the settings or with `/posture minimap`.
- **Slash commands:** `/posture` (or `/pcheck`) with `config`, `reset`, `show`, `hide`, `lock` or `minimap`. `/posture preview 80` holds the display at 80% so you can check a stage; `/posture preview` turns it off.

The settings also have a page under the game's AddOns options that opens the panel.

## Settings

**Timer:** what it's used for (the **Posture** and **Beer** presets set the character, bar label and warning message), timer length (1–120 minutes; changing it restarts the timer), restart automatically (the pint always waits for a click instead), the warning message, whether it shows on screen (raid warning style) and whether it is also sent to party or raid chat (off by default), and the alert sound (built-in presets, or a custom SoundKit ID/name or FileDataID/path).

**Window:** show the timer window, lock its position, show the minimap button, scale (50–200%), character, show the character and nudge it with an offset, and the border, background and background opacity of the window. Border and background are off by default.

**Bar:** show the bar and the time separately (with the bar off, the time is shown as large text; with both off, only the character is left), the label on the bar, width, height, texture, color (green to red, class color or fixed colors), border (none, cast bar, tooltip, dialog, gold dialog, thin line) and spark.

**Defaults** resets every setting except where the window and the minimap button are.
