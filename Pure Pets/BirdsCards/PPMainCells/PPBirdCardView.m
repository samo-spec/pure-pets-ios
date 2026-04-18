//
//  PPBirdCardView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/12/2025.
//


#import "PPBirdCardView.h"
#import "CardModel.h"

@interface PPBirdCardView ()
@property (nonatomic, assign) ParentIs parentType;

@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, strong) UIImageView *sexualImageView;

@property (nonatomic, strong) UILabel *ringLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *dataView;
@property (nonatomic, strong) UIView *statusOverlay;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong, readwrite) UIButton *menuButton;
@end

@implementation PPBirdCardView


-(void)layoutSubviews
{
    [super layoutSubviews];
    
    // Ensure Auto Layout finished
    [self.imageView layoutIfNeeded];
    
    CGFloat radius = CGRectGetHeight(self.imageView.bounds) / 2.0;
    self.imageView.layer.cornerRadius = radius;
  
    
    
}
#pragma mark - Init

- (instancetype)initWithParentIs:(ParentIs)parent {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _parentType = parent;
        LOG_EMOJI_INFO(@"PPBirdCardView init %@", parent == ParentIsFather ? @"Father" : @"Mother");
        [self buildUI];
    }
    return self;
}

#pragma mark - UI

- (void)buildUI {

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = AppClearClr;
 

    self.dataView = [[UIView alloc] init];
    self.dataView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dataView.backgroundColor = AppBackgroundClr;
    self.dataView.clipsToBounds = YES;
    self.dataView.layer.cornerRadius = 22;
    [self addSubview:self.dataView];

    
    
    /* Image */
    self.imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"placeholder3"]];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.clipsToBounds = YES;
    [self.imageView pp_setBorderColor:AppForgroundColr];
    self.imageView.layer.borderWidth = 3;
    [self addSubview:self.imageView];
    
    
    /* Image  */
    self.sexualImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"male"]];
    self.sexualImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sexualImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.sexualImageView.clipsToBounds = NO;
    [self.sexualImageView pp_setBorderColor:AppClearClr];
    self.sexualImageView.alpha = 0.0;
    
    self.sexualImageView.tintColor = AppBackgroundClr;
    [self.dataView  addSubview:self.sexualImageView];
    
    
  
    /* Ring label */
    self.ringLabel = [UILabel new];
    self.ringLabel.font = [GM boldFontWithSize:14];
    self.ringLabel.textColor = UIColor.labelColor;
    self.ringLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dataView addSubview:self.ringLabel];

    /* Parent title */
    self.titleLabel = [UILabel new];
    self.titleLabel.font = [GM MidFontWithSize:13];
    self.titleLabel.textColor = AppSecondaryTextClr;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text =
    self.parentType == ParentIsFather ? kLang(@"father_card_accessibility") : kLang(@"mother_card_accessibility");
    [self.dataView addSubview:self.titleLabel];

    /* Menu button */
    self.menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.menuButton.translatesAutoresizingMaskIntoConstraints = NO;

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.image = [UIImage systemImageNamed:@"ellipsis"];
        cfg.baseForegroundColor = AppPrimaryClr;
        self.menuButton.configuration = cfg;
    } else {
        [self.menuButton setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
        self.menuButton.tintColor = AppPrimaryClr;
        self.menuButton.layer.cornerRadius = 22;
        self.menuButton.clipsToBounds = YES;
    }
    [self.dataView addSubview:self.menuButton];

    /* Status overlay */
    self.statusOverlay = [UIView new];
    self.statusOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusOverlay.backgroundColor =
    [UIColor.blackColor colorWithAlphaComponent:0.55];
    self.statusOverlay.layer.cornerRadius = 22;
    self.statusOverlay.hidden = YES;

    self.statusLabel = [UILabel new];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [GM boldFontWithSize:14];
    self.statusLabel.textColor = UIColor.whiteColor;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;

    [self.statusOverlay addSubview:self.statusLabel];
    [self addSubview:self.statusOverlay];

    /* Constraints */
    [NSLayoutConstraint activateConstraints:@[
        // Image
        [self.imageView.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
        [self.imageView.widthAnchor constraintEqualToConstant:70],
        [self.imageView.heightAnchor constraintEqualToConstant:70],
        [self.imageView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:0],
        //[self.imageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
         
        [self.dataView.heightAnchor constraintEqualToConstant:100],
        [self.dataView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:0],
        [self.dataView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-0],

        
        [self.sexualImageView.topAnchor constraintEqualToAnchor:self.dataView.topAnchor constant:5],
        [self.sexualImageView.trailingAnchor constraintEqualToAnchor:self.dataView.trailingAnchor constant:-5],
        [self.sexualImageView.heightAnchor constraintEqualToConstant:22],
        [self.sexualImageView.widthAnchor constraintEqualToConstant:22],
        
        // Menu
        [self.menuButton.bottomAnchor constraintEqualToAnchor:self.dataView.bottomAnchor constant:-12],
        [self.menuButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [self.menuButton.widthAnchor constraintEqualToConstant:32],
        [self.menuButton.heightAnchor constraintEqualToConstant:32],
        
        // Title
        [self.titleLabel.heightAnchor constraintEqualToConstant:18],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.dataView.leadingAnchor constant:12],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.dataView.trailingAnchor constant:-12],
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.dataView.bottomAnchor constant:-12],

        // Ring
        [self.ringLabel.bottomAnchor constraintEqualToAnchor:self.titleLabel.topAnchor constant:-12],
        [self.ringLabel.leadingAnchor constraintEqualToAnchor:self.dataView.leadingAnchor constant:12],
        [self.ringLabel.trailingAnchor constraintEqualToAnchor:self.dataView.trailingAnchor constant:-12],
        [self.ringLabel.heightAnchor constraintEqualToConstant:18],
       
        [self.imageView.bottomAnchor constraintEqualToAnchor:self.dataView.topAnchor constant:30],
        // Status overlay
        [self.statusOverlay.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.statusOverlay.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.statusOverlay.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.statusOverlay.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.statusOverlay.centerXAnchor],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.statusOverlay.centerYAnchor],
        
        
        [self.imageView.widthAnchor constraintEqualToAnchor:self.imageView.heightAnchor constant:-0],

    ]];
}

#pragma mark - Configure

- (void)configureWithCard:(CardModel *)card
                   ringID:(NSString *)ringID
                 isFather:(BOOL)isFather {

    LOG_EMOJI_INFO(@"Configure %@ card", isFather ? @"Father" : @"Mother");

    self.ringLabel.text = ringID ?: @"—";

    if (card.imagesUrls.count > 0) {
        NSURL *url = card.imagesUrls.firstObject;
        [self.imageView sd_setImageWithURL:url
                          placeholderImage:[UIImage imageNamed:@"placeholder3"]];
    } else {
        self.imageView.image = [UIImage imageNamed:@"placeholder3"];
    }
    
    self.sexualImageView.image = isFather ? [UIImage imageNamed:@"male"] : [UIImage imageNamed:@"female"];
    self.sexualImageView.tintColor = UIColor.darkGrayColor; // isFather ? [UIColor systemBlueColor] :  [UIColor systemPinkColor];

   
    
}

#pragma mark - Status States

- (void)showSoldState {
    LOG_EMOJI_WARN(@"Parrot sold");
    self.statusLabel.text = kLang(@"parrot_is_sold");
    self.statusOverlay.hidden = NO;
}

- (void)showDeletedState {
    LOG_EMOJI_WARN(@"Parrot deleted");
    self.statusLabel.text = kLang(@"card_was_deleted");
    self.statusOverlay.hidden = NO;
}

- (void)showArchivedStateWithName:(NSString *)archiveName {
    LOG_EMOJI_WARN(@"Parrot archived");
    self.statusLabel.text =
    [NSString stringWithFormat:@"%@ %@", kLang(@"moved_to_archive"), archiveName ?: @""];
    self.statusOverlay.hidden = NO;
}

- (void)clearStatusState {
    self.statusOverlay.hidden = YES;
    self.statusLabel.text = @"";
}

- (void)setStatus:(PPBirdCardStatus)status
       archiveName:(NSString *)archiveName
{
    _status = status;

    self.statusOverlay.hidden = (status == PPBirdCardStatusNormal);
    
    
    
    [self clearStatusState];

    switch (status) {

        case PPBirdCardStatusSold:
            [self showSoldState];
            break;

        case PPBirdCardStatusDeleted:
            [self showDeletedState];
            break;

        case PPBirdCardStatusArchived:
            if (archiveName.length) {
                [self showArchivedStateWithName:archiveName];
            } else {
                self.statusLabel.text = kLang(@"card_moved_to_archive");
            }
            break;

        case PPBirdCardStatusNormal:
        default:
            [self clearStatusState];
            break;
    }

    //NSLog(@"🐦 BirdCard status set: %ld", (long)status);
}


@end
