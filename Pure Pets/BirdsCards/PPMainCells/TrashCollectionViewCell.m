//
//  TrashCollectionViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/12/2025.
//


//
//  TrashCollectionViewCell.m
//  Pure Pets
//

#import "TrashCollectionViewCell.h"
#import "TrashModel.h"

@interface TrashCollectionViewCell ()
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *typeLabel;
@property (nonatomic, strong) UIButton *restoreButton;
@property (nonatomic, strong) UIButton *deleteButton;
@end

@implementation TrashCollectionViewCell

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.trash = nil;
    self.indexPath = nil;
    self.iconView.image = [UIImage imageNamed:@"placeholder3"];
    self.titleLabel.text = @"";
    self.dateLabel.text = @"";
    self.typeLabel.text = @"";
}

- (void)configureWithTrash:(TrashModel *)trash
{
     

  
    self.trash = trash;
    _titleLabel.text = trash.title.length ? trash.title : kLang(@"UnknownItem");
    
    _titleLabel.numberOfLines = 2;
    
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateStyle = NSDateFormatterMediumStyle;
    _dateLabel.text =
    [NSString stringWithFormat:@"%@ %@",
     kLang(@"Deleted"),
     [df stringFromDate:trash.DeletedAt]];

    switch (trash.RefType) {
        case RefTypeCard:
            _typeLabel.text = kLang(@"cards");
            break;
        case RefTypeCage:
            _typeLabel.text = kLang(@"cages");
            break;
        case RefTypeChild:
            _typeLabel.text = kLang(@"childs");
            break;
        case RefTypeArchive:
            _typeLabel.text = kLang(@"archive");
            break;
        default:
            _typeLabel.text = kLang(@"UnknownItem");
            break;
    }

    NSString *placeholder =
    (trash.RefType == RefTypeChild) ? @"placeholderCK" : @"placeholder3";

    [GM setImageFromUrlString:trash.imageUrl
                    imageView:_iconView
                      phImage:placeholder];
    
    /*
     switch (trash.RefType) {
         case RefTypeCard:
            // _iconView.image = [UIImage systemImageNamed:@"doc.text"];
             break;
         case RefTypeCage:
             //_iconView.image = [UIImage systemImageNamed:@"square.grid.2x2"];
             break;
         case RefTypeChild:
             //_iconView.image = [UIImage systemImageNamed:@"person"];
             break;
         case RefTypeArchive:
             //_iconView.image = [UIImage systemImageNamed:@"archivebox"];
             break;
     }
     */
}



- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.contentView.backgroundColor = AppForgroundColr;
    self.contentView.layer.cornerRadius = 22;
    self.contentView.layer.masksToBounds = YES;

    _iconView = [UIImageView new];
    _iconView.layer.cornerRadius = 20;
    _iconView.layer.masksToBounds = YES;
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFill;
    [self.contentView addSubview:_iconView];

    _titleLabel = [UILabel new];
    _titleLabel.font = [GM boldFontWithSize:16];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_titleLabel];
 
    _dateLabel = [UILabel new];
    _dateLabel.font = [GM MidFontWithSize:13];
    _dateLabel.textColor = UIColor.secondaryLabelColor;
    _dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_dateLabel];
    
    _typeLabel = [UILabel new];
    _typeLabel.font = [GM fontWithSize:13];
    _typeLabel.textColor = UIColor.tertiaryLabelColor;
    _typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_typeLabel];

    _restoreButton = [self glassButtonWithTitle:kLang(@"Restore")
                                          image:@"arrow.uturn.left" forButton:1];
    [_restoreButton addTarget:self
                       action:@selector(didTapRestore)
             forControlEvents:UIControlEventTouchUpInside];

    _deleteButton = [self glassButtonWithTitle:kLang(@"Delete")
                                         image:@"trash.fill" forButton:0];
    [_deleteButton addTarget:self
                      action:@selector(didTapDelete)
            forControlEvents:UIControlEventTouchUpInside];

    [self.contentView addSubview:_restoreButton];
    [self.contentView addSubview:_deleteButton];

    [self setupConstraints];
    return self;
}

#pragma mark - Configure

#pragma mark - Actions

- (void)didTapRestore
{
    if (!self.trash) return;
    [self.delegate trashRestore:self.trash];
}

- (void)didTapDelete
{
    if (!self.indexPath) return;
    [self.delegate trashCellDidTapDeleteForever:self.indexPath];
}

#pragma mark - Glass Button Factory

- (UIButton *)glassButtonWithTitle:(NSString *)title image:(NSString *)systemImage forButton:(NSInteger)forButton
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration prominentGlassButtonConfiguration];
        cfg.baseBackgroundColor = forButton == 0 ? [AppPrimaryClr colorWithAlphaComponent:0.05] : AppForgroundColr;
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.title = title;
        cfg.image = [UIImage systemImageNamed:systemImage];
        cfg.imagePadding = 6;
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attrs) {
            NSMutableDictionary *m = attrs.mutableCopy;
            m[NSFontAttributeName] = [GM MidFontWithSize:14];
            return m;
        };
        btn.configuration = cfg;
    } else {
        [btn setTitle:title forState:UIControlStateNormal];
        [btn setImage:[UIImage systemImageNamed:systemImage]
             forState:UIControlStateNormal];
        btn.tintColor = AppPrimaryClr;
        btn.titleLabel.font = [GM MidFontWithSize:14];
    }

    btn.translatesAutoresizingMaskIntoConstraints = NO;
    return btn;
}

#pragma mark - Layout

- (void)setupConstraints
{
    [NSLayoutConstraint activateConstraints:@[
        [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [_iconView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [_iconView.widthAnchor constraintEqualToConstant:90],
        [_iconView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
        [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],

        [_dateLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_dateLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
        
        [_typeLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_typeLabel.topAnchor constraintEqualToAnchor:_dateLabel.bottomAnchor constant:2],
        [_typeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_restoreButton.leadingAnchor constant:-8],

        [_deleteButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14],
        [_deleteButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [_deleteButton.heightAnchor constraintEqualToConstant:40],

        [_restoreButton.trailingAnchor constraintEqualToAnchor:_deleteButton.leadingAnchor constant:-8],
        [_restoreButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [_restoreButton.heightAnchor constraintEqualToConstant:40],
    ]];
}

@end
