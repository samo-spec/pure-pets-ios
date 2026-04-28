//
//  PPDataViewInput.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/12/2025.
//

#import "PPDataViewInput.h"
#import "MainKindsModel.h"

@implementation PPDataViewInput

+ (instancetype)inputWithMainKind:(MainKindsModel *)mainKind
{
    return [self inputWithMainKind:mainKind
                      sourceTarget:PPDeepLinkTargetNone
                            source:PPInputSourceHomeMainKindsSection];
}

+ (instancetype)inputWithMainKind:(MainKindsModel *)mainKind
                     sourceTarget:(PPDeepLinkTarget)sourceTarget
                           source:(PPInputSource)source
{
    PPDataViewInput *input = [[self alloc] init];
    if (!input) { return nil; }

    input.mainKind = mainKind;
    input.mainKindsArr = mainKind ? @[mainKind] : @[];
    input.sourceTarget = sourceTarget;
    input.source = source;
    input.title = mainKind.KindName ?: @"";
    input.initialSectionOverride = nil;
    return input;
}

+ (instancetype)inputWithMainKindsArr:(NSArray<MainKindsModel *> *)mainKindsArr
                          sourceTarget:(PPDeepLinkTarget)sourceTarget
                                source:(PPInputSource)source
{
    PPDataViewInput *input = [[self alloc] init];
    if (!input) { return nil; }

    NSArray<MainKindsModel *> *safeKinds =
    [mainKindsArr isKindOfClass:[NSArray class]] ? mainKindsArr : @[];

    input.mainKindsArr = safeKinds;
    input.mainKind = safeKinds.firstObject;
    input.sourceTarget = sourceTarget;
    input.source = source;
    input.title = input.mainKind.KindName ?: @"";
    input.initialSectionOverride = nil;
    return input;
}

@end
