//
//  PPPlaybackWaveformView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/01/2026.
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A reusable, RTL-aware playback waveform with adaptive sampling and motion-safe progress.
@interface PPPlaybackWaveformView : UIView

- (void)setSamples:(nullable NSArray<NSNumber *> *)samples;
- (void)setPlaybackProgress:(CGFloat)progress; // Clamped to 0...1.
- (void)reset;
+ (NSArray<NSNumber *> *)idleSamples;
@property (nonatomic, strong, nullable) UIColor *activeColor;
@property (nonatomic, strong, nullable) UIColor *inactiveColor;

@end

NS_ASSUME_NONNULL_END
