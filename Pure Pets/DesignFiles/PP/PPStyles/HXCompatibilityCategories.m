//
//  HXCompatibilityCategories.m
//  Pure Pets
//
//  Lightweight shim providing UIView layout and UIColor hex helpers
//  originally supplied by the old ObjC HXPhotoPicker categories.
//

#import "HXCompatibilityCategories.h"

#pragma mark - UIView (HXLayout)

@implementation UIView (HXLayout)

- (CGFloat)hx_x     { return self.frame.origin.x; }
- (void)setHx_x:(CGFloat)hx_x {
    CGRect f = self.frame; f.origin.x = hx_x; self.frame = f;
}

- (CGFloat)hx_y     { return self.frame.origin.y; }
- (void)setHx_y:(CGFloat)hx_y {
    CGRect f = self.frame; f.origin.y = hx_y; self.frame = f;
}

- (CGFloat)hx_w     { return self.frame.size.width; }
- (void)setHx_w:(CGFloat)hx_w {
    CGRect f = self.frame; f.size.width = hx_w; self.frame = f;
}

- (CGFloat)hx_h     { return self.frame.size.height; }
- (void)setHx_h:(CGFloat)hx_h {
    CGRect f = self.frame; f.size.height = hx_h; self.frame = f;
}

- (CGFloat)hx_centerX { return self.center.x; }
- (void)setHx_centerX:(CGFloat)hx_centerX {
    CGPoint c = self.center; c.x = hx_centerX; self.center = c;
}

- (CGFloat)hx_centerY { return self.center.y; }
- (void)setHx_centerY:(CGFloat)hx_centerY {
    CGPoint c = self.center; c.y = hx_centerY; self.center = c;
}

- (CGFloat)hx_maxx  { return CGRectGetMaxX(self.frame); }
- (CGFloat)hx_maxy  { return CGRectGetMaxY(self.frame); }

- (CGSize)hx_size    { return self.frame.size; }
- (void)setHx_size:(CGSize)hx_size {
    CGRect f = self.frame; f.size = hx_size; self.frame = f;
}

- (CGPoint)hx_origin { return self.frame.origin; }
- (void)setHx_origin:(CGPoint)hx_origin {
    CGRect f = self.frame; f.origin = hx_origin; self.frame = f;
}

- (CGFloat)height    { return self.frame.size.height; }
- (void)setHeight:(CGFloat)h {
    CGRect f = self.frame; f.size.height = h; self.frame = f;
}

- (CGFloat)width     { return self.frame.size.width; }
- (void)setWidth:(CGFloat)w {
    CGRect f = self.frame; f.size.width = w; self.frame = f;
}

- (CGSize)size       { return self.frame.size; }
- (void)setSize:(CGSize)s {
    CGRect f = self.frame; f.size = s; self.frame = f;
}

- (CGFloat)centerX   { return self.center.x; }
- (void)setCenterX:(CGFloat)cx {
    self.center = CGPointMake(cx, self.center.y);
}

- (CGFloat)centerY   { return self.center.y; }
- (void)setCenterY:(CGFloat)cy {
    self.center = CGPointMake(self.center.x, cy);
}

@end

#pragma mark - UIColor (HXHex)

@implementation UIColor (HXHex)

+ (UIColor *)colorWithHexString:(NSString *)hexString {
    return [self hx_colorWithHexStr:hexString];
}

+ (UIColor *)hx_colorWithHexStr:(NSString *)hexString {
    if (!hexString || hexString.length == 0) return [UIColor clearColor];
    
    NSString *hex = [hexString stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([hex hasPrefix:@"#"])  hex = [hex substringFromIndex:1];
    if ([hex hasPrefix:@"0x"]) hex = [hex substringFromIndex:2];
    
    if (hex.length == 3) {
        unichar c0 = [hex characterAtIndex:0];
        unichar c1 = [hex characterAtIndex:1];
        unichar c2 = [hex characterAtIndex:2];
        hex = [NSString stringWithFormat:@"%C%C%C%C%C%C", c0, c0, c1, c1, c2, c2];
    }
    if (hex.length == 6) hex = [hex stringByAppendingString:@"FF"];
    if (hex.length != 8) return [UIColor clearColor];
    
    unsigned int rgba = 0;
    [[NSScanner scannerWithString:hex] scanHexInt:&rgba];
    
    return [UIColor colorWithRed:((rgba >> 24) & 0xFF) / 255.0
                           green:((rgba >> 16) & 0xFF) / 255.0
                            blue:((rgba >>  8) & 0xFF) / 255.0
                           alpha:((rgba >>  0) & 0xFF) / 255.0];
}

+ (UIColor *)hx_colorWithR:(CGFloat)r g:(CGFloat)g b:(CGFloat)b a:(CGFloat)a {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}

+ (BOOL)hx_colorIsWhite:(UIColor *)color {
    CGFloat r, g, b, a;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        return (r > 0.9 && g > 0.9 && b > 0.9);
    }
    return NO;
}

- (NSString *)hx_hexStringWithColor {
    CGFloat r, g, b, a;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return @"#000000";
    }
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)(r * 255), (int)(g * 255), (int)(b * 255)];
}

@end
