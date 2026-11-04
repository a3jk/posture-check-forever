# Cleanup TODO

Review of inconsistencies and quirks. Checked items are done; open ones still need work. Rough priority: **P1** = bug or confusing behavior users will hit, **P2** = inconsistency / UX polish, **P3** = architecture / housekeeping.

## Bugs and surprising behavior

- [x] **P1** Dragging the *Timer length* slider below the elapsed time fires the alert immediately (sound, raid warning and party/raid chat message), possibly several times while dragging. Changing the length should restart the timer or wait until the slider is released. ([Options.lua:165](PostureCheck/Options.lua#L165), [Core.lua:97](PostureCheck/Core.lua#L97))
- [x] **P1** The *Restart automatically* setting is silently ignored for the Pint character, which always waits for a click. Disable or relabel the checkbox when Pint is selected. ([Core.lua:85](PostureCheck/Core.lua#L85))
- [x] **P1** If you switch from Pint to another character while the pint is waiting for a click, the timer stays finished and flashes red forever. Nothing tells you to right-click to reset.
- [x] **P1** With *Restart automatically* off (Peon or Orc), the alert keeps pulsing until a manual reset, and nothing says how to reset.
- [x] **P2** Changing *Scale* moves the frame on screen, because the saved anchor offsets are in scaled units. ([TimerFrame.lua:163](PostureCheck/TimerFrame.lua#L163))
- [x] **P2** The custom sound label and box are hidden for non-custom sounds, but their space is still reserved, which leaves a ~46px gap in the General column. ([Options.lua:192-204](PostureCheck/Options.lua#L192-L204))
- [x] **P2** If a saved key isn't in a dropdown's list (for example a SoundKit missing on this client, or a removed style), the dropdown shows blank or stale text, while `FindStyle` / `GetSoundEntry` quietly fall back to the first entry. ([Options.lua:122](PostureCheck/Options.lua#L122))
- [x] **P2** When the pint is finished, its click area covers that part of the frame, so you can't drag the frame by the glass or get the frame's tooltip. Any mouse button refills it. ([Pint.lua:162](PostureCheck/Pint.lua#L162))
- [x] **P2** `/posture show|hide|lock` don't refresh the options panel if it's open, so its checkboxes go stale. ([Core.lua:147](PostureCheck/Core.lua#L147))
- [x] **P2** The character X/Y offset (±60) can push the character outside the frame or onto the bar, and the layout doesn't account for it. ([TimerFrame.lua:151](PostureCheck/TimerFrame.lua#L151))
- [x] **P3** `/posture preview 150` says "Previewing 150%" but clamps to 100%. ([Core.lua:156](PostureCheck/Core.lua#L156))
- [x] **P3** With the custom sound box empty, *Test sound* plays the Raid Warning fallback with no hint that the custom value is missing or invalid. ([Sounds.lua:75](PostureCheck/Sounds.lua#L75))

## UX inconsistencies

- [x] **P1** **Presets are buried** at the bottom of the 4th column (Messages), yet they change the character (General column). "What is this timer for?" (Posture / Beer) is the top-level choice and should come first.
- [x] **P1** **Options panel layout**: 4 columns × 270px ≈ 1100px wide. Settings sit in the wrong groups:
  - Character X/Y offset is under *Frame*; it belongs with *Character* in General.
  - *Show label on bar* is under Timer Bar, but the label text is under Messages.
  - *Show time* is under Timer Bar, but it also controls the big-text mode when the bar is off.
  - *Reset timer* sits next to *Test sound*, so it looks like a sound action.
- [x] **P1** **Inconsistent words for the same thing**: "timer", "timer frame", "frame", "display", "character", "orc", "figure". For example, *Show timer* hides the whole widget, while *Show timer bar* and *Show time* hide parts of it. The column named *Frame* means the border/background only.
- [x] **P2** **Reset feedback differs by entry point**: minimap right-click and `/posture reset` print "Timer reset."; frame right-click, the options button and clicking the pint print nothing.
- [x] **P2** **Slash feedback differs**: `lock` prints a message, `show`/`hide` don't. The help text leaves out the `options` alias.
- [x] **P2** **Posture wording in Beer mode**: the minimap tooltip says "Next check in …" whatever preset you use. The timer frame tooltip shows no remaining time at all, while the minimap tooltip does.
- [x] **P2** **Empty text is handled differently**: an empty warning message falls back to the default, but an empty bar label just shows nothing.
- [x] **P2** **No disabled states for dependent controls**: texture, color, border, spark, width and height stay active when the bar is off, and background opacity stays active when the background is "None".
- [x] **P2** **Three slightly different alert reds**: `ALERT_RGB {1,0.2,0.2}`, label `(1,0.25,0.25)`, and the big-text pulse formula. ([TimerFrame.lua:9](PostureCheck/TimerFrame.lua#L9), [TimerFrame.lua:273](PostureCheck/TimerFrame.lua#L273), [TimerFrame.lua:284](PostureCheck/TimerFrame.lua#L284))
- [x] **P2** **Stage thresholds differ by character**: Peon sits/sleeps at 0.6/0.75, Orc gets drowsy/dozes at 0.5/0.78, and both turn into a sack at 0.9. A shared set of stages would make "check at stage X" mean the same thing everywhere.
- [x] **P2** **Minimap button**: middle-drag to move is unusual (most addons use left-drag). There's no way to hide the button, and it assumes a round minimap.
- [x] **P2** **Presets don't set the sound**, so Beer mode still plays the alliance bell. Decide whether presets should cover sound and auto-restart too. *Decided: presets set only what depends on the purpose; the sound and looks stay yours.*
- [x] **P3** No "Reset to defaults" button. Settings don't appear in Blizzard's Interface → AddOns list.
- [ ] **P3** Sliders have no min/max labels and no way to type a value. *Partly done: the min/max labels are added; typing a value isn't.*
- [x] **P3** The custom sound entries are named "SoundKit ID or name" / "File ID or path", but the shared label under them says "SoundKit ID/name, or FileDataID/path" no matter which one is selected.

## Architecture / code consistency

- [x] **P2** **Characters are registered in three places**: `ns.CHARACTERS` ([Styles.lua:5](PostureCheck/Styles.lua#L5)), the constructor map `CHARACTERS` ([TimerFrame.lua:10](PostureCheck/TimerFrame.lua#L10)), and the TOC file list. Use one registry where each character file registers itself.
- [x] **P2** **The character interface is implicit**: every character has `frame` and `SetHunch(amount, finished)`, and only Pint has `waitsForClick`. "Hunch" makes no sense for a pint. Document the contract and rename it (e.g. `SetProgress`).
- [x] **P2** **Naming mismatch**: key `pixel` → `ns.CreateOrc` in `Orc.lua`; saved var `showOrc` controls every character. Renaming the saved var needs a DB migration.
- [x] **P2** **Duplicated pixel-art engine**: `Outline()`, grid setup and the texture-per-pixel holder are copied between [Orc.lua](PostureCheck/Orc.lua) and [Pint.lua](PostureCheck/Pint.lua), and their palette formats differ (Pint has alpha, Orc doesn't). Extract a shared `PixelCanvas`.
- [x] **P2** **Presets live in the UI file** ([Options.lua:7](PostureCheck/Options.lua#L7)). They're data/behavior and belong in Core or a presets module.
- [x] **P3** `Styles.lua` says it holds "Appearance presets for the timer bar and the frame" but also holds the character list.
- [x] **P3** The [TimerFrame.lua](PostureCheck/TimerFrame.lua#L3) header says "3D peon or pixel orc" and leaves out the pint.
- [x] **P3** The bar color fallback `{1, 0.7, 0}` duplicates the "gold" entry. ([TimerFrame.lua:54](PostureCheck/TimerFrame.lua#L54))
- [x] **P3** Saved variables have no schema version or migration path, and keys removed from defaults stay in saved data forever. ([Core.lua:39](PostureCheck/Core.lua#L39))
- [x] **P3** The custom sound box is built by hand instead of reusing `AddTextBox`, so it's a second copy of the same logic. ([Options.lua:174](PostureCheck/Options.lua#L174))
- [x] **P3** The options panel only refreshes `OnShow`, so changes made elsewhere don't show up. A small settings-changed callback would fix this and the stale-checkbox bug above.
- [ ] **P3** Strings are hard-coded English. Gather them in one place if localization is ever planned. *Not started.*

## Packaging / docs

- [ ] **P2** Two TOCs have to be kept in sync by hand (same file list, same version). Consider one TOC with a comma-separated `## Interface:` if both clients support it, or generate them. *Not started: I couldn't confirm that every client accepts a comma-separated Interface line.*
- [x] **P2** Version is hard-coded to `1.0.0`, and there's no `.pkgmeta` or `@project-version@`, even though `.gitignore` expects `.release/` and there's a CurseForge logo. Add packager config and the `X-Curse-Project-ID` metadata.
- [x] **P3** The TOC `## Notes` say "a slouching orc", but the default character is the 3D Peon.
- [x] **P3** README: the install path mentions `_classic_beta_`; the bar label is listed under both *Timer Bar* and *Messages*; the minimap's middle-drag gets its own sentence when it should just be the standard behavior.
- [x] **P3** Naming across the repo (`posture-check-forever`), the folder (`PostureCheck`) and the title (`Posture Check`) is fine, but the chat prefix color and the options title don't match any branding. Pick one accent color.
