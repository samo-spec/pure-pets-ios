//
//  PPPlaybackWaveformView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/01/2026.
//


#import <UIKit/UIKit.h>

@interface PPPlaybackWaveformView : UIView

- (void)setSamples:(NSArray<NSNumber *> *)samples;   // called ONCE
- (void)setPlaybackProgress:(CGFloat)progress;       // 0..1
- (void)reset;
+ (NSArray<NSNumber *> *)idleSamples;
@property (nonatomic, strong) UIColor *activeColor;
@property (nonatomic, strong) UIColor *inactiveColor;

@end
