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

@end
