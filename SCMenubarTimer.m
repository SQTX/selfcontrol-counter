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
