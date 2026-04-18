// PPBirdSummaryCollectionCell.m

#import "PPBirdSummaryCollectionCell.h"
 #import "ZMJTipView.h"
#import "GM.h"                     // Assumed general utilities
#import "AppManager.h"
 #import "PPFunc.h"
#import "FileModel.h"
#import "ArchiveModel.h"
#import "CageModel.h"

@interface PPBirdSummaryCollectionCell ()
@property (nonatomic, strong) UIMenu *transactionMenu;
@property (nonatomic, strong) UIMenu *shareOptionsMenu;
@property (nonatomic, strong) UIMenu *moreOptionsMenu;
@end




#pragma mark - Style

@implementation PPBirdSummaryCellStyle
- (instancetype)init {
    if ((self = [super init])) {
        _cardBackground = UIColor.systemBackgroundColor;
        _titleColor     = UIColor.labelColor;
        _metaColor      = UIColor.secondaryLabelColor;
        _brandColor     = [UIColor colorWithRed:0.78 green:0.02 blue:0.25 alpha:1.0];
        _cardCorner     = 32;
        _photoCorner    = 4.0;
    }
    return self;
}
@end

#pragma mark - Cell

@implementation PPBirdSummaryCollectionCell {
    // Private UI properties
    UIView *_card;
    UIView *_photoShadowView;
    UIView *_photoCard;
    UIImageView *_photoView;

     UIButton *_archiveBTN;
    UIStackView *_rightStack;
    UILabel *_titleLabel, *_line1, *_line2, *_line3, *_line4;
    UIButton *_TransactionBTN;
    UIView *_topView;
 }

/*
 ,
 [UIAction actionWithTitle:kLang(@"Post as advertise")
                     image:[UIImage systemImageNamed:@"camera"]
                identifier:nil
                   handler:^(__kindof UIAction * _Nonnull action) {
     __strong typeof(weakSelf) self = weakSelf;
     if (!self) return;

     [self.delegate shareCard:4
                        index:4
                    cardImage:self->_photoView.image
                      subKind:self.cardModel.subKindString
                       cardID:self.cardModel.ID];
 }],
 */

- (void)buildTransactionMenuIfNeeded {
    if (self.transactionMenu) return;

    __weak typeof(self) weakSelf = self;

    UIAction *shareAction =
    [UIAction actionWithTitle:kLang(@"share")
                        image:[UIImage systemImageNamed:@"square.and.arrow.up"]
                   identifier:nil
                      handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self.delegate shareCard:3
                           index:3
                       cardImage:self->_photoView.image
                         subKind:self.cardModel.subKindString
                          cardID:self.cardModel.ID];
    }];
    // NOTE: Do NOT use UIMenuElementAttributesKeepsMenuPresented here.
    // It keeps the context menu presented while the share handler fires,
    // causing "already presenting" crash when UIActivityViewController is shown.
    
    
    // ========= Share submenu =========
    _shareOptionsMenu =
    [UIMenu menuWithTitle:@""
                    image:[UIImage systemImageNamed:@"square.and.arrow.up"]
               identifier:nil
                  options:UIMenuOptionsDisplayInline
                 children:@[
        [UIAction actionWithTitle:kLang(@"archive")
                            image:[UIImage systemImageNamed:@"archivebox"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            [self.delegate archiveCardData:self.cardModel
                             cellIndexPath:self.cellIndexPath];
        }],
        [UIAction actionWithTitle:kLang(@"sale")
                            image:[UIImage systemImageNamed:@"tag"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            [self.delegate sellThisCard:self.cardModel
                           lastLocation:CardSectionCards
                              cageIndex:0];
        }],shareAction
    ]];
 
    
    // ===== Edit action =====
    UIAction *editAction =
    
    [UIAction actionWithTitle:kLang(@"editCard")
                        image:[UIImage systemImageNamed:@"pencil"]
                   identifier:nil
                      handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self.delegate deleteEditOptions:0 CardData:self.cardModel];
    }];
    if (@available(iOS 16.0, *)) {
        editAction.state =  UIMenuElementStateOff;
        
    } else {
        // Fallback on earlier versions
    }
    // ===== Delete action (destructive) =====
    UIAction *deleteAction =
    [UIAction actionWithTitle:kLang(@"deleteCard")
                        image:[UIImage systemImageNamed:@"trash"]
                   identifier:nil
                       handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self.delegate deleteEditOptions:1 CardData:self.cardModel];
    }];
    deleteAction.attributes = UIMenuElementAttributesDestructive;
    // ===== QR Code action =====
    UIAction *qrAction =
    [UIAction actionWithTitle:kLang(@"craeteQrCode")
                        image:[UIImage systemImageNamed:@"barcode.viewfinder"]
                   identifier:nil
                      handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self.delegate deleteEditOptions:2 CardData:self.cardModel];
    }];
 
    _moreOptionsMenu =
    [UIMenu menuWithTitle:kLang(@"more")
                    image:[UIImage systemImageNamed:@"wand.and.outline.inverse"]
               identifier:nil
                  options:UIMenuOptionsSingleSelection
                 children:@[editAction,qrAction,deleteAction ]];
    if (@available(iOS 16.0, *)) {
        _moreOptionsMenu.preferredElementSize =  UIMenuElementSizeLarge;
    } else {
        // Fallback on earlier versions
    }
    
 }

- (NSString *)transactionMenuTitle {
    NSString *ringID = self.cardModel.RingID ?: @"";
    if (ringID.length == 0) {
        return kLang(@"Bird Actions");
    }
    return [NSString stringWithFormat:@"%@ • %@",
            kLang(@"Bird Actions"),
            ringID];
}


- (UIView *)createFilledCardView
{
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;

    // Background
    card.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:1.0];
   
    card.clipsToBounds = YES;
 

    return card;
}



-(void)createTBTN
{
    // ================================
    // Transaction Button (Share / Sale)
    // ================================

    _TransactionBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    _TransactionBTN.translatesAutoresizingMaskIntoConstraints = NO;
    
   
    
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(0, 0, 0, 0);
        cfg.image = [UIImage systemImageNamed:@"circle.hexagongrid.circle"]; //gearshape.arrow.trianglehead.2.clockwise.rotate.90  // smallcircle.filled.circle //smallcircle.filled.circle
        cfg.imagePadding = 2;
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.background.backgroundColor = UIColor.clearColor;
        cfg.baseBackgroundColor = UIColor.clearColor;
        
        UIImageSymbolConfiguration *palette =
        [UIImageSymbolConfiguration  configurationWithPaletteColors:@[AppPrimaryClr,UIColor.lightGrayColor]];

        UIImageSymbolConfiguration *size =
        [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];

        // Combine configurations
        UIImageSymbolConfiguration *finalConfig =
            [palette configurationByApplyingConfiguration:size];

        cfg.preferredSymbolConfigurationForImage = finalConfig;
        
        
        _TransactionBTN.configuration = cfg;
        _TransactionBTN.configurationUpdateHandler = ^(UIButton *btn) {
            btn.layer.shadowOpacity = 0.08;
            [btn pp_setShadowColor:UIColor.blackColor];
            btn.layer.shadowRadius = 10.0;
            btn.layer.shadowOffset = CGSizeMake(0, 4);
        };
    }
     else {
        _TransactionBTN.clipsToBounds = YES;
        _TransactionBTN.layer.cornerRadius = 18;
         _TransactionBTN.tintColor = [AppPrimaryClr colorWithAlphaComponent:1];
        [_TransactionBTN setImage:
         [UIImage pp_symbolNamed:@"circle.hexagongrid.circle" pointSize:16 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleDefault palette:@[AppPrimaryClr,AppPrimaryClr] makeTemplate:YES]
                         forState:UIControlStateNormal];

        _TransactionBTN.backgroundColor =
        [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.6];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [_TransactionBTN.widthAnchor constraintEqualToConstant:42],
        [_TransactionBTN.heightAnchor constraintEqualToConstant:42],
    ]];
    
    
    
    [_topView addSubview:_TransactionBTN];

    [self buildTransactionMenuIfNeeded];

   
    
     
}
+ (NSString *)reuseIdentifier { return @"PPBirdSummaryCollectionCell"; }

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.contentView.backgroundColor = UIColor.clearColor;
        _style = [PPBirdSummaryCellStyle new];
        [self buildUI];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    // Clear all dynamic content to avoid reuse artifacts
    self.cardModel = nil;
    self.currentImageURL = nil;
    _photoView.image = nil;
    _titleLabel.text = @"";
    _line1.text = @"";
    _line2.text = @"";
    _line3.text = @"";
    _line4.text = @"";

    //[_archiveBTN setTitle:@"" forState:UIControlStateNormal];
    
    _archiveBTN.alpha = 0.0;
    _TransactionBTN.menu = nil;
    
    // Optionally clear quick-action items
    //[self.actionsView setActions:@[]];
   
    [self layoutSubviews];
}

#pragma mark - Build UI

- (UILabel *)metaLabel {
    UILabel *l = [UILabel new];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.font = [GM boldFontWithSize:14];
    l.textColor = UIColor.secondaryLabelColor;
    l.numberOfLines = 1;
    return l;
}

- (void)buildUI {
    // Card container
    
    
    _card = [UIView new];
    _card.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    _card.translatesAutoresizingMaskIntoConstraints = NO;
    _card.backgroundColor = self.style.cardBackground;
    _card.layer.cornerRadius = 28.0;
    //[GM addCornersToView:_card tl:self.style.cardCorner tr:self.style.cardCorner bl:self.style.cardCorner + 15 br:self.style.cardCorner + 15];
    //_card.clipsToBounds = YES;
    //_card.layer.shadowColor = [UIColor blackColor].CGColor;
    _card.layer.shadowOpacity = 0.08;
    _card.layer.shadowRadius = 10;
    _card.layer.shadowOffset = CGSizeMake(0, 4);
    [self.contentView addSubview:_card];

    
    _topView = [self createFilledCardView];
    _topView.layer.cornerRadius = 25.0;
    [_card addSubview:_topView];
     
    // Photo shadow container (handles shadow only)
    _photoShadowView = [UIView new];
    _photoShadowView.translatesAutoresizingMaskIntoConstraints = NO;
    _photoShadowView.backgroundColor = UIColor.clearColor;
    [_photoShadowView pp_setShadowColor:[UIColor blackColor]];
    _photoShadowView.layer.shadowOpacity = 0.08;
    _photoShadowView.layer.shadowRadius = 10;
    _photoShadowView.layer.shadowOffset = CGSizeMake(0, 4);
    [_card addSubview:_photoShadowView];

    // Photo card (handles corner radius + clipping)
    _photoCard = [UIView new];
    _photoCard.translatesAutoresizingMaskIntoConstraints = NO;
    _photoCard.backgroundColor = UIColor.secondarySystemBackgroundColor;
    _photoCard.layer.cornerRadius = 22;
    _photoCard.clipsToBounds = YES;
    [_photoShadowView addSubview:_photoCard];

    // Image view
    _photoView = [UIImageView new];
    _photoView.translatesAutoresizingMaskIntoConstraints = NO;
    _photoView.contentMode = UIViewContentModeScaleAspectFill;
    _photoView.clipsToBounds = YES;
    [_photoCard addSubview:_photoView];

   
    // Archive button
    _archiveBTN = [UIButton systemButtonWithPrimaryAction:nil];
    _archiveBTN.translatesAutoresizingMaskIntoConstraints = NO;
    [_archiveBTN setTitleColor:AppPrimaryTextClr forState:UIControlStateNormal];
    _archiveBTN.titleLabel.font = [GM boldFontWithSize:14];
    _archiveBTN.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.5]; // IMPORTANT
    _archiveBTN.clipsToBounds = YES;
    _archiveBTN.layer.cornerRadius = 20;
    [_photoCard addSubview:_archiveBTN];

    // Right-side text stack
    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:17];
    _titleLabel.textColor = self.style.titleColor;
    _titleLabel.numberOfLines = 2;
    _line1 = [self metaLabel];
    [_line1.heightAnchor constraintEqualToConstant:22].active = YES;
    _line2 = [self metaLabel];
    //_line3 = [self metaLabel];
    _line4 = [self metaLabel];
    _line4.numberOfLines = 2;

    _rightStack = [[UIStackView alloc] initWithArrangedSubviews:@[_line1,_line2,_line4]];//,_line3
    _rightStack.translatesAutoresizingMaskIntoConstraints = NO;
    _rightStack.axis = UILayoutConstraintAxisVertical;
    _rightStack.alignment = UIStackViewAlignmentFill;
    _rightStack.spacing = 8;
    _rightStack.distribution = UIStackViewDistributionFillProportionally;
    [_card addSubview:_rightStack];
 
    
    // Floating buttons (Grid and Share)
    [self createTBTN];
 
    
    self.actionsView = [PPQuickActionsView new];
    self.actionsView.translatesAutoresizingMaskIntoConstraints = NO;
    [_card addSubview:self.actionsView];
    [_topView addSubview:_titleLabel];
    // Constraints
    CGFloat pad = 16.0;
    //CGFloat emptyCardHeight = 56 ;
    [NSLayoutConstraint activateConstraints:@[
        // Card container edges
        [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        
        
        [_topView.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:pad],
        [_topView.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-pad],
        
        [_TransactionBTN.trailingAnchor constraintEqualToAnchor:_topView.trailingAnchor constant:-4],
        [_TransactionBTN.centerYAnchor constraintEqualToAnchor:_topView.centerYAnchor constant:0],
        
        [_topView.topAnchor constraintEqualToAnchor:_card.topAnchor constant:pad],
        [_topView.heightAnchor constraintEqualToConstant:50],
         
        // Photo column (shadow container)
        [_photoShadowView.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:pad],
        [_photoShadowView.topAnchor constraintEqualToAnchor:_topView.bottomAnchor constant:pad],
        [_photoShadowView.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-pad],
        [_photoShadowView.widthAnchor constraintEqualToAnchor:_card.widthAnchor multiplier:0.35],

        // Photo card fills shadow container
        [_photoCard.leadingAnchor constraintEqualToAnchor:_photoShadowView.leadingAnchor],
        [_photoCard.trailingAnchor constraintEqualToAnchor:_photoShadowView.trailingAnchor],
        [_photoCard.topAnchor constraintEqualToAnchor:_photoShadowView.topAnchor],
        [_photoCard.bottomAnchor constraintEqualToAnchor:_photoShadowView.bottomAnchor],

        // Photo image fills photoCard
        [_photoView.topAnchor constraintEqualToAnchor:_photoCard.topAnchor],

        [_photoView.leadingAnchor constraintEqualToAnchor:_photoCard.leadingAnchor],
        [_photoView.trailingAnchor constraintEqualToAnchor:_photoCard.trailingAnchor],
        [_photoView.bottomAnchor constraintEqualToAnchor:_photoCard.bottomAnchor constant:-0],
        // Bottom card
        [self.actionsView.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-pad],
        [self.actionsView.leadingAnchor constraintEqualToAnchor:_photoCard.trailingAnchor constant:pad],
        [self.actionsView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor  constant:-pad],
        //[self.actionsView.heightAnchor constraintEqualToConstant:emptyCardHeight],
        
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_topView.leadingAnchor constant:pad],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_TransactionBTN.leadingAnchor constant:-pad],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_topView.centerYAnchor],

        

        // Bottom archive ribbon
        [_archiveBTN.leadingAnchor constraintEqualToAnchor:_photoCard.leadingAnchor constant:3],
        [_archiveBTN.trailingAnchor constraintEqualToAnchor:_photoCard.trailingAnchor constant:-3],
        [_archiveBTN.bottomAnchor constraintEqualToAnchor:_photoCard.bottomAnchor constant:-3],
        [_archiveBTN.heightAnchor constraintEqualToConstant:40],

        
        // Text stack to right of photo
        [_rightStack.leadingAnchor constraintEqualToAnchor:_photoCard.trailingAnchor constant:pad],
        [_rightStack.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-pad],
        [_rightStack.topAnchor constraintEqualToAnchor:_topView.bottomAnchor constant:18],

       
    ]];
    
    if (@available(iOS 18.0, *)) {
        //[_TransactionBTN.imageView addSymbolEffect: [[NSSymbolWiggleEffect effect] effectWithByLayer] options: [NSSymbolEffectOptions optionsWithRepeatBehavior:[NSSymbolEffectOptionsRepeatBehavior behaviorPeriodicWithDelay:5.0]]];
    } else {
        // Fallback on earlier versions
    }
    
    /*
     if(PPIOS26())
     {
         CALayer *glow = [CALayer layer];
         glow.name = @"optionsLayer";
         glow.frame = CGRectMake(0, 0, 44, 44);
         glow.backgroundColor = AppPrimaryClr.CGColor;
         glow.opacity = 0.5;
         glow.cornerRadius = 22;
         [_TransactionBTN.layer insertSublayer:glow atIndex:0];
         
         [_TransactionBTN.imageView addSymbolEffect: [[NSSymbolWiggleEffect effect] effectWithByLayer] options: [NSSymbolEffectOptions optionsWithRepeatBehavior:[NSSymbolEffectOptionsRepeatBehavior behaviorPeriodicWithDelay:4.0]]];
     }
     */
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    _card.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [Styling addLiquidGlassBorderToView:_photoCard cornerRadius:22];
}

#pragma mark - Layout (Gradient Sizing)

-(void)layoutSubviews {
    [super layoutSubviews];

    if (_card.layer.shadowPath == nil) {
        _card.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:_card.bounds
                                   cornerRadius:_card.layer.cornerRadius].CGPath;
    }

    if (_topView.layer.shadowPath == nil) {
        _topView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:_topView.bounds
                                   cornerRadius:_topView.layer.cornerRadius].CGPath;
    }

    _photoShadowView.layer.shadowPath =
    [UIBezierPath bezierPathWithRoundedRect:_photoShadowView.bounds
                               cornerRadius:_photoCard.layer.cornerRadius].CGPath;
    
    
}
#pragma mark - Actions

- (void)tapGrid {
    if (self.onTapGrid) self.onTapGrid();
    [[UIImpactFeedbackGenerator new] impactOccurred];
    NSLog(@"🔘 Grid tapped (collection cell)");
}
- (void)tapShare {
    if (self.onTapShare) self.onTapShare();
    [[UIImpactFeedbackGenerator new] impactOccurred];
    NSLog(@"🔘 Share tapped (collection cell)");
}

#pragma mark - RTL Support

- (void)applyRTL:(BOOL)rtl {
    UISemanticContentAttribute attr = rtl ? UISemanticContentAttributeForceRightToLeft
                                          : UISemanticContentAttributeForceLeftToRight;
    self.contentView.semanticContentAttribute = attr;
    _card.semanticContentAttribute = attr;
    _photoCard.semanticContentAttribute = attr;
    _rightStack.semanticContentAttribute = attr;
    NSTextAlignment a = rtl ? NSTextAlignmentRight : NSTextAlignmentLeft;
    _titleLabel.textAlignment = a;
    _line1.textAlignment = a;
    _line2.textAlignment = a;
    _line3.textAlignment = a;
    _line4.textAlignment = a;
 }

#pragma mark - Configure Cell
static inline BOOL PPHasValidTitle(NSString *title) {
    return (title.length > 0);
}
- (void)configureWithCard:(CardModel *)cardData
              placeholder:(UIImage * _Nullable)placeholder
                      RTL:(BOOL)rtl
             imageLoader:(PPImageLoader)loader
{
    // 1. Set model and appearance
    self.cardModel = cardData;
    
    // ========= Root menu =========
    self.transactionMenu =
    [UIMenu menuWithTitle:[self transactionMenuTitle]
                   image:nil
              identifier:nil
                 options:UIMenuOptionsDisplayInline
                 children:@[_shareOptionsMenu, _moreOptionsMenu]];
    _TransactionBTN.menu = self.transactionMenu;
    _TransactionBTN.showsMenuAsPrimaryAction = YES;
    
    self.loader = loader;
    [self applyRTL:rtl];
    _card.backgroundColor = self.style.cardBackground;
    _titleLabel.textColor  = self.style.titleColor;
    UIColor *meta = self.style.metaColor;
    _line1.textColor = _line2.textColor = _line3.textColor = _line4.textColor = meta;
    

    // 2. Setup quick actions (Sexual, Age, Share, More)
    [self addActionsViewForCard:cardData];

    // 3. Populate text fields
    _line1.text = [self formatLabel:kLang(@"RingID") value:cardData.RingID];
    _line2.text = [self formatLabel:kLang(@"Attribute") value:cardData.getBirdAttribute];
    _line3.text = [self formatLabel:kLang(@"Classification") value:cardData.ClassificationString];
    NSString *notes = [self safeValue:cardData.AdDescString].length > 0 ? [self safeValue:cardData.AdDescString] : kLang(@"_no_DescForCard");
    _line4.text = [self formatLabel:kLang(@"note") value:notes];
    _titleLabel.text = [self safeValue:cardData.CardTitle];

    // 4. Archive button state
    [self configureArchiveButtonWithCardData:cardData];

    // 5. Load image (asynchronously if needed)
    NSString *url = [self primaryImageURLForCard:cardData];
    self.currentImageURL = url;
    if (url.length && loader) {
        _photoView.image = placeholder;
        // The loader's 4th parameter expects a UIView*, not a completion block. Pass the photoView.
        loader(_photoView, url, placeholder, _photoView);
        // Ensure we still guard against stale URL after load is initiated
        if (![self.currentImageURL isEqualToString:url]) {
            return;
        }
        return;
    } else
    {
        _photoView.image = [cardData.CardLocation isEqualToString:@"new_child"] ? [UIImage imageNamed:@"placeholderCK"] : placeholder;
    }
       

     
    [self.contentView setNeedsLayout];
    [self.contentView layoutIfNeeded];
}

- (NSString * _Nullable)primaryImageURLForCard:(CardModel *)cardData {
    if (cardData.imagesUrls.count == 0) {
        // Default placeholder image
        return nil;
    }
    if (cardData.FilesArray.count > 0) {
        for (FileModel *file in cardData.FilesArray) {
            if (file.FileType == 0) return file.FileUrl;
        }
        return cardData.FilesArray.firstObject.FileUrl;
    }
    return nil;
}

- (void)configureArchiveButtonWithCardData:(CardModel *)cardData {
    NSString *currentUserID = UserManager.sharedManager.currentUser.ID;
    
    if ([cardData.loanForUser isEqualToString:currentUserID]) {
        [_archiveBTN setTitle:kLang(@"LoanCard") forState:UIControlStateNormal];
        _archiveBTN.enabled = NO;
         return;
    }
    _archiveBTN.enabled = YES;
     if ([cardData cardSection] == CardSectionCage || [cardData cardSection] == CardSectionNewChild) {
        // Show Cage/Box info
         [_archiveBTN setTitle:[NSString stringWithFormat:@"%@: %@", kLang(@"Box"), PPSafeString(cardData.CageID)] forState:UIControlStateNormal];

          for (CageModel *cage in AppData.caGeDocs) {
            if ([cage.ID isEqualToString:cardData.CageID]) {
                [_archiveBTN setTitle:[NSString stringWithFormat:@"%@: %@", kLang(@"Box"), PPSafeString(cage.CageName)] forState:UIControlStateNormal];
                break;
            }
        }
        self.isActive = YES;
    }
     else if ([cardData cardSection] == CardSectionArchive ||
              cardData.masterArchiveID.length > 0) {

         ArchiveModel *archive =
         [[AppData.UserArchivesDocs filteredArrayUsingPredicate:
           [NSPredicate predicateWithFormat:@"SELF.ID == %@", cardData.masterArchiveID]]
          firstObject];

         NSString *archiveTitle = archive.archiveTitle;

         // 🔒 HIDE if title missing or empty
         if (!PPHasValidTitle(archiveTitle)) {
             _archiveBTN.alpha = 0.0;
             self.haveArchive = NO;
             self.isActive = NO;
             return;
         }

         // ✅ SHOW normally
         _archiveBTN.alpha = 1.0;

         [_archiveBTN setTitle:[NSString stringWithFormat:@"%@: %@", kLang(@"Archive"), PPSafeString(archiveTitle)] forState:UIControlStateNormal];
         self.archiveModel = archive;
         self.haveArchive = YES;
         self.isActive = YES;
     }
    else {
        [_archiveBTN setTitle:[NSString stringWithFormat:@"%@: %@", kLang(@"Archive"), kLang(@"unDefind")] forState:UIControlStateNormal];
        self.haveArchive = NO;
    }
}

 

- (NSString *)formatLabel:(NSString *)label value:(NSString *)value {
    return [NSString stringWithFormat:@"%@ : %@", label, [self safeValue:value]];
}

- (NSString *)safeValue:(NSString *)value {
    if (!value || [value isKindOfClass:[NSNull class]]) return @"";
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed.lowercaseString isEqualToString:@"no_value"] ||
        [trimmed.lowercaseString containsString:@"null"]) return @"";
    return trimmed;
}

#pragma mark - Quick Actions Setup

- (void)addActionsViewForCard:(CardModel *)cardModel {
    // Hide floating buttons by default
    
/*
 
 // Calculate age info from birth date
 NSDictionary *info = [PPFunc ageInfoFromBirthday:cardModel.BirthDate adultHood:18];
 BOOL haveFather = NO, haveMother = NO;
 NSString *fatherVal = kLang(@"notFound"), *motherVal = kLang(@"notFound");

 if (![cardModel.FatherRingID isEqualToString:@"no_value"]) {
     NSString *FRingID = [[[AppData.AllCardsDocs filteredArrayUsingPredicate:
         [NSPredicate predicateWithFormat:@"SELF.ID == %@", cardModel.FatherRingID]] firstObject] RingID];
     if (FRingID.length > 0)  { fatherVal = FRingID; haveFather = YES; }
 }
 if (![cardModel.MotherRingID isEqualToString:@"no_value"]) {
     NSString *MRingID = [[[AppData.AllCardsDocs filteredArrayUsingPredicate:
         [NSPredicate predicateWithFormat:@"SELF.ID == %@", cardModel.MotherRingID]] firstObject] RingID];
     if (MRingID.length > 0)  { motherVal = MRingID; haveMother = YES; }
 }
 */
 
    /*
     // More submenu items (archive, edit, delete, QR)
     NSArray *moreMenuItems = @[
         @{ @"title": kLang(@"archive"),  @"icon": @"archivebox", @"handler": ^{
             [self.delegate archiveCardData:cardModel cellIndexPath:self.cellIndexPath];
         }},
         @{ @"title": kLang(@"editCard"), @"icon": @"pencil", @"handler": ^{
             [self.delegate deleteEditOptions:0 CardData:cardModel];
         }},
         @{ @"title": kLang(@"deleteCard"),@"icon": @"trash", @"handler": ^{
             [self.delegate deleteEditOptions:1 CardData:cardModel];
         }},
         @{ @"title": kLang(@"craeteQrCode"),@"icon": @"barcode.viewfinder", @"handler": ^{
             [self.delegate deleteEditOptions:2 CardData:cardModel];
         }}
     ];
     UIMenu *moreOptionsMenu = [PPButtonFactory menuWithItems:moreMenuItems primaryHandler:nil];
     */


    // (Optional) DNA info not used in UI; remove or implement as needed.
    
    // Configure the quick action items
    [self.actionsView setActions:@[
        [PPQuickActionItem itemWithTitleKey:kLang(@"Sexual")
                                subTitleKey:cardModel.SexualTXT
                                   iconName:nil //@"lesbian"//(cardModel.Sexual == 1 ? @"maleColored" : @"femaleColored")
                              iconNameOnTap:nil
                                      width:0
                                  configFor:ConfigForCardCell
                                       menu:nil
                                    enabled:YES
                                    handler:^(UIView *sender) {
            if (cardModel.Dna.length > 0 && ![cardModel.Dna isEqualToString:@"no_value"]) {
                // Show DNA details if available
            } else {
                [self showTip:PPSafeString(kLang(@"NoDnaImage")) OnView:sender];
            }
        }],
        [PPQuickActionItem itemWithTitleKey:kLang(@"Age")
                                subTitleKey:self.cardModel.ageInfo.ageString
                                   iconName:nil
                              iconNameOnTap:nil
                                      width:0
                                  configFor:ConfigForCardCell
                                       menu:nil
                                    enabled:YES
                                    handler:^(UIView *sender) {
            NSString *birthDateStr = [GM formatDateFromDate:cardModel.BirthDate];
            [self showTip:[NSString stringWithFormat:@"%@: %@", kLang(@"BirthDate"), birthDateStr] OnView:sender];
        }]
    ]];
}
/*
 ,,
 [PPQuickActionItem itemWithTitleKey:nil
                         subTitleKey:nil
                            iconName:@"ellipsis"
                       iconNameOnTap:@"ellipsis"
                               width:0
                           configFor:ConfigForCardCell
                                menu:moreOptionsMenu
                             enabled:YES
                             handler:nil]
 [PPQuickActionItem itemWithTitleKey:kLang(@"share")
                         subTitleKey:kLang(@"share")
                            iconName:@"square.and.arrow.up"
                       iconNameOnTap:@"square.and.arrow.up"
                               width:0
                           configFor:ConfigForCardCell
                                menu:shareOptionsMenu
                             enabled:YES
                             handler:nil]
 */
- (void)showTip:(NSString *)text OnView:(UIView *)targetView {
    // Ensure previous tip is dismissed
    if (self.tipView) {
        [self.tipView dismissWithCompletion:^{}];
        //self.tipView = nil;
    }
    // Validate text
    NSString *message = (text.length > 0 ? text : @"  ");
    // Configure tip preferences
    ZMJPreferences *preferences = [ZMJPreferences new];
    preferences.drawing.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.9];
    preferences.drawing.foregroundColor = AppForgroundColr;
    preferences.drawing.textAlignment = NSTextAlignmentCenter;
    preferences.drawing.font = [GM MidFontWithSize:16];
    preferences.drawing.cornerRadius = 16;
    preferences.drawing.arrowPosition = ZMJArrowPosition_bottom;
    preferences.drawing.shadowColor = [AppShadowClr colorWithAlphaComponent:0.2];
    preferences.animating.showInitialAlpha = 0;
    preferences.animating.showDuration = 0.6;
    preferences.animating.dismissDuration = 0.6;

    // Show tip
    self.tipView = [[ZMJTipView alloc] initWithText:message preferences:preferences delegate:nil];
    [self.tipView showAnimated:YES forView:targetView withinSuperview:self.contentView];

    // Auto-dismiss
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tipView dismissWithCompletion:^{}];
        //self.tipView = nil;
    });
    NSLog(@"💬 [showTip] %@ → %@", targetView, message);
}

@end

































static inline UIButton *PPMakeRoundIconButton(NSString *systemName, UIColor *fill, UIColor *tint) {
    UIButton *b = [PPButtonHelper createButtonWithSystemName:systemName pointSize:16];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    b.backgroundColor = fill;
    b.tintColor = AppForgroundColr;
    b.layer.cornerRadius = 16.0;
    b.clipsToBounds = YES;
    b.contentEdgeInsets = UIEdgeInsetsMake(8, 8, 8, 8);
    [NSLayoutConstraint activateConstraints:@[
        [b.widthAnchor constraintEqualToConstant:32],
        [b.heightAnchor constraintEqualToConstant:32],
    ]];
    return b;
}
