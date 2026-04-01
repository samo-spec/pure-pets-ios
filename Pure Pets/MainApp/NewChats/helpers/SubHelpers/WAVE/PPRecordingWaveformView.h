//
//  PPRecordingWaveformView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/01/2026.
//


@interface PPRecordingWaveformView : UIView

- (void)addSample:(float)level;   // mic level 0..1
- (void)reset;

@property (nonatomic, strong) UIColor *barColor;
@property (nonatomic, strong) UIColor *idleColor;

@end