//
//  PPWaveformView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/01/2026.
//


#import <UIKit/UIKit.h>
typedef NS_ENUM(NSUInteger, PPWaveformVisualState) {
    PPWaveformVisualStateRecording,
    PPWaveformVisualStateLocked,
    PPWaveformVisualStatePreview
};


@interface PPWaveformView : UIView
@property (nonatomic, assign) PPWaveformVisualState visualState;


/// Append a new normalized audio level (0.0 – 1.0)
- (void)addSample:(float)level;

/// Freeze waveform (used when recording finishes)
- (void)freeze;

/// Reset waveform to empty
- (void)reset;

/// Optional: animate playback cursor later
- (void)setPlaybackProgress:(CGFloat)progress; // 0.0 – 1.0
- (void)loadWaveformFromAudioURL:(NSURL *)url;

@property (nonatomic, strong) UIColor *activeColor;
@property (nonatomic, strong) UIColor *inactiveColor;
@property (nonatomic, strong) UIColor *accentColor;

@end

 
