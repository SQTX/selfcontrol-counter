# Menu Bar Block Timer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a SelfControl logo + remaining-time countdown in the macOS menu bar while a block is active, with a Preferences toggle to disable it.

**Architecture:** A new self-contained `SCMenubarTimer` class owns one `NSStatusItem` and one 1-second `NSTimer`. `AppController` decides visibility from two inputs (block active? + preference on?) in one method, called from `refreshUserInterface` and from a `NSUserDefaultsDidChangeNotification` observer. Time-formatting is a pure class method (unit-tested); the status-item UI is verified manually.

**Tech Stack:** Objective-C, AppKit (`NSStatusBar`/`NSStatusItem`/`NSTimer`), XCTest, `xcodeproj` ruby gem for project-file edits, `xcodebuild` for build/test.

**Spec:** [docs/superpowers/specs/2026-05-29-menubar-timer-design.md](../specs/2026-05-29-menubar-timer-design.md)

---

## Background facts (verified, do not re-discover)

- Block end date lives in `SCSettings` under key `@"BlockEndDate"`; legacy fallback is `[SCMigrationUtilities legacyBlockEndDate]` (pattern used in `TimerWindowController.m:84-87`).
- `AppController.refreshUserInterface` (`AppController.m:165-272`) is the single on↔off transition point; `blockIsOn` is set from `[SCUIUtilities blockIsRunning]`. Method ends with `[refreshUILock_ unlock]` at `AppController.m:271`.
- `AppController.applicationDidFinishLaunching:` is at `AppController.m:347`; it calls `[self refreshUserInterface]` at `AppController.m:420`.
- Default user-defaults dict is `SCConstants.defaultUserDefaults` (`SCConstants.m:38-73`), registered at `AppController.m:52`. Existing checkbox key `@"BadgeApplicationIcon": @YES` at `SCConstants.m:49`.
- The General preferences pane is `Base.lproj/PreferencesGeneralViewController.xib`. Shared `NSUserDefaultsController` has id `4wD-T6-SpY`. The "Show countdown in Dock" checkbox (button id `wSe-TV-7lB`, cell id `deK-DV-3UF`) is bound `value` → `values.BadgeApplicationIcon` (binding id `nIQ-e7-3Xl`) and sits at `rect x=18 y=19 width=444 height=18`. The `customView` (id `Hz6-mo-xeY`) is `width=480 height=198`; checkboxes are stacked at y = 19, 53, 87, 120, 154.
- The `SelfControlTests` target has **no** `TEST_HOST`/`BUNDLE_LOADER` — it is a standalone logic-test bundle that compiles its own copies of tested sources (e.g. `SCConstants.m`, `SCSettings.m` are in its Compile Sources). **New code that tests reference must be added to BOTH the `SelfControl` and `SelfControlTests` target source phases.**
- `TemplateIcon2x.png` (root, 96×96 gray+alpha — a monochrome template logo) is NOT currently in any target's resources. It is ideal for the menu bar and will be added to the `SelfControl` target resources.
- There is no shared `SelfControl` xcscheme. Generate user schemes with `xcodeproj` before running tests.
- The `xcodeproj` gem is installed (`--user-install`, v1.27.0). `xcodebuild` is at `/usr/bin/xcodebuild`. The CoreSimulator "out of date" warnings from `xcodebuild` are harmless for macOS builds.

## File Structure

- **Create** `SCMenubarTimer.h` — public interface: `initWithTarget:action:`, `show`, `hide`, and pure class method `+displayStringForSecondsRemaining:`.
- **Create** `SCMenubarTimer.m` — owns the `NSStatusItem` + `NSTimer`; reads `BlockEndDate` live each tick; formats text; loads the template icon.
- **Create** `SelfControlTests/SCMenubarTimerTests.m` — unit tests for `+displayStringForSecondsRemaining:`.
- **Modify** `SelfControl.xcodeproj/project.pbxproj` — via `xcodeproj` ruby script: add the two source files to both targets, the test file to the test target, and `TemplateIcon2x.png` to app resources.
- **Modify** `SCConstants.m` — add `@"ShowMenubarTimer": @YES`.
- **Modify** `AppController.h` — add `SCMenubarTimer* menubarTimer_;` ivar + `@class` forward decl.
- **Modify** `AppController.m` — create the timer, add `updateMenubarTimerVisibility`, click handler, defaults observer; call from `refreshUserInterface`.
- **Modify** `Base.lproj/PreferencesGeneralViewController.xib` — add the "Show countdown in menu bar" checkbox bound to `values.ShowMenubarTimer`.

---

## Task 1: Pure time-formatting logic (TDD)

**Files:**
- Create: `SCMenubarTimer.h`
- Create: `SCMenubarTimer.m`
- Test: `SelfControlTests/SCMenubarTimerTests.m`
- Modify: `SelfControl.xcodeproj/project.pbxproj` (via ruby)

- [ ] **Step 1: Write the failing test**

Create `SelfControlTests/SCMenubarTimerTests.m`:

```objc
//
//  SCMenubarTimerTests.m
//  SelfControlTests
//

#import <XCTest/XCTest.h>
#import "SCMenubarTimer.h"

@interface SCMenubarTimerTests : XCTestCase
@end

@implementation SCMenubarTimerTests

- (void)testZeroAndNegativeShowsEmpty {
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: 0], @"");
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: -10], @"");
}

- (void)testRoundsUpToWholeMinute {
    // 45 seconds left -> "1m"
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: 45], @"1m");
    // 1 second left -> "1m"
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: 1], @"1m");
    // exactly 60 seconds -> "1m"
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: 60], @"1m");
    // 61 seconds rounds up -> "2m"
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: 61], @"2m");
}

- (void)testSubHourMinutesOnly {
    // 23 min 30 sec -> rounds up to 24m
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (23 * 60 + 30)], @"24m");
    // exactly 59 min -> "59m"
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (59 * 60)], @"59m");
}

- (void)testHoursAndMinutes {
    // 1h 23m exactly
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (83 * 60)], @"1h 23m");
    // 1h 22m 30s -> rounds up to 1h 23m
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (82 * 60 + 30)], @"1h 23m");
}

- (void)testWholeHoursOmitMinutes {
    // exactly 2h -> "2h" (no "0m")
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (120 * 60)], @"2h");
    // 1h 59m 30s rounds up to 2h exactly -> "2h"
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (119 * 60 + 30)], @"2h");
}

@end
```

- [ ] **Step 2: Create the header**

Create `SCMenubarTimer.h`:

```objc
//
//  SCMenubarTimer.h
//  SelfControl
//

#import <Cocoa/Cocoa.h>

// Owns a single menu bar status item that shows the SelfControl logo plus the
// time remaining in the current block. Self-contained: create once, then call
// -show when a block is active and -hide otherwise. Both are idempotent.
@interface SCMenubarTimer : NSObject

// target/action are wired to the status item's button when it is shown.
- (instancetype)initWithTarget:(id)target action:(SEL)action;

// Creates the status item (if not already present) and starts a 1s update timer.
- (void)show;

// Stops the timer and removes the status item (if present).
- (void)hide;

// Formats the remaining seconds for menu bar display. Minutes always round UP.
//   seconds <= 0  -> @""
//   >= 1 hour     -> @"1h 23m", or @"2h" when the minute part is 0
//   < 1 hour      -> @"23m", down to @"1m"
+ (NSString*)displayStringForSecondsRemaining:(NSTimeInterval)seconds;

@end
```

- [ ] **Step 3: Create a minimal (intentionally wrong) implementation**

Create `SCMenubarTimer.m` with just enough to compile and fail the test:

```objc
//
//  SCMenubarTimer.m
//  SelfControl
//

#import "SCMenubarTimer.h"

@implementation SCMenubarTimer

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    return [super init];
}

- (void)show {}
- (void)hide {}

+ (NSString*)displayStringForSecondsRemaining:(NSTimeInterval)seconds {
    return nil; // not implemented yet
}

@end
```

- [ ] **Step 4: Add files to the Xcode project**

Run this ruby script from the repo root (adds sources to BOTH app and test targets, test file to test target only):

```bash
ruby -e '
require "xcodeproj"
proj = Xcodeproj::Project.open("SelfControl.xcodeproj")
app  = proj.targets.find { |t| t.name == "SelfControl" }
test = proj.targets.find { |t| t.name == "SelfControlTests" }
main = proj.main_group

def ref(group, path)
  group.files.find { |f| f.path == path } || group.new_file(path)
end

hdr  = ref(main, "SCMenubarTimer.h")
impl = ref(main, "SCMenubarTimer.m")
tst  = ref(main, "SelfControlTests/SCMenubarTimerTests.m")

app.add_file_references([impl])  unless app.source_build_phase.files_references.include?(impl)
test.add_file_references([impl]) unless test.source_build_phase.files_references.include?(impl)
test.add_file_references([tst])  unless test.source_build_phase.files_references.include?(tst)

proj.recreate_user_schemes
proj.save
puts "project updated"
'
```

Expected output: `project updated`

- [ ] **Step 5: Run the test to verify it fails**

```bash
xcodebuild test -project SelfControl.xcodeproj -scheme SelfControlTests \
  -destination 'platform=macOS' \
  -only-testing:SelfControlTests/SCMenubarTimerTests 2>&1 | tail -30
```

Expected: build succeeds, tests FAIL (e.g. `testRoundsUpToWholeMinute` — got `(null)`, expected `1m`).

- [ ] **Step 6: Implement the real formatter**

Replace the `+displayStringForSecondsRemaining:` method body in `SCMenubarTimer.m`:

```objc
+ (NSString*)displayStringForSecondsRemaining:(NSTimeInterval)seconds {
    if (seconds <= 0) return @"";

    NSInteger totalMinutes = (NSInteger)ceil(seconds / 60.0);
    NSInteger hours = totalMinutes / 60;
    NSInteger minutes = totalMinutes % 60;

    if (hours > 0) {
        if (minutes > 0) {
            return [NSString stringWithFormat: @"%ldh %ldm", (long)hours, (long)minutes];
        }
        return [NSString stringWithFormat: @"%ldh", (long)hours];
    }
    return [NSString stringWithFormat: @"%ldm", (long)minutes];
}
```

- [ ] **Step 7: Run the test to verify it passes**

```bash
xcodebuild test -project SelfControl.xcodeproj -scheme SelfControlTests \
  -destination 'platform=macOS' \
  -only-testing:SelfControlTests/SCMenubarTimerTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, 5 tests passing.

- [ ] **Step 8: Commit**

```bash
git add SCMenubarTimer.h SCMenubarTimer.m SelfControlTests/SCMenubarTimerTests.m SelfControl.xcodeproj/project.pbxproj
git commit -m "Add SCMenubarTimer with tested countdown formatter"
```

---

## Task 2: Status item UI (show/hide/update + icon)

**Files:**
- Modify: `SCMenubarTimer.m`
- Modify: `SelfControl.xcodeproj/project.pbxproj` (via ruby — add `TemplateIcon2x.png` to app resources)

- [ ] **Step 1: Add the template icon to app resources**

```bash
ruby -e '
require "xcodeproj"
proj = Xcodeproj::Project.open("SelfControl.xcodeproj")
app  = proj.targets.find { |t| t.name == "SelfControl" }
main = proj.main_group
img = main.files.find { |f| f.path == "TemplateIcon2x.png" } || main.new_file("TemplateIcon2x.png")
app.add_resources([img]) unless app.resources_build_phase.files_references.include?(img)
proj.save
puts "icon added"
'
```

Expected output: `icon added`

- [ ] **Step 2: Implement the status item lifecycle**

Replace the full contents of `SCMenubarTimer.m` with:

```objc
//
//  SCMenubarTimer.m
//  SelfControl
//

#import "SCMenubarTimer.h"
#import "SCSettings.h"
#import "SCMigrationUtilities.h"

@interface SCMenubarTimer ()
@property (weak) id clickTarget;
@property (assign) SEL clickAction;
@property (strong) NSStatusItem* statusItem;
@property (strong) NSTimer* updateTimer;
@end

@implementation SCMenubarTimer

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    if (self = [super init]) {
        _clickTarget = target;
        _clickAction = action;
    }
    return self;
}

- (void)show {
    if (self.statusItem != nil) return; // already showing

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSVariableStatusItemLength];
    self.statusItem.button.image = [self menubarIcon];
    self.statusItem.button.imagePosition = NSImageLeft;
    self.statusItem.button.target = self.clickTarget;
    self.statusItem.button.action = self.clickAction;

    [self updateDisplay];

    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0
                                                        target: self
                                                      selector: @selector(updateDisplay)
                                                      userInfo: nil
                                                       repeats: YES];
}

- (void)hide {
    [self.updateTimer invalidate];
    self.updateTimer = nil;
    if (self.statusItem != nil) {
        [[NSStatusBar systemStatusBar] removeStatusItem: self.statusItem];
        self.statusItem = nil;
    }
}

- (void)updateDisplay {
    if (self.statusItem == nil) return;

    NSDate* endDate = [[SCSettings sharedSettings] valueForKey: @"BlockEndDate"];
    if (endDate == nil || [endDate isEqualToDate: [NSDate distantPast]]) {
        endDate = [SCMigrationUtilities legacyBlockEndDate];
    }

    NSTimeInterval remaining = (endDate != nil) ? [endDate timeIntervalSinceNow] : 0;
    self.statusItem.button.title = [SCMenubarTimer displayStringForSecondsRemaining: remaining];
}

- (NSImage*)menubarIcon {
    NSImage* icon = [NSImage imageNamed: @"TemplateIcon2x"];
    if (icon == nil) icon = [NSImage imageNamed: @"SelfControlIcon"];
    if (icon == nil) icon = [NSApp applicationIconImage];

    NSImage* sized = [icon copy];
    [sized setSize: NSMakeSize(18.0, 18.0)];
    [sized setTemplate: YES];
    return sized;
}

+ (NSString*)displayStringForSecondsRemaining:(NSTimeInterval)seconds {
    if (seconds <= 0) return @"";

    NSInteger totalMinutes = (NSInteger)ceil(seconds / 60.0);
    NSInteger hours = totalMinutes / 60;
    NSInteger minutes = totalMinutes % 60;

    if (hours > 0) {
        if (minutes > 0) {
            return [NSString stringWithFormat: @"%ldh %ldm", (long)hours, (long)minutes];
        }
        return [NSString stringWithFormat: @"%ldh", (long)hours];
    }
    return [NSString stringWithFormat: @"%ldm", (long)minutes];
}

@end
```

- [ ] **Step 3: Re-run the formatter tests (no regression)**

```bash
xcodebuild test -project SelfControl.xcodeproj -scheme SelfControlTests \
  -destination 'platform=macOS' \
  -only-testing:SelfControlTests/SCMenubarTimerTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` (the added UI methods do not break the pure tests; `SCSettings`/`SCMigrationUtilities` are already in the test target).

- [ ] **Step 4: Commit**

```bash
git add SCMenubarTimer.m SelfControl.xcodeproj/project.pbxproj TemplateIcon2x.png
git commit -m "Implement menu bar status item UI with template logo"
```

---

## Task 3: Add the `ShowMenubarTimer` default

**Files:**
- Modify: `SCConstants.m:49`

- [ ] **Step 1: Add the default key**

In `SCConstants.m`, in the `defaultDefaultsDict` literal, add the new key right after the `@"BadgeApplicationIcon": @YES,` line:

```objc
            @"BadgeApplicationIcon": @YES,
            @"ShowMenubarTimer": @YES,
```

- [ ] **Step 2: Build the app target to verify it compiles**

```bash
xcodebuild -project SelfControl.xcodeproj -target SelfControl -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SCConstants.m
git commit -m "Add ShowMenubarTimer user default (on by default)"
```

---

## Task 4: Wire `SCMenubarTimer` into `AppController`

**Files:**
- Modify: `AppController.h`
- Modify: `AppController.m`

- [ ] **Step 1: Declare the ivar in the header**

In `AppController.h`, add a forward declaration above the `@interface` line (after the existing `@class TimerWindowController;` at line 24):

```objc
@class TimerWindowController;
@class SCMenubarTimer;
```

And add the ivar inside the `AppController` ivar block (after `BOOL addingBlock;`):

```objc
	BOOL blockIsOn;
	BOOL addingBlock;
	SCMenubarTimer* menubarTimer_;
```

- [ ] **Step 2: Import and create the timer + observer in applicationDidFinishLaunching**

In `AppController.m`, add the import near the top with the other project imports:

```objc
#import "SCMenubarTimer.h"
```

In `applicationDidFinishLaunching:`, immediately before the `[self refreshUserInterface];` call (currently `AppController.m:420`), insert:

```objc
	// Create the menu bar countdown timer and keep it in sync with the prefs toggle
	menubarTimer_ = [[SCMenubarTimer alloc] initWithTarget: self
	                                                action: @selector(menubarTimerClicked:)];
	[[NSNotificationCenter defaultCenter] addObserver: self
	                                         selector: @selector(updateMenubarTimerVisibility)
	                                             name: NSUserDefaultsDidChangeNotification
	                                           object: nil];

	[self refreshUserInterface];
```

- [ ] **Step 3: Add the visibility method and click handler**

In `AppController.m`, add these two methods (place them right after the `closeTimerWindow` method, which ends at `AppController.m:316`):

```objc
- (void)updateMenubarTimerVisibility {
    // UI updates are for the main thread only
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateMenubarTimerVisibility];
        });
        return;
    }

    if (blockIsOn && [defaults_ boolForKey: @"ShowMenubarTimer"]) {
        [menubarTimer_ show];
    } else {
        [menubarTimer_ hide];
    }
}

- (void)menubarTimerClicked:(id)sender {
    [self showTimerWindow];
    [NSApp activateIgnoringOtherApps: YES];
}
```

- [ ] **Step 4: Call updateMenubarTimerVisibility from refreshUserInterface**

In `refreshUserInterface`, immediately before the final `[refreshUILock_ unlock];` (currently `AppController.m:271`), insert:

```objc
    [self updateMenubarTimerVisibility];

	[refreshUILock_ unlock];
```

- [ ] **Step 5: Build the app target**

```bash
xcodebuild -project SelfControl.xcodeproj -target SelfControl -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add AppController.h AppController.m
git commit -m "Show menu bar timer while a block is active, toggled by preference"
```

---

## Task 5: Preferences checkbox

**Files:**
- Modify: `Base.lproj/PreferencesGeneralViewController.xib`

- [ ] **Step 1: Grow the pane and add the checkbox**

In `Base.lproj/PreferencesGeneralViewController.xib`:

1. Change the `customView` height so the new top row fits. Replace:

```xml
        <customView id="Hz6-mo-xeY">
            <rect key="frame" x="0.0" y="0.0" width="480" height="198"/>
```

with:

```xml
        <customView id="Hz6-mo-xeY">
            <rect key="frame" x="0.0" y="0.0" width="480" height="224"/>
```

2. Add a new checkbox button as the first child inside `<subviews>` (immediately after the `<subviews>` opening tag, before the `id="RmI-NP-U9P"` button). It mirrors the "Show countdown in Dock" button but binds to `values.ShowMenubarTimer` and sits at the new top row (y=188). All object ids below are new and unique:

```xml
                <button fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="mbT-01-aaa">
                    <rect key="frame" x="18" y="188" width="444" height="18"/>
                    <autoresizingMask key="autoresizingMask" flexibleMaxX="YES" flexibleMinY="YES"/>
                    <buttonCell key="cell" type="check" title="Show countdown in menu bar" bezelStyle="regularSquare" imagePosition="left" alignment="left" state="on" inset="2" id="mbT-02-bbb">
                        <behavior key="behavior" changeContents="YES" doesNotDimImage="YES" lightByContents="YES"/>
                        <font key="font" metaFont="system"/>
                    </buttonCell>
                    <connections>
                        <binding destination="4wD-T6-SpY" name="value" keyPath="values.ShowMenubarTimer" id="mbT-03-ccc"/>
                    </connections>
                </button>
```

- [ ] **Step 2: Build the app target to verify the xib still compiles**

```bash
xcodebuild -project SelfControl.xcodeproj -target SelfControl -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **` (a malformed xib fails the `CompileXIB`/`ibtool` step, so a clean build confirms the XML is valid).

- [ ] **Step 3: Commit**

```bash
git add Base.lproj/PreferencesGeneralViewController.xib
git commit -m "Add 'Show countdown in menu bar' preference checkbox"
```

---

## Task 6: Full build + manual verification

**Files:** none (verification only)

- [ ] **Step 1: Clean build of the whole app + run all tests**

```bash
xcodebuild -project SelfControl.xcodeproj -target SelfControl -configuration Debug build 2>&1 | tail -5
xcodebuild test -project SelfControl.xcodeproj -scheme SelfControlTests -destination 'platform=macOS' 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **`.

- [ ] **Step 2: Launch the built app and run the manual checklist**

Find the built app under DerivedData (path printed during build, or `~/Library/Developer/Xcode/DerivedData/SelfControl-*/Build/Products/Debug/SelfControl.app`) and run it:

```bash
open ~/Library/Developer/Xcode/DerivedData/SelfControl-*/Build/Products/Debug/SelfControl.app
```

Verify, against the spec's testing section:
1. Start a short block → logo + countdown (e.g. `5m`) appears in the menu bar.
2. Countdown decreases by the minute; with <1 min left it shows `1m` (never `0`).
3. Click the menu bar item → floating timer window opens and the app comes to front.
4. Extend the block → menu bar countdown increases to match.
5. End/expire the block → menu bar item disappears.
6. Preferences → General → uncheck "Show countdown in menu bar" during a block → item disappears immediately; re-check → reappears.
7. With the checkbox off, start a block → item does not appear.

> Note: the icon is rendered as a template (monochrome silhouette of `TemplateIcon2x.png`). If it reads poorly in the menu bar, swap the image source in `-[SCMenubarTimer menubarIcon]` — this does not affect any other task.

- [ ] **Step 3: No commit needed** (verification only). If manual testing surfaced a fix, commit it with a descriptive message.

---

## Self-Review notes

- **Spec coverage:** visibility-only-during-block (Task 4 `updateMenubarTimerVisibility`), godz+min round-up format (Task 1, tested), click→timer window (Task 4 handler), template logo (Task 2), prefs toggle + live update (Tasks 3/4/5), `BlockEndDate` live read incl. legacy fallback (Task 2 `updateDisplay`). All requirements mapped.
- **Type consistency:** `+displayStringForSecondsRemaining:`, `-show`, `-hide`, `-initWithTarget:action:`, `-updateMenubarTimerVisibility`, `-menubarTimerClicked:`, key `@"ShowMenubarTimer"` are spelled identically across all tasks.
- **No placeholders:** every code/edit step shows the exact content.
