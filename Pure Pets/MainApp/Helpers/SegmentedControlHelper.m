//
//  SegmentedControlHelper.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/05/2025.
//


#import "SegmentedControlHelper.h"
#import "AppManager.h"
#import "Language.h"

@implementation SegmentedControlHelper

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles inView:(UIView *)parentView centerX:(CGFloat)centerX {
    self = [super init];
    if (self) {
        self.segmentTitles = titles;
        
        _segmentedControl = [[LUNSegmentedControl alloc] initWithFrame:CGRectMake(5, 5, parentView.bounds.size.width - 20, 36)];
        _segmentedControl.dataSource = self;
        _segmentedControl.delegate = self;
        _segmentedControl.center = CGPointMake(centerX, _segmentedControl.center.y);
        [parentView addSubview:_segmentedControl];
        [_segmentedControl reloadData];
        
        parentView.backgroundColor = UIColor.clearColor;
    }
    return self;
}

-(void)setSegmentY:(float)y
{
    _segmentedControl.hx_y  = y;
}

- (void)layoutSegmentedControlInView:(UIView *)view inController:(UIViewController *)controller{
    CGFloat width = view.frame.size.width - 20;
    self.segmentedControl.frame = CGRectMake((view.frame.size.width - width) / 2, self.segmentedControl.frame.origin.y, width, 44);
    //self.segmentedControl.textColor = [UIColor blackColor];
    self.segmentedControl.textFont =  [GM boldFontWithSize:14];
    self.segmentedControl.selectedStateTextColor = [UIColor whiteColor];

    self.segmentedControl.textColor = [GM SecondaryTextColor];
    self.segmentedControl.cornerRadius = 12;
    self.segmentedControl.shadowsEnabled = NO;
    self.segmentedControl.shadowHideDuration = 0;
    self.segmentedControl.shadowShowDuration = 0;
    //self.segmentedControl.hx_w = controller.view.hx_w - 140;
    //self.segmentedControl.hx_x = controller.view.centerX - (width / 2);
    //self.segmentedControl.textColor = [UIColor blackColor];
    //self.segmentedControl.selectedStateTextColor =  [UIColor whiteColor];
}

#pragma mark - LUNSegmentedControlDataSource

- (NSInteger)numberOfStatesInSegmentedControl:(LUNSegmentedControl *)segmentedControl {
    return self.segmentTitles.count;
}

- (NSAttributedString *)segmentedControl:(LUNSegmentedControl *)segmentedControl attributedTitleForStateAtIndex:(NSInteger)index {
    NSString *title = self.segmentTitles[index];
    return [[NSAttributedString alloc] initWithString:title attributes:@{
        NSFontAttributeName: [GM MidFontWithSize:14],
        NSForegroundColorAttributeName: GM.SecondaryTextColor // ← Set your desired color here
    }];
}

- (NSAttributedString *)segmentedControl:(LUNSegmentedControl *)segmentedControl attributedTitleForSelectedStateAtIndex:(NSInteger)index {
    NSString *title = self.segmentTitles[index];
    return [[NSAttributedString alloc] initWithString:title attributes:@{
        NSFontAttributeName: [GM boldFontWithSize:14]
    }];
}

- (NSArray<UIColor *> *)segmentedControl:(LUNSegmentedControl *)segmentedControl gradientColorsForStateAtIndex:(NSInteger)index {
    return @[[GM appPrimaryColor], [GM AppPrimaryColorDarker]];
}

#pragma mark - LUNSegmentedControlDelegate

- (void)segmentedControl:(LUNSegmentedControl *)segmentedControl didChangeStateFromStateAtIndex:(NSInteger)fromIndex toStateAtIndex:(NSInteger)toIndex {
    
    // with this:
    if ([self.delegate respondsToSelector:@selector(segmentedControlHelper:didChangeSegmentToIndex:)]) {
        [self.delegate segmentedControlHelper:self didChangeSegmentToIndex:toIndex];
    }
}

- (void)segmentedControl:(LUNSegmentedControl *)segmentedControl didScrollWithXOffset:(CGFloat)offset {
    // Optional: Handle scroll if needed
}

@end
