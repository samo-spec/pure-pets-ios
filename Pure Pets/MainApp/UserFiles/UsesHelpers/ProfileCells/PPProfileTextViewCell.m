//
//  PPProfileTextViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//


#import "PPProfileTextViewCell.h"

@interface PPProfileTextViewCell ()
@property (nonatomic, assign) BOOL pp_didSetupViews;
- (void)pp_commonInit;
@end

@implementation PPProfileTextViewCell

- (instancetype)init
{
    return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    [self pp_commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }

    [self pp_commonInit];
    return self;
}

- (void)pp_commonInit
{
    if (self.pp_didSetupViews) {
        return;
    }
    self.pp_didSetupViews = YES;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UITextView *textView = [[UITextView alloc] init];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.backgroundColor = UIColor.clearColor;
    textView.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    textView.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    textView.scrollEnabled = NO;
    textView.textContainerInset = UIEdgeInsetsZero;
    textView.textContainer.lineFragmentPadding = 0.0;
    textView.autocorrectionType = UITextAutocorrectionTypeNo;
    textView.textAlignment = Language.alignmentForCurrentLanguage;
    textView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    [self.contentView addSubview:textView];
    self.textView = textView;

    UILabel *placeholderLabel = [[UILabel alloc] init];
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderLabel.font = textView.font;
    placeholderLabel.textColor = UIColor.placeholderTextColor;
    placeholderLabel.numberOfLines = 0;
    placeholderLabel.userInteractionEnabled = NO;
    [self.contentView addSubview:placeholderLabel];
    self.placeholderLabel = placeholderLabel;

    NSLayoutConstraint *heightConstraint = [textView.heightAnchor constraintGreaterThanOrEqualToConstant:116.0];
    heightConstraint.active = YES;
    self.textViewHeightConstraint = heightConstraint;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
        
        [textView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [textView.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [textView.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],

        [placeholderLabel.topAnchor constraintEqualToAnchor:textView.topAnchor],
        [placeholderLabel.leadingAnchor constraintEqualToAnchor:textView.leadingAnchor constant:2.0],
        [placeholderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:textView.trailingAnchor]
    ]];
}

- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
                 fieldKind:(PPProfileFieldKind)fieldKind
                  delegate:(id<UITextViewDelegate>)delegate
{
    self.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.textView.tag = fieldKind;
    self.textView.delegate = delegate;
    self.textView.textAlignment = Language.alignmentForCurrentLanguage;
    self.textView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.textView.text = text ?: @"";
    self.placeholderLabel.text = placeholder ?: @"";
    self.placeholderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self updatePlaceholderVisibility];
    [self updatePreferredHeight];
}

- (void)updatePreferredHeight
{
    CGFloat fittingWidth = CGRectGetWidth(self.textView.bounds);
    if (fittingWidth <= 1.0) {
        fittingWidth = UIScreen.mainScreen.bounds.size.width - 72.0;
    }
    CGSize targetSize = CGSizeMake(MAX(120.0, fittingWidth), CGFLOAT_MAX);
    CGFloat preferredHeight = ceil([self.textView sizeThatFits:targetSize].height);
    self.textViewHeightConstraint.constant = MAX(116.0, preferredHeight);
}

- (void)updatePlaceholderVisibility
{
    self.placeholderLabel.hidden = self.textView.text.length > 0;
}

@end
