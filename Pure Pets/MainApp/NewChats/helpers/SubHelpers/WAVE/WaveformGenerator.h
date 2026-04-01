//
//  WaveformGenerator.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/01/2026.
//


#import <Foundation/Foundation.h>

@interface WaveformGenerator : NSObject

/// Generates normalized waveform samples (0..1)
/// count = number of bars (recommended 40–64)
+ (NSArray<NSNumber *> *)samplesFromAudioURL:(NSURL *)url
                                       count:(NSInteger)count;

@end