#import "PPUniversalCell.h"

BOOL PPUniversalCellShowsCTA = YES;

BOOL PPUniversalCellGetShowsCTA(void) {
    return PPUniversalCellShowsCTA;
}

void PPUniversalCellSetShowsCTA(BOOL showsCTA) {
    PPUniversalCellShowsCTA = showsCTA;
}

#pragma mark - PPUniversalGradientView

@implementation PPUniversalGradientView

+ (Class)layerClass
{
    return [CAGradientLayer class];
}

- (instancetype)init
{
    self = [super initWithFrame:CGRectZero];
    if (!self) {
        return nil;
    }

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = YES;
    self.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return self;
}

- (void)applyContextPaletteForContext:(PPCellContext)context
{
    self.backgroundColor = [UIColor clearColor];
    CAGradientLayer *layer = (CAGradientLayer *)self.layer;
    layer.colors = @[(id)[UIColor clearColor].CGColor, (id)[UIColor clearColor].CGColor];
}

@end

#pragma mark - PPUniversalCell (Registration / Dequeue)

@implementation PPUniversalCell

@synthesize delegate = _delegate;
@synthesize indexPath = _indexPath;
@synthesize context = _context;
@synthesize layoutMode = _layoutMode;
@synthesize discountStyle = _discountStyle;
@synthesize onTap = _onTap;
@synthesize quantity = _quantity;
@synthesize hideTopBadge = _hideTopBadge;
@synthesize showCTA = _showCTA;
@synthesize forceShowsOwnerMenuButton = _forceShowsOwnerMenuButton;
@synthesize showsSubtitle = _showsSubtitle;
@synthesize dataViewPresentation = _dataViewPresentation;
@synthesize userBordersV2 = _userBordersV2;
@synthesize imageView = _imageView;
@synthesize imageContainer = _imageContainer;

+ (NSString *)reuseIdentifier
{
    return @"PPUniversalCell";
}

+ (void)pp_registerInCollectionView:(UICollectionView *)collectionView
{
    Class cellClass = NSClassFromString(@"PPUniversalCardHostingCell");
    if (!cellClass) {
        cellClass = NSClassFromString(@"Pure_Pets.PPUniversalCardHostingCell");
    }
    if (!cellClass) {
        cellClass = self;
    }
    [collectionView registerClass:cellClass
       forCellWithReuseIdentifier:[self reuseIdentifier]];
}

+ (id)pp_dequeueFromCollectionView:(UICollectionView *)collectionView
                         indexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:[self reuseIdentifier]
                                                    forIndexPath:indexPath];
}

+ (BOOL)pp_isUniversalCell:(UICollectionViewCell *)cell
{
    if ([cell isKindOfClass:[PPUniversalCell class]]) return YES;
    Class swiftCell = NSClassFromString(@"PPUniversalCardHostingCell");
    if (!swiftCell) {
        swiftCell = NSClassFromString(@"Pure_Pets.PPUniversalCardHostingCell");
    }
    if (swiftCell && [cell isKindOfClass:swiftCell]) return YES;
    return NO;
}

- (void)setQuantity:(NSInteger)quantity animated:(BOOL)animated
{
    _quantity = quantity;
}

- (void)collapseStepper:(BOOL)animated
{
}

- (void)refreshThemeAppearance
{
}

- (void)stopMediaPlayback
{
}

- (void)applyViewModel:(PPUniversalCellViewModel *)vm
               context:(PPCellContext)context
            layoutMode:(PPManagerCellLayoutMode)layout
          discountMode:(PPDiscountStyle)discountStyle
           imageLoader:(PPImageLoader)loader
{
    _context = context;
    _layoutMode = layout;
    _discountStyle = discountStyle;
    if (vm) {
        _indexPath = vm.indexPath;
    }
}

- (UIImageView *)imageView
{
    if (!_imageView) {
        _imageView = [[UIImageView alloc] init];
    }
    return _imageView;
}

- (PPUniversalGradientView *)imageContainer
{
    if (!_imageContainer) {
        _imageContainer = [[PPUniversalGradientView alloc] init];
    }
    return _imageContainer;
}

@end
