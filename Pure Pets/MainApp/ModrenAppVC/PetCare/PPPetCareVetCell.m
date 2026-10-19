//
//  PPPetCareVetCell.m
//  Pure Pets
//
//  Reinvented from absolute first principles for NextGen V6 Flagship.
//  Category-defining clinical specialist card hosted via PPVetCardBridge (SwiftUI).
//

#import "PPPetCareVetCell.h"
#import "VetModel.h"
#import <Pure_Pets-Swift.h>

@interface PPPetCareVetCell ()
@property (nonatomic, strong, nullable) VetModel *vet;
@property (nonatomic, copy, nullable) NSString *mainKindName;
@end

@implementation PPPetCareVetCell

+ (NSString *)reuseIdentifier
{
    return PPPetCareVetCellID;
}

+ (CGFloat)preferredHeightForVet:(VetModel *)vet
                    mainKindName:(nullable NSString *)mainKindName
                           width:(CGFloat)width
                 traitCollection:(UITraitCollection *)traitCollection
{
    BOOL isAccessibility = NO;
    if (traitCollection) {
        isAccessibility = UIContentSizeCategoryIsAccessibilityCategory(traitCollection.preferredContentSizeCategory);
    }
    return [PPVetCardBridge preferredHeightWithVet:vet
                                      mainKindName:mainKindName
                                             width:width
                                   isAccessibility:isAccessibility];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
    }
    return self;
}

- (void)configureWithVet:(VetModel *)vet mainKindName:(nullable NSString *)mainKindName
{
    _vet = vet;
    _mainKindName = [mainKindName copy];
    [self pp_rebindContent];
}

- (void)setOnDetailsTap:(void (^)(void))onDetailsTap
{
    _onDetailsTap = [onDetailsTap copy];
    [self pp_rebindContent];
}

- (void)setOnCallTap:(void (^)(void))onCallTap
{
    _onCallTap = [onCallTap copy];
    [self pp_rebindContent];
}

- (void)setOnWhatsAppTap:(void (^)(void))onWhatsAppTap
{
    _onWhatsAppTap = [onWhatsAppTap copy];
    [self pp_rebindContent];
}

- (void)pp_rebindContent
{
    if (!_vet) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [PPVetCardBridge configureWithCell:self
                                   vet:_vet
                          mainKindName:_mainKindName
                          onDetailsTap:^{
                              if (weakSelf.onDetailsTap) {
                                  weakSelf.onDetailsTap();
                              }
                          }
                             onCallTap:^{
                              if (weakSelf.onCallTap) {
                                  weakSelf.onCallTap();
                              }
                          }
                         onWhatsAppTap:^{
                              if (weakSelf.onWhatsAppTap) {
                                  weakSelf.onWhatsAppTap();
                              }
                          }];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _vet = nil;
    _mainKindName = nil;
    _onDetailsTap = nil;
    _onCallTap = nil;
    _onWhatsAppTap = nil;
}

@end
