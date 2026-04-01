//
//  AKPickerView.m
//  AKPickerViewSample
//
//  Created by Akio Yasui on 3/29/14.
//  Copyright (c) 2014 Akio Yasui. All rights reserved.
//

#import "AKPickerView.h"

#import <Availability.h>

@class AKCollectionViewLayout;

@protocol AKCollectionViewLayoutDelegate <NSObject>
- (AKPickerViewStyle)pickerViewStyleForCollectionViewLayout:(AKCollectionViewLayout *)layout;
@end

@interface AKCollectionViewCell : UICollectionViewCell
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIButton *btn;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIFont *highlightedFont;
@end

@interface AKCollectionViewLayout : UICollectionViewFlowLayout
@property (nonatomic, assign) id <AKCollectionViewLayoutDelegate> delegate;
@end

@interface AKPickerViewDelegateIntercepter : NSObject <UICollectionViewDelegate>
@property (nonatomic, weak) AKPickerView *pickerView;
@property (nonatomic, weak) id <UIScrollViewDelegate> delegate;
@end

@interface AKPickerView () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, AKCollectionViewLayoutDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, assign) NSUInteger selectedItem;
@property (nonatomic, strong) AKPickerViewDelegateIntercepter *intercepter;
- (CGFloat)offsetForItem:(NSUInteger)item;
- (void)didEndScrolling;
- (CGSize)sizeForString:(NSString *)string;

@property (nonatomic, assign) NSInteger selectedCategoryIndex;

@end

@implementation AKPickerView

- (void)initialize
{
	self.font = self.font ?: [UIFont fontWithName:@"HelveticaNeue-Light" size:20];
	self.highlightedFont = self.highlightedFont ?: [UIFont fontWithName:@"HelveticaNeue" size:20];
	self.textColor = self.textColor ?: [UIColor darkGrayColor];
	self.highlightedTextColor = self.highlightedTextColor ?: [UIColor blackColor];
	self.pickerViewStyle = self.pickerViewStyle ?: AKPickerViewStyle3D;
	self.maskDisabled = self.maskDisabled;

	[self.collectionView removeFromSuperview];
	self.collectionView = [[UICollectionView alloc] initWithFrame:self.bounds
											 collectionViewLayout:[self collectionViewLayout]];
	self.collectionView.showsHorizontalScrollIndicator = NO;
	self.collectionView.backgroundColor = [UIColor clearColor];
	self.collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
	self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.collectionView.dataSource = self;
	[self.collectionView registerClass:[AKCollectionViewCell class]
			forCellWithReuseIdentifier:NSStringFromClass([AKCollectionViewCell class])];
	[self addSubview:self.collectionView];

	self.intercepter = [AKPickerViewDelegateIntercepter new];
	self.intercepter.pickerView = self;
	self.intercepter.delegate = self.delegate;
	self.collectionView.delegate = self.intercepter;
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self initialize];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self initialize];
	}
	return self;
}

- (void)dealloc
{
	self.collectionView.delegate = nil;
}

#pragma mark -

- (void)layoutSubviews
{
	[super layoutSubviews];
	self.collectionView.collectionViewLayout = [self collectionViewLayout];
	if ([self.dataSource numberOfItemsInPickerView:self]) {
		[self scrollToItem:self.selectedItem animated:NO];
	}
	self.collectionView.layer.mask.frame = self.collectionView.bounds;
}

- (CGSize)intrinsicContentSize
{
	return CGSizeMake(UIViewNoIntrinsicMetric, MAX(self.font.lineHeight, self.highlightedFont.lineHeight));
}

- (CGPoint)contentOffset
{
	return self.collectionView.contentOffset;
}

#pragma mark -

- (void)setDelegate:(id<AKPickerViewDelegate>)delegate
{
	if (![_delegate isEqual:delegate]) {
		_delegate = delegate;
		self.intercepter.delegate = delegate;
	}
}

- (void)setFisheyeFactor:(CGFloat)fisheyeFactor
{
	_fisheyeFactor = fisheyeFactor;

	CATransform3D transform = CATransform3DIdentity;
	transform.m34 = -MAX(MIN(self.fisheyeFactor, 1.0), 0.0);
	self.collectionView.layer.sublayerTransform = transform;
}

- (void)setMaskDisabled:(BOOL)maskDisabled
{
	_maskDisabled = maskDisabled;

	self.collectionView.layer.mask = maskDisabled ? nil : ({
		CAGradientLayer *maskLayer = [CAGradientLayer layer];
		maskLayer.frame = self.collectionView.bounds;
		maskLayer.colors = @[(id)[[UIColor clearColor] CGColor],
							 (id)[[UIColor blackColor] CGColor],
							 (id)[[UIColor blackColor] CGColor],
							 (id)[[UIColor clearColor] CGColor],];
		maskLayer.locations = @[@0.0, @0.33, @0.66, @1.0];
		maskLayer.startPoint = CGPointMake(0.0, 0.0);
		maskLayer.endPoint = CGPointMake(1.0, 0.0);
		maskLayer;
	});
}

#pragma mark -

- (AKCollectionViewLayout *)collectionViewLayout
{
	AKCollectionViewLayout *layout = [AKCollectionViewLayout new];
	layout.delegate = self;
	return layout;
}

- (CGSize)sizeForString:(NSString *)string
{
	CGSize size;
	CGSize highlightedSize;
#ifdef __IPHONE_7_0
	size = [string sizeWithAttributes:@{NSFontAttributeName: self.font}];
	highlightedSize = [string sizeWithAttributes:@{NSFontAttributeName: self.highlightedFont}];
#else
	size = [string sizeWithFont:self.font];
	highlightedSize = [string sizeWithFont:self.highlightedFont];
#endif
	return CGSizeMake(ceilf(MAX(size.width, highlightedSize.width)), ceilf(MAX(size.height, highlightedSize.height)));
}

#pragma mark -

- (void)reloadData
{
	[self invalidateIntrinsicContentSize];
	[self.collectionView.collectionViewLayout invalidateLayout];
	[self.collectionView reloadData];
	if ([self.dataSource numberOfItemsInPickerView:self]) {
		[self selectItem:self.selectedItem animated:NO notifySelection:NO];
	}
}

- (CGFloat)offsetForItem:(NSUInteger)item
{
	NSAssert(item < [self.collectionView numberOfItemsInSection:0],
			 @"item out of range; '%lu' passed, but the maximum is '%lu'", item, [self.collectionView numberOfItemsInSection:0]);

	CGFloat offset = 0.0;

	for (NSInteger i = 0; i < item; i++) {
		NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
		CGSize cellSize = [self collectionView:self.collectionView layout:self.collectionView.collectionViewLayout sizeForItemAtIndexPath:indexPath];
		offset += cellSize.width;
	}

	NSIndexPath *firstIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
	CGSize firstSize = [self collectionView:self.collectionView layout:self.collectionView.collectionViewLayout sizeForItemAtIndexPath:firstIndexPath];
	NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForItem:item inSection:0];
	CGSize selectedSize = [self collectionView:self.collectionView layout:self.collectionView.collectionViewLayout sizeForItemAtIndexPath:selectedIndexPath];
	offset -= (firstSize.width - selectedSize.width) / 2;

	return offset;
}

- (void)scrollToItem:(NSUInteger)item animated:(BOOL)animated
{
	switch (self.pickerViewStyle) {
		case AKPickerViewStyleFlat: {
			[self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:item inSection:0]
										atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
												animated:animated];
			break;
		}
		case AKPickerViewStyle3D: {
			[self.collectionView setContentOffset:CGPointMake([self offsetForItem:item], self.collectionView.contentOffset.y)
										 animated:animated];
			break;
		}
		default: break;
	}
}

- (void)selectItem:(NSUInteger)item animated:(BOOL)animated
{
	[self selectItem:item animated:animated notifySelection:YES];
}

- (void)selectItem:(NSUInteger)item animated:(BOOL)animated notifySelection:(BOOL)notifySelection
{
	[self.collectionView selectItemAtIndexPath:[NSIndexPath indexPathForItem:item inSection:0]
									  animated:animated
								scrollPosition:UICollectionViewScrollPositionNone];
	[self scrollToItem:item animated:animated];

	self.selectedItem = item;

	if (notifySelection &&
		[self.delegate respondsToSelector:@selector(pickerView:didSelectItem:)])
		[self.delegate pickerView:self didSelectItem:item];
}

- (void)didEndScrolling
{
	switch (self.pickerViewStyle) {
		case AKPickerViewStyleFlat: {
			CGPoint center = [self convertPoint:self.collectionView.center toView:self.collectionView];
			NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:center];
			[self selectItem:indexPath.item animated:YES];
			break;
		}
		case AKPickerViewStyle3D: {
			if ([self.dataSource numberOfItemsInPickerView:self]) {
				for (NSUInteger i = 0; i < [self collectionView:self.collectionView numberOfItemsInSection:0]; i++) {
					NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
					AKCollectionViewCell *cell = (AKCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
					if ([self offsetForItem:i] + cell.bounds.size.width / 2 > self.collectionView.contentOffset.x) {
						[self selectItem:i animated:YES];
						break;
					}
				}
			}
			break;
		}
		default: break;
	}
}

#pragma mark -

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
	return ([self.dataSource numberOfItemsInPickerView:self] > 0);
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return [self.dataSource numberOfItemsInPickerView:self];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	AKCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([AKCollectionViewCell class])
																		   forIndexPath:indexPath];

    
        
        
        
	if ([self.dataSource respondsToSelector:@selector(pickerView:titleForItem:)]) {
		NSString *title = [self.dataSource pickerView:self titleForItem:indexPath.item];
		cell.label.text = title;
		cell.label.textColor = self.textColor;
		cell.label.highlightedTextColor = self.highlightedTextColor;
		cell.label.font = self.font;
		cell.font = self.font;
		cell.highlightedFont = self.highlightedFont;
		cell.label.bounds = (CGRect){CGPointZero, [self sizeForString:title]};
		if ([self.delegate respondsToSelector:@selector(pickerView:marginForItem:)]) {
			CGSize margin = [self.delegate pickerView:self marginForItem:indexPath.item];
			cell.label.frame = CGRectInset(cell.label.frame, -margin.width, -margin.height);
		}
		if ([self.delegate respondsToSelector:@selector(pickerView:configureLabel:forItem:)]) {
			[self.delegate pickerView:self configureLabel:cell.label forItem:indexPath.item];
		}
	} else if ([self.dataSource respondsToSelector:@selector(pickerView:buttonForItem:)]) {
        // ✅ NEW CONDITION: Support custom button instead of label/image
        NSString *buttonTitle = [self.dataSource pickerView:self buttonForItem:indexPath.item];
        if (!cell.btn) {
            cell.btn = [UIButton buttonWithType:UIButtonTypeSystem];
            cell.btn.frame = cell.contentView.bounds;
            cell.btn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [cell.contentView addSubview:cell.btn];
        }

        BOOL isSelected = (indexPath.item == self.selectedCategoryIndex);
        [self configureCategoryButton:cell.btn
                              forKind:PPMainKindsArray[indexPath.item]
                             selected:isSelected
                         animatedCell:cell];

        cell.btn.titleLabel.font = self.font;
        cell.btn.tag =  indexPath.item;
        
        
        
        [cell.btn removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        //[button addTarget:self action:@selector(categoryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        
        
        [cell.btn addTarget:self action:@selector(selectedButton:) forControlEvents:UIControlEventAllEvents];
       

    }else if ([self.dataSource respondsToSelector:@selector(pickerView:imageForItem:)]) {
		cell.imageView.image = [self.dataSource pickerView:self imageForItem:indexPath.item];
	}
	cell.selected = (indexPath.item == self.selectedItem);

	return cell;
}

#pragma mark - Button Configuration Helper

- (void)configureCategoryButton:(UIButton *)button
                        forKind:(MainKindsModel *)kind
                       selected:(BOOL)isSelected
                   animatedCell:(UICollectionViewCell *)cell {
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        
        
        config.title = kind.KindName;
        config.imagePadding = 6;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.imagePlacement = NSDirectionalRectEdgeTop;
         // config.image = [UIImage symbolicImageNamed:kind.KindImageNamed weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleDefault pointSize:16];;

        // Colors
        UIColor *bgColor = isSelected ? AppPrimaryClr : UIColor.systemGray6Color;
        UIColor *fgColor = isSelected ? UIColor.whiteColor : AppSecondaryTextClr;
        config.baseBackgroundColor = bgColor;
        config.baseForegroundColor = fgColor;

        // Font styling
        UIFont *font = isSelected ? [GM boldFontWithSize:17] : [GM MidFontWithSize:16];
        config.attributedTitle = [[NSAttributedString alloc] initWithString:kind.KindName
                                                                 attributes:@{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: fgColor
        }];

        // Assign
        button.configuration = config;

        // Animate selection highlight
        [UIView transitionWithView:cell.contentView
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            cell.contentView.layer.shadowOpacity = isSelected ? 0.3 : 0.0;
            cell.contentView.layer.shadowRadius = isSelected ? 8 : 0;
            cell.contentView.layer.shadowOffset = CGSizeMake(0, isSelected ? 4 : 0);
        } completion:nil];
        
        
        [button setImage:[UIImage symbolicImageNamed:kind.KindImageNamed weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleDefault pointSize:16] forState:UIControlStateNormal];

    } else {
        // iOS 14 fallback
        [button setTitle:kind.KindName forState:UIControlStateNormal];
        [button setImage:[UIImage imageNamed:kind.KindImageNamed] forState:UIControlStateNormal];
        button.tintColor = AppForgroundColr;
        button.backgroundColor = isSelected ? AppPrimaryClr : UIColor.systemGray5Color;
        button.layer.cornerRadius = 10;
        button.titleLabel.font = [GM MidFontWithSize:16];
    }
}


-(void)selectedButton:(UIButton *)sender{
    self.selectedCategoryIndex = sender.tag;
    [self selectItem:sender.tag animated:YES];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	CGSize size = CGSizeMake(self.interitemSpacing, collectionView.bounds.size.height);
	if ([self.dataSource respondsToSelector:@selector(pickerView:titleForItem:)]) {
		NSString *title = [self.dataSource pickerView:self titleForItem:indexPath.item];
		size.width += [self sizeForString:title].width;
		if ([self.delegate respondsToSelector:@selector(pickerView:marginForItem:)]) {
			CGSize margin = [self.delegate pickerView:self marginForItem:indexPath.item];
			size.width += margin.width * 2;
		}
    } else if ([self.dataSource respondsToSelector:@selector(pickerView:buttonForItem:)]) {
        UIButton *btnTitle = [self.dataSource pickerView:self buttonForItem:indexPath.item];
        size.width += btnTitle.hx_w;
        size.height = collectionView.hx_h;
    } else if ([self.dataSource respondsToSelector:@selector(pickerView:imageForItem:)]) {
		UIImage *image = [self.dataSource pickerView:self imageForItem:indexPath.item];
		size.width += image.size.width;
	}
	return size;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
	return 10.0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
	return 10.0;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
	NSInteger number = [self collectionView:collectionView numberOfItemsInSection:section];
	NSIndexPath *firstIndexPath = [NSIndexPath indexPathForItem:0 inSection:section];
	CGSize firstSize = [self collectionView:collectionView layout:collectionViewLayout sizeForItemAtIndexPath:firstIndexPath];
	NSIndexPath *lastIndexPath = [NSIndexPath indexPathForItem:number - 1 inSection:section];
	CGSize lastSize = [self collectionView:collectionView layout:collectionViewLayout sizeForItemAtIndexPath:lastIndexPath];
	return UIEdgeInsetsMake(0, (collectionView.bounds.size.width - firstSize.width) / 2,
							0, (collectionView.bounds.size.width - lastSize.width) / 2);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	[self selectItem:indexPath.item animated:YES];
}

#pragma mark -

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	if ([self.delegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)])
		[self.delegate scrollViewDidEndDecelerating:scrollView];

	if (!scrollView.isTracking) [self didEndScrolling];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if ([self.delegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)])
		[self.delegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];

	if (!decelerate) [self didEndScrolling];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	if ([self.delegate respondsToSelector:@selector(scrollViewDidScroll:)])
		[self.delegate scrollViewDidScroll:scrollView];

	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue
					 forKey:kCATransactionDisableActions];
	self.collectionView.layer.mask.frame = self.collectionView.bounds;
	[CATransaction commit];
}

#pragma mark -

- (AKPickerViewStyle)pickerViewStyleForCollectionViewLayout:(AKCollectionViewLayout *)layout
{
	return self.pickerViewStyle;
}

@end

@implementation AKCollectionViewCell

- (void)initialize
{
	self.layer.doubleSided = NO;
	self.label = [[UILabel alloc] initWithFrame:self.contentView.bounds];
	self.label.backgroundColor = [UIColor clearColor];
	self.label.textAlignment = NSTextAlignmentCenter;
	self.label.textColor = [UIColor grayColor];
	self.label.numberOfLines = 1;
	self.label.lineBreakMode = NSLineBreakByTruncatingTail;
	self.label.highlightedTextColor = [UIColor blackColor];
	self.label.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
	self.label.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin |
								   UIViewAutoresizingFlexibleLeftMargin |
								   UIViewAutoresizingFlexibleBottomMargin |
								   UIViewAutoresizingFlexibleRightMargin);
	[self.contentView addSubview:self.label];

	self.imageView = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
	self.imageView.backgroundColor = [UIColor clearColor];
	self.imageView.contentMode = UIViewContentModeCenter;
	self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.contentView addSubview:self.imageView];
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self initialize];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self initialize];
	}
	return self;
}

- (void)setSelected:(BOOL)selected
{
	[super setSelected:selected];

	CATransition *transition = [CATransition animation];
	[transition setType:kCATransitionFade];
	[transition setDuration:0.15];
	[self.label.layer addAnimation:transition forKey:nil];

	self.label.font = self.selected ? self.highlightedFont : self.font;
}

@end

@interface AKCollectionViewLayout ()
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat midX;
@property (nonatomic, assign) CGFloat maxAngle;
@end

@implementation AKCollectionViewLayout

- (id)init
{
	self = [super init];
	if (self) {
		self.sectionInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
		self.scrollDirection = UICollectionViewScrollDirectionHorizontal;
		self.minimumLineSpacing = 0.0;
	}
	return self;
}

- (void)prepareLayout
{
	CGRect visibleRect = (CGRect){self.collectionView.contentOffset, self.collectionView.bounds.size};
	self.midX = CGRectGetMidX(visibleRect);
	self.width = CGRectGetWidth(visibleRect) / 2;
	self.maxAngle = M_PI_2;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
	return YES;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
	UICollectionViewLayoutAttributes *attributes = [[super layoutAttributesForItemAtIndexPath:indexPath] copy];
	switch ([self.delegate pickerViewStyleForCollectionViewLayout:self]) {
		case AKPickerViewStyleFlat: {
			return attributes; break;
		}
		case AKPickerViewStyle3D: {
			CGFloat distance = CGRectGetMidX(attributes.frame) - self.midX;
			CGFloat currentAngle = self.maxAngle * distance / self.width / M_PI_2;
			CATransform3D transform = CATransform3DIdentity;
			transform = CATransform3DTranslate(transform, -distance, 0, -self.width);
			transform = CATransform3DRotate(transform, currentAngle, 0, 1, 0);
			transform = CATransform3DTranslate(transform, 0, 0, self.width);
			attributes.transform3D = transform;
			attributes.alpha = (ABS(currentAngle) < self.maxAngle);
			return attributes; break;
		}
		default: return nil; break;
	}
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
	switch ([self.delegate pickerViewStyleForCollectionViewLayout:self]) {
		case AKPickerViewStyleFlat: {
			return [super layoutAttributesForElementsInRect:rect];
			break;
		}
		case AKPickerViewStyle3D: {
			NSMutableArray *attributes = [NSMutableArray array];
			if ([self.collectionView numberOfSections]) {
				for (NSInteger i = 0; i < [self.collectionView numberOfItemsInSection:0]; i++) {
					NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
					[attributes addObject:[self layoutAttributesForItemAtIndexPath:indexPath]];
				}
			}
			return attributes;
			break;
		}
		default: return nil; break;
	}
}

@end

@implementation AKPickerViewDelegateIntercepter

- (id)forwardingTargetForSelector:(SEL)aSelector
{
	if ([self.pickerView respondsToSelector:aSelector]) return self.pickerView;
	if ([self.delegate respondsToSelector:aSelector]) return self.delegate;
	return [super forwardingTargetForSelector:aSelector];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if ([self.pickerView respondsToSelector:aSelector]) return YES;
	if ([self.delegate respondsToSelector:aSelector]) return YES;
	return [super respondsToSelector:aSelector];
}

@end
