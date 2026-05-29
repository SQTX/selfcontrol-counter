# Menu Bar Block Timer — Design

Date: 2026-05-29
Status: Approved (pending spec review)

## Goal

Add a macOS menu bar (status bar) item that shows, while a SelfControl block is
active, the SelfControl logo plus a countdown of the time remaining in the block.
The item appears when a block starts and disappears when it ends. The user can
turn the feature off via a checkbox in Preferences → General.

## Requirements

1. **Visibility:** the status item exists only while a block is active.
2. **Display format:** icon (SelfControl logo) + text, hours and minutes only,
   no seconds. Minutes are always rounded **up**: 45 seconds remaining shows
   `1m`. While time remaining is > 0 the text never shows `0`.
   - `>= 1h`: `"1h 23m"`, or `"2h"` when the minute part is 0.
   - `< 1h`: `"23m"`, down to `"1m"`.
3. **Click:** clicking the status item opens the existing floating timer window
   and brings the app to the front.
4. **Icon:** the existing SelfControl app icon, rendered as a monochrome
   template image so it adapts to light/dark menu bars.
5. **Toggle:** a checkbox in Preferences → General ("Show countdown in menu
   bar") controls whether the item is shown. Default on. Toggling takes effect
   live, including during an active block.

## Architecture

### New unit: `SCMenubarTimer` (`SCMenubarTimer.h` / `SCMenubarTimer.m`)

A small, self-contained controller owning one `NSStatusItem` and one `NSTimer`.

- State: `NSStatusItem* statusItem_`, `NSTimer* updateTimer_`, weak reference to
  the click target (`AppController`).
- Public API:
  - `- (instancetype)initWithTarget:(id)target action:(SEL)action;`
  - `- (void)show;` — idempotent. If already shown, no-op (or internally
    re-creates cleanly). Creates the status item in the system status bar
    (`[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength]`),
    sets the template logo image on `statusItem_.button.image`, wires the
    button's target/action to the click handler, performs an immediate display
    update, and starts a 1-second repeating `NSTimer`.
  - `- (void)hide;` — idempotent. Invalidates and nils the timer, removes the
    status item via `[[NSStatusBar systemStatusBar] removeStatusItem:]`, nils
    the reference.
- Display update (timer callback, runs on main thread):
  - Reads the block end date **fresh** each tick:
    `[[SCSettings sharedSettings] valueForKey:@"BlockEndDate"]`, with the same
    legacy fallback used by `TimerWindowController` (`[SCMigrationUtilities
    legacyBlockEndDate]`).
  - If the end date is nil or `timeIntervalSinceNow <= 0`: leave the icon, clear
    the text (the item will be hidden shortly by `AppController` once the block
    is detected as ended; clearing avoids showing stale/`0` text in the gap).
  - Otherwise compute `M = (NSInteger)ceil(timeIntervalSinceNow / 60.0)`,
    `h = M / 60`, `m = M % 60`, format per Requirement 2, and set
    `statusItem_.button.title`.

Rationale for reading the end date fresh each tick: "Extend Block" and other
configuration changes update `BlockEndDate` in `SCSettings`; reading live means
the menu bar countdown reflects extensions automatically with no extra signal.

### Integration: `AppController`

- New ivar `SCMenubarTimer* menubarTimer_`, created in
  `applicationDidFinishLaunching:` (target = self, action =
  `@selector(menubarTimerClicked:)`).
- New method `- (void)updateMenubarTimerVisibility`:
  - If `blockIsOn` **and** `[defaults_ boolForKey:@"ShowMenubarTimer"]`:
    `[menubarTimer_ show]`. Else `[menubarTimer_ hide]`.
- Call `updateMenubarTimerVisibility` near the end of `refreshUserInterface`
  (unconditionally — not only on the on/off transition branches). Because
  `show`/`hide` are idempotent this is safe to call on every refresh and
  correctly handles: block start, block end, and app launch while a block is
  already running.
- New click handler `- (void)menubarTimerClicked:(id)sender`:
  `[self showTimerWindow]; [NSApp activateIgnoringOtherApps:YES];`
- Register for `NSUserDefaultsDidChangeNotification` (in
  `applicationDidFinishLaunching:`) → `updateMenubarTimerVisibility`, so the
  Preferences checkbox takes effect live. Remove the observer on teardown.

This centralizes the show/hide decision in one method driven by two inputs
(block state + preference), instead of scattering `show`/`hide` across the
transition branches.

### Preference: `ShowMenubarTimer`

- Add `@"ShowMenubarTimer": @YES` to `SCConstants.defaultUserDefaults`
  (`SCConstants.m`, alongside `@"BadgeApplicationIcon": @YES`).
- Add a checkbox to `Base.lproj/PreferencesGeneralViewController.xib`,
  mirroring the existing "Show countdown in Dock" checkbox
  (cell id `deK-DV-3UF`, binding id `nIQ-e7-3Xl` → `values.BadgeApplicationIcon`):
  - New `NSButton` with a check `buttonCell`, title "Show countdown in menu bar".
  - `binding` `value` → `keyPath="values.ShowMenubarTimer"`,
    destination = the shared `NSUserDefaultsController` (`4wD-T6-SpY`).
  - Positioned in the General pane layout next to the Dock countdown checkbox.
  - Risk: hand-editing the xib XML (frames/constraints/ids). Mitigation: copy
    the exact structure of the working Dock checkbox, use fresh unique object
    ids, keep autolayout/frame attributes consistent with the sibling control.

## Data Flow

```
block starts/ends  ──► AppController.refreshUserInterface
                         └─► updateMenubarTimerVisibility
                               ├─ blockIsOn && pref ──► SCMenubarTimer.show ──► 1s NSTimer
                               │                                                  └─► read BlockEndDate (live) ──► format ──► button.title
                               └─ else ──────────────► SCMenubarTimer.hide

prefs checkbox toggled ─► NSUserDefaultsDidChangeNotification ─► updateMenubarTimerVisibility (same as above)

status item clicked ───► AppController.menubarTimerClicked: ─► showTimerWindow + activate app
```

## Error Handling / Edge Cases

- `BlockEndDate` nil while shown → clear text, no crash (hidden shortly after).
- Double `show` / double `hide` → idempotent, no leaked status items.
- App launched with a block already running → first `refreshUserInterface`
  detects `blockIsOn` and shows the item.
- Time at/below zero ("Finishing" window in `TimerWindowController`) → menu bar
  text cleared; item removed once block detected as ended.
- No new third-party dependencies; pure AppKit (`NSStatusItem` available since
  macOS 10.0).

## Testing (manual)

1. Start a block → logo + countdown (minutes) appears in the menu bar.
2. Watch the countdown decrease minute by minute; with <1 min left it shows `1m`.
3. Click the item → floating timer window opens and app comes to front.
4. Extend the block → menu bar countdown increases to match.
5. End the block (or let it expire) → status item disappears.
6. Preferences → General → uncheck "Show countdown in menu bar" during a block →
   item disappears immediately; re-check → reappears.
7. With the checkbox off, start a block → item does not appear.

## Out of Scope (YAGNI)

- Menu / popover on the status item (click opens the existing window instead).
- Seconds display.
- Hiding the Dock icon / making the app a menu bar agent (LSUIElement).
- Showing the item when no block is active.
