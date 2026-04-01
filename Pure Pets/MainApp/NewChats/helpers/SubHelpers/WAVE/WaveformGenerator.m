

#import "WaveformGenerator.h"
@import AVFoundation;

static const float kPPWaveMinDb = -60.0f;
static const float kPPWaveNoiseGate = 0.08f;
static const float kPPWaveCompression = 0.55f;
static const float kPPWaveIdleFloor = 0.03f;

@implementation WaveformGenerator

+ (float)pp_normalizeAndCompress:(float)linear
{
    // linear expected 0..1
    if (linear <= 0) return kPPWaveIdleFloor;

    // Noise gate
    if (linear < kPPWaveNoiseGate) {
        return kPPWaveIdleFloor;
    }

    // Non‑linear compression (WhatsApp‑like)
    float v = powf(linear, kPPWaveCompression);
    return fminf(fmaxf(v, 0.0f), 1.0f);
}
// New: Shape relative level with noise gate and compression (post-normalization)
+ (float)pp_shapeRelativeLevel:(float)relative
{
    // relative expected 0..1
    if (relative <= 0) return kPPWaveIdleFloor;

    // Gentle noise gate
    if (relative < kPPWaveNoiseGate) {
        return kPPWaveIdleFloor;
    }

    // Non-linear compression (WhatsApp-like)
    float v = powf(relative, kPPWaveCompression);
    return fminf(fmaxf(v, 0.0f), 1.0f);
}
//
//  WaveformGenerator.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/01/2026.
//

+ (NSArray<NSNumber *> *)samplesFromAudioURL:(NSURL *)url
                                       count:(NSInteger)count
{
    if (!url || count <= 0) return @[];

    AVAsset *asset = [AVAsset assetWithURL:url];
    AVAssetTrack *track =
        [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!track) return @[];

    NSError *error = nil;

    AVAssetReader *reader =
        [[AVAssetReader alloc] initWithAsset:asset error:&error];
    if (error) return @[];

    NSDictionary *settings = @{
        AVFormatIDKey : @(kAudioFormatLinearPCM),
        AVLinearPCMBitDepthKey : @16,
        AVLinearPCMIsBigEndianKey : @NO,
        AVLinearPCMIsFloatKey : @NO,
        AVLinearPCMIsNonInterleaved : @NO
    };

    AVAssetReaderTrackOutput *output =
        [[AVAssetReaderTrackOutput alloc] initWithTrack:track
                                          outputSettings:settings];

    [reader addOutput:output];
    [reader startReading];

    NSMutableArray<NSNumber *> *raw = [NSMutableArray array];

    while (reader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef buffer = [output copyNextSampleBuffer];
        if (!buffer) break;

        CMBlockBufferRef block = CMSampleBufferGetDataBuffer(buffer);
        size_t length = CMBlockBufferGetDataLength(block);

        SInt16 samples[length / sizeof(SInt16)];
        CMBlockBufferCopyDataBytes(block, 0, length, samples);

        NSInteger sampleCount = length / sizeof(SInt16);
        for (NSInteger i = 0; i < sampleCount; i++) {
            float v = fabsf(samples[i] / 32768.0f);
            [raw addObject:@(v)];
        }

        CFRelease(buffer);
    }

    [reader cancelReading];

    if (raw.count == 0) return @[];

    NSMutableArray<NSNumber *> *result =
        [NSMutableArray arrayWithCapacity:count];

    NSInteger bucketSize = MAX(raw.count / count, 1);

    // First pass: collect RMS values
    NSMutableArray<NSNumber *> *rmsValues =
        [NSMutableArray arrayWithCapacity:count];

    float maxRMS = 0.0f;

    for (NSInteger i = 0; i < count; i++) {
        NSInteger start = i * bucketSize;
        NSInteger end = MIN(start + bucketSize, raw.count);

        if (start >= end) {
            [rmsValues addObject:@(0)];
            continue;
        }

        float sumSquares = 0.0f;
        NSInteger c = 0;

        for (NSInteger j = start; j < end; j++) {
            float v = raw[j].floatValue;
            sumSquares += v * v;
            c++;
        }

        float rms = sqrtf(sumSquares / MAX(c, 1));
        maxRMS = MAX(maxRMS, rms);
        [rmsValues addObject:@(rms)];
    }

    // Second pass: normalize RELATIVELY and shape
    for (NSNumber *n in rmsValues) {
        float rms = n.floatValue;
        float relative = (maxRMS > 0.0f) ? (rms / maxRMS) : 0.0f;
        float shaped = [self pp_shapeRelativeLevel:relative];
        [result addObject:@(shaped)];
    }

    return result;
}

@end
