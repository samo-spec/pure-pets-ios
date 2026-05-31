//
//  EmptyStateView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/07/2025.
//


#import <UIKit/UIKit.h>


@interface EmptyStateView : UIView

@property (nonatomic, strong) LOTAnimationView *animationView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subTitleLabel;
@property (nonatomic, assign) float animationViewSize;
@property (nonatomic, strong) UIButton *reloadButton;
@property (nonatomic, strong) UIStackView *stackView;
- (void)setReloadButtonTitle:(NSString *)title;
- (instancetype)initWithFrame:(CGRect)frame
               animationNamed:(NSString *)animationName
                        title:(NSString *)title
                       subTitle:(NSString *)subTitle
                  buttonTitle:(NSString *)buttonTitle
                       target:(id)target
                emptyIconSize:(float)emptyIconSize
                       isNetworkFile:(BOOL)isNetworkFile
                       action:(SEL)action;


- (instancetype)initWithFrame:(CGRect)frame
               animationNamed:(NSString *)animationName
                      title:(NSString *)title
                     subTitle:(NSString *)subTitle
                  buttonTitle:(NSString *)buttonTitle
                       target:(id)target
                       isNetworkFile:(BOOL)isNetworkFile
                       action:(SEL)action;

@end
