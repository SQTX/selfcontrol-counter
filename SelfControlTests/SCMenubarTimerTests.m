//
//  SCMenubarTimerTests.m
//  SelfControlTests
//

#import <XCTest/XCTest.h>
#import "SCMenubarTimer.h"

@interface SCMenubarTimerTests : XCTestCase
@end

@implementation SCMenubarTimerTests

- (void)testZeroAndNegativeShowsZeroMinutes {
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: 0], @"0m");
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: -10], @"0m");
}

- (void)testRoundsUpToWholeMinute {
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: 45], @"1m");
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: 1], @"1m");
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: 60], @"1m");
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: 61], @"2m");
}

- (void)testSubHourMinutesOnly {
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (23 * 60 + 30)], @"24m");
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (59 * 60)], @"59m");
}

- (void)testHoursAndMinutes {
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (83 * 60)], @"1h 23m");
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (82 * 60 + 30)], @"1h 23m");
}

- (void)testWholeHoursOmitMinutes {
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (120 * 60)], @"2h");
    XCTAssertEqualObjects([SCMenubarTimer displayStringForSecondsRemaining: (119 * 60 + 30)], @"2h");
}

@end
