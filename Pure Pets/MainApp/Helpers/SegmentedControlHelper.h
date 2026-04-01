//
//  SegmentedControlHelper.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/05/2025.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LUNSegmentedControl.h"

@class SegmentedControlHelper;

@protocol SegmentedControlHelperDelegate <NSObject>
- (void)segmentedControlHelper:(SegmentedControlHelper *)helper didChangeSegmentToIndex:(NSInteger)index;

@end

@interface SegmentedControlHelper : NSObject <LUNSegmentedControlDataSource, LUNSegmentedControlDelegate>

@property (nonatomic, weak) id<SegmentedControlHelperDelegate> delegate;
@property (nonatomic, strong) NSArray<NSString *> *segmentTitles;
@property (nonatomic, strong) LUNSegmentedControl *segmentedControl;

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles inView:(UIView *)parentView centerX:(CGFloat)centerX;
- (void)layoutSegmentedControlInView:(UIView *)view inController:(UIViewController *)controller;
-(void)setSegmentY:(float)y;
@end
