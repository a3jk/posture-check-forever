# Posture Check

A small World of Warcraft: Forever addon that reminds you to sit up straight. A bar fills over a configurable time while a character's posture slowly gets worse. When the bar is full, a sound plays (a bell by default).

Two characters are available:

- **Lazy Peon (3D)** uses the game's own Lazy Peon model. He works, then stands around, sits down, falls asleep, and at 90% turns into a sack.
- **Pixel orc** is a hand-made pixel-art orc whose back slowly rounds. At 90% he turns into a sack of potatoes.

## Install

Copy the `PostureCheck` folder into the game's `Interface/AddOns/` folder (`_classic_beta_` during the beta; the folder name at launch may differ).

The addon also runs on Classic Era: copy the same folder into `_classic_era_/Interface/AddOns/`.

| Client | TOC file | Interface |
| --- | --- | --- |
| WoW: Forever | `PostureCheck.toc` | `16001` |
| Classic Era | `PostureCheck_Vanilla.toc` | `11509` |

Classic Era loads the `_Vanilla` TOC first and ignores the other one. If a client flags the addon as out of date, check the current value with `/dump select(4, GetBuildInfo())` and update `## Interface:` in that client's TOC. Keep the file lists in both TOCs the same.

## Usage

- **Minimap button:** left-click opens settings, right-click resets the timer, and holding the middle mouse button (MOUSE3) while dragging moves the button around the minimap.
- **Timer frame:** left-drag to move it (unless locked) and right-click to reset the timer.
- **Slash commands:** `/posture` (or `/pcheck`) with `config`, `reset`, `show`, `hide` or `lock`. `/posture preview 80` holds the display at 80% so you can check a stage; `/posture preview` turns it off.

## Settings

**General:** timer length (1–120 minutes), scale (0.5–2.0), alert sound (built-in presets, or a custom SoundKit ID/name or FileDataID), character, show the timer or the character, lock the position, restart automatically, show an on-screen warning.

**Timer Bar:** show the bar or only the time as text, width, height, texture, color (green to red, class color or fixed colors), border (none, cast bar, tooltip, dialog, gold dialog, thin line), spark, and text on the bar.

**Frame:** border and background style around the whole timer (tooltip, dialog, marble, rock, solid…) and background opacity. Both are off by default.
