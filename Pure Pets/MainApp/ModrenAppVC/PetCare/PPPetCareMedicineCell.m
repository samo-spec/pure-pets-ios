//
//  PPPetCareMedicineCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/26/26.
//

#import "PPPetCareMedicineCell.h"
#import "PPImageLoaderManager.h"
NS_ASSUME_NONNULL_BEGIN



@implementation PPPetCareMedicineCell {
    UIView *_surfaceView;
    UIView *_surfaceFill;
    UIView *_imageShellView;
    UIImageView *_imageView;
    UILabel *_titleLabel;
    UILabel *_descriptionLabel;
    UILabel *_priceLabel;
    UILabel *_statusLabel;
    UILabel *_categoryLabel;
    UIButton *_detailsButton;
}

+ (NSString *)reuseIdentifier
{
    return PPPetCareMedicineCellID;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.layer.cornerRadius = 28.0;
    _surfaceView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _surfaceView.layer.shadowOpacity = 0.10;
    _surfaceView.layer.shadowRadius = 20.0;
    _surfaceView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [self.contentView addSubview:_surfaceView];

    _surfaceFill = [[UIView alloc] init];
    _surfaceFill.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceFill.backgroundColor = PPPetCareSurfaceColor();
    _surfaceFill.layer.cornerRadius = 28.0;
    _surfaceFill.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _surfaceFill.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_surfaceFill];

    _imageShellView = [[UIView alloc] init];
    _imageShellView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageShellView.layer.cornerRadius = 22.0;
    _imageShellView.layer.borderWidth = 0.8;
    _imageShellView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _imageShellView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceFill addSubview:_imageShellView];

    _imageView = [[UIImageView alloc] init];
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    _imageView.tintColor = PPPetCareAccentColor();
    [_imageShellView addSubview:_imageView];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.layer.cornerRadius = 13.0;
    _statusLabel.layer.masksToBounds = YES;
    [_surfaceFill addSubview:_statusLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    _titleLabel.textColor = PPPetCareTextColor();
    _titleLabel.numberOfLines = 2;
    [_surfaceFill addSubview:_titleLabel];

    _descriptionLabel = [[UILabel alloc] init];
    _descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _descriptionLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _descriptionLabel.textColor = PPPetCareSecondaryTextColor();
    _descriptionLabel.numberOfLines = 3;
    [_surfaceFill addSubview:_descriptionLabel];

    _categoryLabel = [[UILabel alloc] init];
    _categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    _categoryLabel.textColor = PPPetCareSecondaryTextColor();
    [_surfaceFill addSubview:_categoryLabel];

    _priceLabel = [[UILabel alloc] init];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    _priceLabel.textColor = PPPetCareTextColor();
    [_surfaceFill addSubview:_priceLabel];

    _detailsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _detailsButton.translatesAutoresizingMaskIntoConstraints = NO;
    _detailsButton.layer.cornerRadius = 18.0;
    _detailsButton.clipsToBounds = YES;
    _detailsButton.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [_detailsButton addTarget:self action:@selector(pp_detailsTapped) forControlEvents:UIControlEventTouchUpInside];
    [_surfaceFill addSubview:_detailsButton];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_surfaceFill.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor],
        [_surfaceFill.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor],
        [_surfaceFill.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor],
        [_surfaceFill.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor],

        [_imageShellView.topAnchor constraintEqualToAnchor:_surfaceFill.topAnchor constant:16.0],
        [_imageShellView.leadingAnchor constraintEqualToAnchor:_surfaceFill.leadingAnchor constant:16.0],
        [_imageShellView.trailingAnchor constraintEqualToAnchor:_surfaceFill.trailingAnchor constant:-16.0],
        [_imageShellView.heightAnchor constraintEqualToConstant:136.0],

        [_imageView.topAnchor constraintEqualToAnchor:_imageShellView.topAnchor],
        [_imageView.leadingAnchor constraintEqualToAnchor:_imageShellView.leadingAnchor],
        [_imageView.trailingAnchor constraintEqualToAnchor:_imageShellView.trailingAnchor],
        [_imageView.bottomAnchor constraintEqualToAnchor:_imageShellView.bottomAnchor],

        [_statusLabel.topAnchor constraintEqualToAnchor:_surfaceFill.topAnchor constant:16.0],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:_surfaceFill.trailingAnchor constant:-16.0],
        [_statusLabel.heightAnchor constraintEqualToConstant:26.0],
        [_statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:88.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:_imageShellView.bottomAnchor constant:14.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_surfaceFill.leadingAnchor constant:16.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_surfaceFill.trailingAnchor constant:-16.0],

        [_descriptionLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6.0],
        [_descriptionLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_descriptionLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_categoryLabel.topAnchor constraintEqualToAnchor:_descriptionLabel.bottomAnchor constant:10.0],
        [_categoryLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_categoryLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_priceLabel.topAnchor constraintEqualToAnchor:_categoryLabel.bottomAnchor constant:10.0],
        [_priceLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_priceLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_detailsButton.topAnchor constraintEqualToAnchor:_priceLabel.bottomAnchor constant:14.0],
        [_detailsButton.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_detailsButton.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_detailsButton.heightAnchor constraintEqualToConstant:44.0],
        [_detailsButton.bottomAnchor constraintEqualToAnchor:_surfaceFill.bottomAnchor constant:-16.0],
    ]];
    return self;
}

- (void)configureWithMedicine:(VetMedicineModel *)medicine mainKindName:(NSString *)mainKindName
{
    UIColor *accentColor = PPPetCareAccentColor();
    _surfaceView.layer.borderColor = PPPetCareBorderColor().CGColor;
    _imageShellView.layer.borderColor = [accentColor colorWithAlphaComponent:0.12].CGColor;
    _imageShellView.backgroundColor = [accentColor colorWithAlphaComponent:0.08];

    _titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _descriptionLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _categoryLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _priceLabel.textAlignment = [Language alignmentForCurrentLanguage];

    _titleLabel.text = medicine.title.length > 0 ? medicine.title : PPPetCareLocalized(@"pet_care_medicine_untitled", @"Medicine");
    _descriptionLabel.text = medicine.medicineDescription.length > 0 ? medicine.medicineDescription : PPPetCareLocalized(@"pet_care_medicine_default_subtitle", @"Care essentials prepared by approved veterinary partners.");
    _categoryLabel.text = mainKindName.length > 0 ? mainKindName : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    _priceLabel.text = [NSString stringWithFormat:@"%.2f %@", medicine.price, medicine.currency.length > 0 ? medicine.currency : @"QAR"];

    BOOL prescriptionRequired = medicine.requiresPrescription;
    _statusLabel.text = prescriptionRequired
        ? PPPetCareLocalized(@"pet_care_medicine_prescription_required", @"Prescription required")
        : PPPetCareLocalized(@"pet_care_medicine_ready", @"Ready to order");
    _statusLabel.backgroundColor = [accentColor colorWithAlphaComponent:prescriptionRequired ? 0.14 : 0.09];
    _statusLabel.textColor = prescriptionRequired ? [UIColor systemOrangeColor] : accentColor;

    [_detailsButton setTitle:PPPetCareLocalized(@"pet_care_details_button", @"Details") forState:UIControlStateNormal];
    [_detailsButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _detailsButton.backgroundColor = accentColor;
    _detailsButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIImage *placeholder = [UIImage systemImageNamed:@"pills.fill"];
    _imageView.image = placeholder;
    if (medicine.imageUrl.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:_imageView
                                                       url:medicine.imageUrl
                                               placeholder:placeholder
                                          transitionStyle:PPImageTransitionStyleNone
                                                complation:nil];
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:_imageView];
    _imageView.image = nil;
    _titleLabel.text = nil;
    _descriptionLabel.text = nil;
    _priceLabel.text = nil;
    _statusLabel.text = nil;
    _categoryLabel.text = nil;
    self.onDetailsTap = nil;
    self.transform = CGAffineTransformIdentity;
    self.alpha = 1.0;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _surfaceView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_surfaceView.bounds
                                                               cornerRadius:_surfaceView.layer.cornerRadius].CGPath;
}

- (void)pp_detailsTapped
{
    if (self.onDetailsTap) {
        self.onDetailsTap();
    }
}

@end

NS_ASSUME_NONNULL_END
