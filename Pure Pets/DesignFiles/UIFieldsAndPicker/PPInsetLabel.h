//
//  PPInsetLabel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//


// PPInsetLabel.h
@interface PPInsetLabel : UILabel
@property (nonatomic) UIEdgeInsets textInsets;
@end














NS_ASSUME_NONNULL_BEGIN

@interface UILabel (LineSpacing)

/// Sets custom line spacing for the label text.
/// @param spacing The desired spacing (e.g. 2.0 or 4.0)
- (void)setLineSpacing:(CGFloat)spacing;

/// Sets line spacing while keeping existing attributes like color & font.
- (void)setLineSpacing:(CGFloat)spacing text:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
