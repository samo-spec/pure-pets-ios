//
//  PPModernAvatarRenderer.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//


#import "PPModernAvatarRenderer.h"

@implementation PPModernAvatarRenderer

#pragma mark - Public

+ (UIImage *)avatarImageForName:(NSString *)displayName size:(CGFloat)size {
    return [self avatarImageForName:displayName size:size style:PPModernAvatarStyleGlass];
}

+ (UIImage *)avatarImageForName:(NSString *)displayName
                           size:(CGFloat)size
                          style:(PPModernAvatarStyle)style {
    
    CGFloat safeSize = MAX(36.0, size);
    NSString *initials = [self initialsForDisplayName:displayName];
    NSArray *colors = [self paletteForSeed:(displayName ?: @"?")];
    
    UIGraphicsImageRenderer *renderer =
    [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(safeSize, safeSize)];
    
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        
        CGContextRef ctx = context.CGContext;
        CGRect rect = CGRectMake(0, 0, safeSize, safeSize);
        CGFloat radius = safeSize * 0.34;
        
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
        [path addClip];
        
        // Gradient
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        NSArray *cgColors = @[
            (__bridge id)[colors[0] CGColor],
            (__bridge id)[colors[1] CGColor],
            (__bridge id)[colors[2] CGColor]
        ];
        
        CGFloat locs[] = {0.0, 0.6, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)cgColors, locs);
        
        CGContextDrawLinearGradient(ctx, gradient,
                                    CGPointMake(0, 0),
                                    CGPointMake(rect.size.width, rect.size.height),
                                    0);
        
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        
        // Gloss
        CGRect glossRect = CGRectMake(0, 0, rect.size.width, rect.size.height * 0.4);
        UIBezierPath *glossPath = [UIBezierPath bezierPathWithRoundedRect:glossRect cornerRadius:radius];
        
        CGContextSaveGState(ctx);
        [glossPath addClip];
        
        CGColorSpaceRef gSpace = CGColorSpaceCreateDeviceRGB();
        NSArray *gColors = @[
            (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.25].CGColor,
            (__bridge id)[[UIColor clearColor] CGColor]
        ];
        
        CGFloat gLocs[] = {0.0, 1.0};
        CGGradientRef gGradient = CGGradientCreateWithColors(gSpace, (__bridge CFArrayRef)gColors, gLocs);
        
        CGContextDrawLinearGradient(ctx, gGradient,
                                    CGPointMake(0, 0),
                                    CGPointMake(0, glossRect.size.height),
                                    0);
        
        CGGradientRelease(gGradient);
        CGColorSpaceRelease(gSpace);
        CGContextRestoreGState(ctx);
        
        // Border
        UIBezierPath *border = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, 1, 1) cornerRadius:radius];
        border.lineWidth = 2;
        [[[UIColor whiteColor] colorWithAlphaComponent:0.2] setStroke];
        [border stroke];
        
        // Initials
        CGFloat fontSize = safeSize * 0.36;
        UIFont *font = [UIFont boldSystemFontOfSize:fontSize];
        
        NSMutableParagraphStyle *styleP = [NSMutableParagraphStyle new];
        styleP.alignment = NSTextAlignmentCenter;
        
        NSDictionary *attrs = @{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: UIColor.whiteColor,
            NSParagraphStyleAttributeName: styleP
        };
        
        CGSize textSize = [initials sizeWithAttributes:attrs];
        CGRect textRect = CGRectMake(0,
                                     (rect.size.height - textSize.height)/2,
                                     rect.size.width,
                                     textSize.height);
        
        [initials drawInRect:textRect withAttributes:attrs];
    }];
    
    return image;
}

+ (NSString *)initialsForDisplayName:(NSString *)displayName {
    
    NSString *trimmed = [[displayName ?: @"" stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    
    if (trimmed.length == 0) return @"?";
    
    NSArray *parts = [trimmed componentsSeparatedByString:@" "];
    
    NSString *first = parts.firstObject;
    NSString *last = parts.count > 1 ? parts.lastObject : @"";
    
    NSString *i1 = first.length ? [first substringToIndex:1] : @"";
    NSString *i2 = last.length ? [last substringToIndex:1] : @"";
    
    return [[NSString stringWithFormat:@"%@%@", i1, i2] uppercaseString];
}

#pragma mark - Colors

+ (NSArray *)paletteForSeed:(NSString *)seed {
    
    NSArray *palettes = @[
        @[
            [UIColor colorWithRed:0.96 green:0.36 blue:0.63 alpha:1],
            [UIColor colorWithRed:0.74 green:0.30 blue:0.95 alpha:1],
            [UIColor colorWithRed:0.38 green:0.55 blue:0.98 alpha:1]
        ],
        @[
            [UIColor colorWithRed:0.24 green:0.74 blue:0.89 alpha:1],
            [UIColor colorWithRed:0.37 green:0.57 blue:0.98 alpha:1],
            [UIColor colorWithRed:0.53 green:0.35 blue:0.95 alpha:1]
        ],
        @[
            [UIColor colorWithRed:0.11 green:0.78 blue:0.65 alpha:1],
            [UIColor colorWithRed:0.14 green:0.60 blue:0.89 alpha:1],
            [UIColor colorWithRed:0.36 green:0.43 blue:0.95 alpha:1]
        ]
    ];
    
    NSUInteger index = seed.hash % palettes.count;
    return palettes[index];
}

@end