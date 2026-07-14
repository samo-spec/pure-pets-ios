//
//  PPOrderProgressTimelineView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//
#import "PPOrderProgressTimelineView.h"
#import "PPOrderProgressTimelineRowView.h"

@interface PPOrderProgressTimelineView ()

@property (nonatomic, strong) UIView *trackView;
@property (nonatomic, strong) NSMutableArray<PPOrderProgressTimelineRowView *> *rowViews;
@property (nonatomic, copy) NSArray<NSDictionary *> *stepDescriptors;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL showsFailure;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, strong) UIColor *accentColor;

@end

@implementation PPOrderProgressTimelineView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        _trackView = [[UIView alloc] initWithFrame:CGRectZero];
        _trackView.layer.cornerRadius = 1.0;
        [self addSubview:_trackView];
        _rowViews = [NSMutableArray array];
    }
    return self;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self refreshCurrentStatusMotion];
}

- (void)ensureRowCount:(NSInteger)count
{
    while (self.rowViews.count < count) {
        PPOrderProgressTimelineRowView *row = [[PPOrderProgressTimelineRowView alloc] initWithFrame:CGRectZero];
        [self.rowViews addObject:row];
        [self addSubview:row];
    }
    for (NSInteger index = 0; index < self.rowViews.count; index++) {
        self.rowViews[index].hidden = (index >= count);
    }
}

- (void)configureWithStepDescriptors:(NSArray<NSDictionary *> *)stepDescriptors
                        currentIndex:(NSInteger)currentIndex
                        showsFailure:(BOOL)showsFailure
                            expanded:(BOOL)expanded
                           tintColor:(UIColor *)tintColor
                            animated:(BOOL)animated
{
    self.stepDescriptors = stepDescriptors ?: @[];
    self.currentIndex = MAX(0, MIN(currentIndex, MAX((NSInteger)self.stepDescriptors.count - 1, 0)));
    self.showsFailure = showsFailure;
    self.expanded = expanded;
    self.accentColor = tintColor ?: [GM appPrimaryColor];

    [self ensureRowCount:self.stepDescriptors.count];

    BOOL isRTL = [Language isRTL];
    for (NSInteger index = 0; index < self.stepDescriptors.count; index++) {
        NSDictionary *descriptor = self.stepDescriptors[index];
        PPOrderProgressTimelineRowState state = PPOrderProgressTimelineRowStateUpcoming;
        if (showsFailure && index == self.currentIndex) {
            state = PPOrderProgressTimelineRowStateFailure;
        } else if (index < self.currentIndex) {
            state = PPOrderProgressTimelineRowStateCompleted;
        } else if (index == self.currentIndex) {
            state = PPOrderProgressTimelineRowStateCurrent;
        }

        [self.rowViews[index] configureWithTitle:[descriptor[@"title"] isKindOfClass:NSString.class] ? descriptor[@"title"] : @""
                                        subtitle:[descriptor[@"subtitle"] isKindOfClass:NSString.class] ? descriptor[@"subtitle"] : @""
                                        metaText:[descriptor[@"meta"] isKindOfClass:NSString.class] ? descriptor[@"meta"] : @""
                                      symbolName:[descriptor[@"icon"] isKindOfClass:NSString.class] ? descriptor[@"icon"] : @"circle"
                                           state:state
                                        expanded:expanded
                                       tintColor:self.accentColor
                                           isRTL:isRTL];
    }

    if (animated) {
        [UIView transitionWithView:self
                          duration:0.26
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                        animations:^{
            [self setNeedsLayout];
            [self layoutIfNeeded];
        } completion:nil];
    } else {
        [self setNeedsLayout];
    }

    [self refreshCurrentStatusMotion];
}

- (void)refreshCurrentStatusMotion
{
    for (PPOrderProgressTimelineRowView *row in self.rowViews) {
        [row refreshCurrentStatusMotion];
    }
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
    if (self.stepDescriptors.count == 0) return 0.0;

    CGFloat gap = self.expanded ? 12.0 : 7.0;
    CGFloat totalHeight = 0.0;
    for (NSInteger index = 0; index < self.stepDescriptors.count; index++) {
        PPOrderProgressTimelineRowView *row = (index < self.rowViews.count) ? self.rowViews[index] : nil;
        totalHeight += [row preferredHeightForWidth:width];
        if (index < (NSInteger)self.stepDescriptors.count - 1) {
            totalHeight += gap;
        }
    }
    return totalHeight;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat gap = self.expanded ? 12.0 : 7.0;
    CGFloat y = 0.0;
    CGFloat firstMarkerY = 0.0;
    CGFloat lastMarkerY = 0.0;
    CGFloat trackX = [Language isRTL] ? (width - 18.0) : 18.0;

    for (NSInteger index = 0; index < self.stepDescriptors.count; index++) {
        PPOrderProgressTimelineRowView *row = self.rowViews[index];
        row.hidden = NO;
        CGFloat rowHeight = [row preferredHeightForWidth:width];
        row.frame = CGRectMake(0.0, y, width, rowHeight);
        CGFloat markerY = y + [row markerCenterY];
        if (index == 0) firstMarkerY = markerY;
        lastMarkerY = markerY;
        y += rowHeight;
        if (index < (NSInteger)self.stepDescriptors.count - 1) {
            y += gap;
        }
    }

    self.trackView.hidden = (self.stepDescriptors.count < 2);
    self.trackView.backgroundColor = [self.accentColor colorWithAlphaComponent:self.expanded ? 0.18 : 0.12];
    self.trackView.frame = CGRectMake(trackX - 1.0,
                                      firstMarkerY,
                                      2.0,
                                      MAX(0.0, lastMarkerY - firstMarkerY));
    [self sendSubviewToBack:self.trackView];
}

@end
