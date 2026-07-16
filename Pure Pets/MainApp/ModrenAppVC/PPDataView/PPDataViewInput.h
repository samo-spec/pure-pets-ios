//
//  PPDataViewInput.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/12/2025.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "EnumValues.h"
#import "MainKindsModel.h"

   
NS_ASSUME_NONNULL_BEGIN

@interface PPDataViewInput : NSObject

@property (nonatomic, strong, nullable) MainKindsModel *mainKind;
@property (nonatomic, strong, nullable) UIColor *accentColor;
@property (nonatomic, assign) PPDeepLinkTarget sourceTarget;
@property (nonatomic, assign) PPInputSource source;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, strong, nullable) NSNumber *initialSectionOverride;

@property (nonatomic, strong, nullable) NSArray<MainKindsModel *> *mainKindsArr;

+ (instancetype)inputWithMainKind:(nullable MainKindsModel *)mainKind;

+ (instancetype)inputWithMainKindsArr:(NSArray<MainKindsModel *> *)mainKindsArr
                     sourceTarget:(PPDeepLinkTarget)sourceTarget
                           source:(PPInputSource)source;


+ (instancetype)inputWithMainKind:(nullable MainKindsModel *)mainKind
                     sourceTarget:(PPDeepLinkTarget)sourceTarget
                           source:(PPInputSource)source;

@end

NS_ASSUME_NONNULL_END
