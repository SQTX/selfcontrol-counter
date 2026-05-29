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
