//
//  RoundedCorners.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 17/03/2025.
//

#import "RoundedCorners.h"

@implementation UIButton (PJR)

- (void)roundCornersWithTopLeft:(CGFloat)topLeft topRight:(CGFloat)topRight bottomLeft:(CGFloat)bottomLeft bottomRight:(CGFloat)bottomRight {
    
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                   byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight | UIRectCornerBottomLeft | UIRectCornerBottomRight)
                                                         cornerRadii:CGSizeMake(topLeft, topLeft)]; // Start with topLeft radius

    // Modify the path to handle different radii for each corner
    if (topRight != topLeft) {
        UIBezierPath *topRightPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       byRoundingCorners:UIRectCornerTopRight
                                                             cornerRadii:CGSizeMake(topRight, topRight)];
        [maskPath appendPath:topRightPath];
    }

    if (bottomLeft != topLeft) {
        UIBezierPath *bottomLeftPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       byRoundingCorners:UIRectCornerBottomLeft
                                                             cornerRadii:CGSizeMake(bottomLeft, bottomLeft)];
        [maskPath appendPath:bottomLeftPath];
    }

    if (bottomRight != topLeft) {
        UIBezierPath *bottomRightPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       byRoundingCorners:UIRectCornerBottomRight
                                                             cornerRadii:CGSizeMake(bottomRight, bottomRight)];
        [maskPath appendPath:bottomRightPath];
    }

    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.bounds;
    maskLayer.path = maskPath.CGPath;

    self.layer.mask = maskLayer;
}

@end
