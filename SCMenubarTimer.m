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
