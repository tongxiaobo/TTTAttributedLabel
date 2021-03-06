//
//  TTTAttributedLabelTests.m
//  TTTAttributedLabelTests
//
//  Created by Jonathan Hersh on 12/5/14.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <TTTAttributedLabel.h>
#import <FBSnapshotTestCase.h>
#import <Expecta.h>
#import <OCMock.h>
#import <KIF.h>

static NSString * const kTestLabelText = @"Pallando, Merlyn, and Melisandre were walking one day...";
static CGSize const kTestLabelSize = (CGSize) { 90, CGFLOAT_MAX };

static inline NSAttributedString * TTTAttributedTestString() {
    return [[NSAttributedString alloc] initWithString:kTestLabelText
                                           attributes:@{
                                                    NSForegroundColorAttributeName : [UIColor redColor],
                                                    NSFontAttributeName : [UIFont boldSystemFontOfSize:16.f],
                                           }];
}

static inline void TTTSizeAttributedLabel(TTTAttributedLabel *label) {
    CGSize size = [TTTAttributedLabel sizeThatFitsAttributedString:label.attributedText
                                                   withConstraints:kTestLabelSize
                                            limitedToNumberOfLines:0];
    [label setFrame:CGRectMake(0, 0, size.width, size.height)];
};

static inline void TTTSimulateTapOnLabelAtPoint(TTTAttributedLabel *label, CGPoint point) {
    UIWindow *window = [[UIApplication sharedApplication].windows lastObject];
    [window addSubview:label];
    [label tapAtPoint:point];
};

static inline void TTTSimulateLongPressOnLabelAtPointWithDuration(TTTAttributedLabel *label, CGPoint point, NSTimeInterval duration) {
    UIWindow *window = [[UIApplication sharedApplication].windows lastObject];
    [window addSubview:label];
    [label longPressAtPoint:point duration:duration];
};

@interface TTTAttributedLabelTests : FBSnapshotTestCase

@end

@implementation TTTAttributedLabelTests
{
    TTTAttributedLabel *label; // system under test
    NSURL *testURL;
    OCMockObject *TTTDelegateMock;
}

- (void)setUp {
    [super setUp];
    
    label = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
    label.numberOfLines = 0;
    
    testURL = [NSURL URLWithString:@"http://helios.io"];
    
    TTTDelegateMock = OCMProtocolMock(@protocol(TTTAttributedLabelDelegate));
    label.delegate = (id <TTTAttributedLabelDelegate>)TTTDelegateMock;
    
    // Compatibility fix for intermittently non-rendering images
    self.renderAsLayer = YES;
    
    // Enable recording mode to record and save reference images for tests
//    self.recordMode = YES;
}

- (void)tearDown {
    [super tearDown];
}

#pragma mark - Logic tests

- (void)testInitializable {
    XCTAssertNotNil(label, @"Label should be initializable");
}

- (void)testAttributedTextAccess {
    label.text = TTTAttributedTestString();
    XCTAssertTrue([label.attributedText isEqualToAttributedString:TTTAttributedTestString()], @"Attributed strings should match");
}

- (void)testEmptyAttributedStringSizing {
    XCTAssertTrue(CGSizeEqualToSize(CGSizeZero, [TTTAttributedLabel sizeThatFitsAttributedString:nil
                                                                                 withConstraints:CGSizeMake(10, CGFLOAT_MAX)
                                                                          limitedToNumberOfLines:0]),
                  @"nil string should size to empty");
    XCTAssertTrue(CGSizeEqualToSize(CGSizeZero, [TTTAttributedLabel sizeThatFitsAttributedString:[[NSAttributedString alloc] initWithString:@""]
                                                                                 withConstraints:CGSizeMake(10, CGFLOAT_MAX)
                                                                          limitedToNumberOfLines:0]),
                  @"empty string should size to zero");
}

- (void)testSingleLineLabelSizing {
    NSAttributedString *testString = TTTAttributedTestString();
    label.text = testString;
    
    CGSize lineSize = [TTTAttributedLabel sizeThatFitsAttributedString:testString
                                                       withConstraints:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                                limitedToNumberOfLines:1];
    
    UIFont *font = [testString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    XCTAssertLessThan(lineSize.height, font.pointSize * 2, @"Label should size to less than two lines");
}

- (void)testMultilineLabelSizing {
    NSAttributedString *testString = TTTAttributedTestString();
    
    CGSize size = [TTTAttributedLabel sizeThatFitsAttributedString:testString
                                                   withConstraints:kTestLabelSize
                                            limitedToNumberOfLines:0];
    
    UIFont *font = [testString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    XCTAssertGreaterThan(size.height, font.pointSize, @"Text should size to more than one line");
}

- (void)testContainsLinkAtPoint {
    label.text = TTTAttributedTestString();
    [label addLinkToURL:testURL withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    XCTAssertTrue([label containslinkAtPoint:CGPointMake(5, 5)], @"Label should contain a link at the start of the string");
    XCTAssertFalse([label containslinkAtPoint:CGPointMake(30, 5)], @"Label should not contain a link elsewhere in the string");
}

- (void)testLinkDetection {
    label.enabledTextCheckingTypes = NSTextCheckingTypeLink;
    label.text = [testURL absoluteString];
    
    // Data detection is performed asynchronously in a background thread
    EXP_expect([label.links count] == 1).will.beTruthy();
    EXP_expect([((NSTextCheckingResult *)label.links[0]).URL isEqual:testURL]).will.beTruthy();
}

- (void)testLinkArray {
    label.text = TTTAttributedTestString();
    [label addLinkToURL:testURL withRange:NSMakeRange(0, 1)];
    
    XCTAssertNotNil(label.links, @"Label should have a links array");
    
    NSTextCheckingResult *result = label.links[0];
    XCTAssertEqual(result.resultType, NSTextCheckingTypeLink, @"Should be a link checking result");
    XCTAssertTrue(result.range.location == 0 && result.range.length == 1, @"Link range should match");
    XCTAssertEqualObjects(result.URL, testURL, @"Should set and retrieve test URL");
}

- (void)testInheritsAttributesFromLabel {
    UIFont *testFont = [UIFont boldSystemFontOfSize:16.f];
    UIColor *testColor = [UIColor greenColor];
    CGFloat testKern = 3.f;
    
    label.font = testFont;
    label.textColor = testColor;
    label.kern = testKern;
    
    __block NSMutableAttributedString *derivedString;
    
    NSMutableAttributedString * (^configureBlock) (NSMutableAttributedString *) = ^NSMutableAttributedString *(NSMutableAttributedString *inheritedString)
    {
        XCTAssertEqualObjects(testFont,
                              [inheritedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL],
                              @"Inherited font should match");
        XCTAssertEqualObjects(testColor,
                              [inheritedString attribute:(NSString *)kCTForegroundColorAttributeName atIndex:0 effectiveRange:NULL],
                              @"Inherited color should match");
        XCTAssertEqualWithAccuracy(testKern,
                                   [[inheritedString attribute:(NSString *)kCTKernAttributeName atIndex:0 effectiveRange:NULL] floatValue],
                                   FLT_EPSILON,
                                   @"Inherited kerning should match");
        
        derivedString = inheritedString;
        
        return inheritedString;
    };
    
    [label setText:@"1.21 GigaWatts!" afterInheritingLabelAttributesAndConfiguringWithBlock:configureBlock];
    
    XCTAssertTrue([label.attributedText isEqualToAttributedString:derivedString],
                  @"Label should ultimately set the derived string as its text");
}

#pragma mark - FBSnapshotTestCase tests

- (void)testVerticalAlignment {
    label.verticalAlignment = TTTAttributedLabelVerticalAlignmentBottom;
    label.text = TTTAttributedTestString();
    [label setFrame:CGRectMake(0, 0, 90, 300)];
    FBSnapshotVerifyView(label, nil);
}

- (void)testMultilineLabelView {
    label.text = TTTAttributedTestString();
    TTTSizeAttributedLabel(label);
    FBSnapshotVerifyView(label, nil);
}

- (void)testLinkifiedLabelView {
    label.text = TTTAttributedTestString();
    [label addLinkToURL:testURL withRange:NSMakeRange(1, 3)];
    TTTSizeAttributedLabel(label);
    FBSnapshotVerifyView(label, nil);
}

- (void)testLinkAttributeLabelView {
    label.linkAttributes = @{ NSForegroundColorAttributeName : (id)[UIColor greenColor].CGColor };
    label.text = TTTAttributedTestString();
    [label addLinkToURL:testURL withRange:NSMakeRange(10, 6)];
    TTTSizeAttributedLabel(label);
    FBSnapshotVerifyView(label, nil);
}

- (void)testLinkBackgroundLabelView {
    label.linkAttributes = @{ kTTTBackgroundFillColorAttributeName : (id)[UIColor greenColor].CGColor };
    label.text = TTTAttributedTestString();
    [label addLinkToURL:testURL withRange:NSMakeRange(40, 5)];
    FBSnapshotVerifyView(label, nil);
}

- (void)testMultipleLineLinkBackgroundLabelView {
    label.linkAttributes = @{ kTTTBackgroundFillColorAttributeName : (id)[UIColor greenColor].CGColor };
    label.text = TTTAttributedTestString();
    [label addLinkToURL:testURL withRange:NSMakeRange(20, 25)];
    FBSnapshotVerifyView(label, nil);
}

- (void)testLabelTextInsets {
    label.textInsets = UIEdgeInsetsMake(10, 40, 10, 40);
    label.text = TTTAttributedTestString();
    FBSnapshotVerifyView(label, nil);
}

- (void)testLabelShadowRadius {
    label.shadowRadius = 3.f;
    label.shadowColor = [UIColor greenColor];
    label.shadowOffset = CGSizeMake(1, 3);
    label.text = TTTAttributedTestString();
    FBSnapshotVerifyView(label, nil);
}

- (void)testComplexAttributedString {
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:kTestLabelText];
    [string addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:16.f] range:NSMakeRange(0, [kTestLabelText length])];
    [string addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"Menlo" size:18.f] range:NSMakeRange(0, 10)];
    [string addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"Courier" size:20.f] range:NSMakeRange(10, 10)];
    [string addAttribute:NSForegroundColorAttributeName value:[UIColor greenColor] range:NSMakeRange(5, 10)];
    [string addAttribute:kTTTStrikeOutAttributeName value:@1 range:NSMakeRange(15, 5)];
    [string addAttribute:kTTTBackgroundFillColorAttributeName value:(id)[UIColor blueColor].CGColor range:NSMakeRange(23, 8)];
    [string addAttribute:kTTTBackgroundCornerRadiusAttributeName value:@4 range:NSMakeRange(23, 8)];
    [string addAttribute:kTTTBackgroundStrokeColorAttributeName value:(id)[UIColor orangeColor].CGColor range:NSMakeRange(34, 4)];
    [string addAttribute:kTTTBackgroundLineWidthAttributeName value:@2 range:NSMakeRange(34, 4)];
    
    label.text = string;
    TTTSizeAttributedLabel(label);
    FBSnapshotVerifyView(label, nil);
}

#pragma mark - TTTAttributedLabelDelegate tests

- (void)testDefaultLongPressValues {
    XCTAssertGreaterThan(label.longPressGestureRecognizer.minimumPressDuration, 0, @"Should have a default minimum long press duration");
    XCTAssertGreaterThan(label.longPressGestureRecognizer.allowableMovement, 0, @"Should have a default allowable long press movement distance");
}

- (void)testMinimumLongPressDuration {
    label.text = TTTAttributedTestString();
    [label addLinkToURL:testURL withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    label.longPressGestureRecognizer.minimumPressDuration = 0.4f;
    
    [[TTTDelegateMock expect] attributedLabel:label didSelectLinkWithURL:testURL];
    [[TTTDelegateMock reject] attributedLabel:label didLongPressLinkWithURL:testURL atPoint:CGPointMake(5, 5)];
    
    TTTSimulateLongPressOnLabelAtPointWithDuration(label, CGPointMake(5, 5), 0.2f);
    
    [TTTDelegateMock verify];
}

- (void)testLinkPressCallsDelegate {
    label.text = TTTAttributedTestString();
    [label addLinkToURL:testURL withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock expect] attributedLabel:label didSelectLinkWithURL:testURL];
    
    TTTSimulateTapOnLabelAtPoint(label, CGPointMake(5, 5));
    
    [TTTDelegateMock verify];
}

- (void)testLongPressOffLinkDoesNotCallDelegate {
    label.text = TTTAttributedTestString();
    [label addLinkToURL:testURL withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock reject] attributedLabel:label didSelectLinkWithURL:testURL];
    [[TTTDelegateMock reject] attributedLabel:label didLongPressLinkWithURL:testURL atPoint:CGPointMake(30, 5)];
    
    TTTSimulateLongPressOnLabelAtPointWithDuration(label, CGPointMake(30, 5), 0.6f);
    
    [TTTDelegateMock verify];
}

- (void)testDragOffLinkDoesNotCallDelegate {
    label.text = TTTAttributedTestString();
    [label addLinkToURL:testURL withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock reject] attributedLabel:label didSelectLinkWithURL:testURL];
    [[TTTDelegateMock reject] attributedLabel:label didLongPressLinkWithURL:testURL atPoint:CGPointMake(30, 5)];
    
    [[[UIApplication sharedApplication].windows lastObject] addSubview:label];
    [label dragFromPoint:CGPointMake(0, 1) toPoint:CGPointMake(30, 5) steps:30];
    
    [TTTDelegateMock verify];
}

- (void)testLongLinkPressCallsDelegate {
    label.text = TTTAttributedTestString();
    [label addLinkToURL:testURL withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock reject] attributedLabel:label didSelectLinkWithURL:testURL];
    [[TTTDelegateMock expect] attributedLabel:label didLongPressLinkWithURL:testURL atPoint:CGPointMake(5, 5)];
    
    TTTSimulateLongPressOnLabelAtPointWithDuration(label, CGPointMake(5, 5), 0.6f);
    
    [TTTDelegateMock verify];
}

- (void)testPhonePressCallsDelegate {
    label.text = TTTAttributedTestString();
    
    NSString *phone = @"415-555-1212";
    [label addLinkToPhoneNumber:phone withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock expect] attributedLabel:label didSelectLinkWithPhoneNumber:phone];
    
    TTTSimulateTapOnLabelAtPoint(label, CGPointMake(5, 5));
    
    [TTTDelegateMock verify];
}

- (void)testLongPhonePressCallsDelegate {
    label.text = TTTAttributedTestString();
    
    NSString *phone = @"415-555-1212";
    [label addLinkToPhoneNumber:phone withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock reject] attributedLabel:label didSelectLinkWithPhoneNumber:phone];
    [[TTTDelegateMock expect] attributedLabel:label didLongPressLinkWithPhoneNumber:phone atPoint:CGPointMake(5, 5)];
    
    TTTSimulateLongPressOnLabelAtPointWithDuration(label, CGPointMake(5, 5), 0.6f);
    
    [TTTDelegateMock verify];
}

- (void)testDatePressCallsDelegate {
    label.text = TTTAttributedTestString();
    
    NSDate *date = [NSDate date];
    [label addLinkToDate:date withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock expect] attributedLabel:label didSelectLinkWithDate:date];
    
    TTTSimulateTapOnLabelAtPoint(label, CGPointMake(5, 5));
    
    [TTTDelegateMock verify];
}

- (void)testLongDatePressCallsDelegate {
    label.text = TTTAttributedTestString();
    
    NSDate *date = [NSDate date];
    [label addLinkToDate:date withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock reject] attributedLabel:label didSelectLinkWithDate:date];
    [[TTTDelegateMock expect] attributedLabel:label didLongPressLinkWithDate:date atPoint:CGPointMake(5, 5)];
    
    TTTSimulateLongPressOnLabelAtPointWithDuration(label, CGPointMake(5, 5), 0.6f);
    
    [TTTDelegateMock verify];
}

- (void)testAddressPressCallsDelegate {
    label.text = TTTAttributedTestString();
    
    NSDictionary *address = @{
          NSTextCheckingCityKey     : @"San Fransokyo",
          NSTextCheckingCountryKey  : @"United States of Eurasia",
          NSTextCheckingStateKey    : @"California",
          NSTextCheckingStreetKey   : @"1 Market St",
    };
    [label addLinkToAddress:address withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock expect] attributedLabel:label didSelectLinkWithAddress:address];
    
    TTTSimulateTapOnLabelAtPoint(label, CGPointMake(5, 5));
    
    [TTTDelegateMock verify];
}

- (void)testLongAddressPressCallsDelegate {
    label.text = TTTAttributedTestString();
    
    NSDictionary *address = @{
          NSTextCheckingCityKey     : @"San Fransokyo",
          NSTextCheckingCountryKey  : @"United States of Eurasia",
          NSTextCheckingStateKey    : @"California",
          NSTextCheckingStreetKey   : @"1 Market St",
    };
    [label addLinkToAddress:address withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock reject] attributedLabel:label didSelectLinkWithAddress:address];
    [[TTTDelegateMock expect] attributedLabel:label didLongPressLinkWithAddress:address atPoint:CGPointMake(5, 5)];
    
    TTTSimulateLongPressOnLabelAtPointWithDuration(label, CGPointMake(5, 5), 0.6f);
    
    [TTTDelegateMock verify];
}

- (void)testTransitPressCallsDelegate {
    label.text = TTTAttributedTestString();
    
    NSDictionary *transitDict = @{
          NSTextCheckingAirlineKey  : @"Galactic Spacelines",
          NSTextCheckingFlightKey   : @9876,
    };
    [label addLinkToTransitInformation:transitDict withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock expect] attributedLabel:label didSelectLinkWithTransitInformation:transitDict];
    
    TTTSimulateTapOnLabelAtPoint(label, CGPointMake(5, 5));
    
    [TTTDelegateMock verify];
}

- (void)testLongTransitPressCallsDelegate {
    label.text = TTTAttributedTestString();
    
    NSDictionary *transitDict = @{
          NSTextCheckingAirlineKey  : @"Galactic Spacelines",
          NSTextCheckingFlightKey   : @9876,
    };
    [label addLinkToTransitInformation:transitDict withRange:NSMakeRange(0, 4)];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock reject] attributedLabel:label didSelectLinkWithTransitInformation:transitDict];
    [[TTTDelegateMock expect] attributedLabel:label didLongPressLinkWithTransitInformation:transitDict atPoint:CGPointMake(5, 5)];
    
    TTTSimulateLongPressOnLabelAtPointWithDuration(label, CGPointMake(5, 5), 0.6f);
    
    [TTTDelegateMock verify];
}

- (void)testTextCheckingPressCallsDelegate {
    label.text = TTTAttributedTestString();
    
    NSTextCheckingResult *textResult = [NSTextCheckingResult spellCheckingResultWithRange:NSMakeRange(0, 4)];
    [label addLinkWithTextCheckingResult:textResult];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock expect] attributedLabel:label didSelectLinkWithTextCheckingResult:textResult];
    
    TTTSimulateTapOnLabelAtPoint(label, CGPointMake(5, 5));
    
    [TTTDelegateMock verify];
}

- (void)testLongTextCheckingPressCallsDelegate {
    label.text = TTTAttributedTestString();
    
    NSTextCheckingResult *textResult = [NSTextCheckingResult spellCheckingResultWithRange:NSMakeRange(0, 4)];
    [label addLinkWithTextCheckingResult:textResult];
    TTTSizeAttributedLabel(label);
    
    [[TTTDelegateMock reject] attributedLabel:label didSelectLinkWithTextCheckingResult:textResult];
    [[TTTDelegateMock expect] attributedLabel:label didLongPressLinkWithTextCheckingResult:textResult atPoint:CGPointMake(5, 5)];
    
    TTTSimulateLongPressOnLabelAtPointWithDuration(label, CGPointMake(5, 5), 0.6f);
    
    [TTTDelegateMock verify];
}

@end
