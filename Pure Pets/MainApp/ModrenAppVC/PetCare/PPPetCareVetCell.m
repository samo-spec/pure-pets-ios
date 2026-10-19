//
//  PPPetCareVetCell.m
//  Pure Pets
//
//  Hosts distinct veterinarian and clinic discovery compositions.
//

#import "PPPetCareVetCell.h"
#import "VetModel.h"
#import <Pure_Pets-Swift.h>

@interface PPPetCareVetCell ()
@property (nonatomic, strong, nullable) VetModel *vet;
@property (nonatomic, copy, nullable) NSString *mainKindName;
@property (nonatomic, assign) CGFloat hostedWidth;
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
    return [PPVetCardBridge preferredHeightWithVet:vet
                                      mainKindName:mainKindName
                                             width:width
                               contentSizeCategory:traitCollection.preferredContentSizeCategory ?: UIContentSizeCategoryLarge
                                  legibilityWeight:traitCollection.legibilityWeight];
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
}

- (void)setOnCallTap:(void (^)(void))onCallTap
{
    _onCallTap = [onCallTap copy];
}

- (void)setOnWhatsAppTap:(void (^)(void))onWhatsAppTap
{
    _onWhatsAppTap = [onWhatsAppTap copy];
}

- (void)pp_rebindContent
{
    if (!_vet) {
        return;
    }
    self.hostedWidth = CGRectGetWidth(self.bounds);
    // These closures read the current callbacks. Setting each callback does not
    // need to rebuild the SwiftUI host or restart image loading.
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

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    if (_vet && width > 0 && fabs(width - self.hostedWidth) > 0.5) {
        [self pp_rebindContent];
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [PPVetCardBridge cellDidMoveToWindow:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (![previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory] ||
        previousTraitCollection.legibilityWeight != self.traitCollection.legibilityWeight) {
        [self pp_rebindContent];
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _vet = nil;
    _mainKindName = nil;
    _onDetailsTap = nil;
    _onCallTap = nil;
    _onWhatsAppTap = nil;
    _hostedWidth = 0;
    [PPVetCardBridge clearCell:self];
}

@end
