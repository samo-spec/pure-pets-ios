//  BubbleLayer.m
//  VideoCoreTest
//
#import "BubbleLayer.h"


@interface BubbleLayer()


// The size of the view that needs to be masked into a bubble shape
@property (nonatomic) CGSize size;


@end

@implementation BubbleLayer


#pragma mark - preparation

//Key point: Before drawing the bubble shape, you need to calculate the coordinates of the three points of the arrow and the four corners of the rectangle.
-(NSMutableArray *)keyPoints {
    
    NSMutableArray *points = [[NSMutableArray alloc]init];
    
    // First determine the three points of the arrow
     CGPoint beginPoint; // The first fulcrum when drawing the arrow clockwise, such as the left fulcrum when the arrow points upward.
     CGPoint topPoint; // vertex
     CGPoint endPoint; // Another pivot point
    
    //The range of the X coordinate (or Y coordinate) of the arrow vertex topPoint (used to calculate arrowPosition)
    CGFloat tpXRange = _size.width - 2 * _cornerRadius - _arrowWidth;
    CGFloat tpYRange = _size.height - 2 * _cornerRadius - _arrowWidth;
    
    // These parameters are used to determine the position of the rectangular box (that is, the area remaining after making room for the arrow)
    // These parameters will be adjusted below according to the position of the arrow
    CGFloat x = 0, y = 0; // Coordinates of the upper left corner of the rectangular box
    CGFloat width = _size.width, height = _size.height; //The size of the rectangular box
    
    // Calculate the position of the arrow and adjust the position and size of the rectangle
     switch (_arrowDirection) {
            
             //When the arrow is on the right
         case ArrowDirectionRight:
            
             topPoint = CGPointMake(_size.width , _size.height / 2 + tpYRange*(_arrowPosition - 0.5));
             beginPoint = CGPointMake(topPoint.x - _arrowHeight, topPoint.y - _arrowWidth/2);
             endPoint = CGPointMake(beginPoint.x, beginPoint.y + _arrowWidth);
            
             width -= _arrowHeight; //The position on the right side of the rectangular box is "vacated" for the arrow
             break;
            
            //When the arrow is down
        case ArrowDirectionBottom:
            topPoint = CGPointMake(_size.width / 2 + tpXRange*(_arrowPosition - 0.5), _size.height);
            beginPoint = CGPointMake(topPoint.x + _arrowWidth/2, topPoint.y - _arrowHeight);
            endPoint = CGPointMake(beginPoint.x - _arrowWidth, beginPoint.y);
            
            height -= _arrowHeight;
            break;
            
            //When the arrow is on the left
        case ArrowDirectionLeft:
           topPoint = CGPointMake(0, _size.height / 2 + tpYRange*(_arrowPosition - 0.5));
            beginPoint = CGPointMake(topPoint.x + _arrowHeight, topPoint.y + _arrowWidth/2);
            endPoint = CGPointMake(beginPoint.x, beginPoint.y - _arrowWidth);
            
            x = _arrowHeight;
            width -= _arrowHeight;
            break;
            
            //When the arrow is up
        case ArrowDirectionTop:
            topPoint = CGPointMake(_size.width / 2 + tpXRange*(_arrowPosition - 0.5), 0);
            beginPoint = CGPointMake(topPoint.x - _arrowWidth/2, topPoint.y + _arrowHeight);
            endPoint = CGPointMake(beginPoint.x + _arrowWidth, beginPoint.y);
            
            y = _arrowHeight;
            height -= _arrowHeight;
            break;
    }
    
    // 先把箭头的三个点放进关键点数组中
    points = [NSMutableArray arrayWithObjects:[NSValue valueWithCGPoint:beginPoint],
                  [NSValue valueWithCGPoint:topPoint],
                  [NSValue valueWithCGPoint:endPoint],  nil];
    
    
    
    //Determine the four points of the rounded rectangle
    CGPoint bottomRight = CGPointMake(x+width, y+height); //右下角的点
    CGPoint bottomLeft = CGPointMake(x, y+height);
    CGPoint topLeft = CGPointMake(x, y);
    CGPoint topRight = CGPointMake(x+width, y);
    
    
    //First place the four points of the rounded rectangle in a temporary array. The order of placement is related to the following operations.
    NSMutableArray *rectPoints = [NSMutableArray arrayWithObjects: [NSValue valueWithCGPoint:bottomRight],
                                  [NSValue valueWithCGPoint:bottomLeft],
                                  [NSValue valueWithCGPoint:topLeft],
                                  [NSValue valueWithCGPoint:topRight],  nil];
    
    
    //When drawing the bubble shape, start from the arrow and proceed clockwise
     // Assuming the arrow is pointing to the right, then after drawing the arrow, it will first be drawn to the lower right corner of the rectangular box
     // So at this time, first put the point in the lower right corner of the rectangular frame into the key point array, and add the other three points in a clockwise direction
    // When the arrow is in other directions, so on
    int rectPointIndex = (int)_arrowDirection;
    for(int i=0; i<4; i++) {
        [points addObject:[rectPoints objectAtIndex:rectPointIndex]];
        rectPointIndex = (rectPointIndex+1)%4;
    }
    
    return points;
}


#pragma mark - draw

- (CGPathRef)bubblePath
{
    // 🚨 HARD GUARD — NEVER draw with zero size
    if (self.size.width <= 1.0 || self.size.height <= 1.0) {
        return NULL;
    }

    UIGraphicsImageRendererFormat *format =
        [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    format.scale = UIScreen.mainScreen.scale;

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:self.size
                                               format:format];

    __block CGPathRef outPath = NULL;

    [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {

        CGContextRef ctx = context.CGContext;

        NSMutableArray *points = [self keyPoints];
        if (points.count < 7) return;

        CGPoint start = [points[6] CGPointValue];
        CGContextMoveToPoint(ctx, start.x, start.y);

        for (int i = 0; i < 7; i++) {
            CGPoint a = [points[i] CGPointValue];
            CGPoint b = [points[(i + 1) % 7] CGPointValue];

            CGFloat radius = (i < 3) ? self.arrowRadius : self.cornerRadius;
            CGContextAddArcToPoint(ctx, a.x, a.y, b.x, b.y, radius);
        }

        CGContextClosePath(ctx);
        outPath = CGContextCopyPath(ctx);
    }];

    return outPath;
}


- (CAShapeLayer *)layer
{
    CGPathRef path = [self bubblePath];
    if (!path) return nil;

    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.path = path;
    return layer;
}


#pragma mark - setup

//Set default parameters
- (void)setDefaultProperty {
    
    _cornerRadius = 8;
    _arrowWidth = 30;
    _arrowHeight = 12;
    _arrowDirection = 1;
    _arrowPosition = 0.5;
    _arrowRadius = 3;
    
}

#pragma mark - init

-(instancetype)initWithSize:(CGSize) originalSize {
    if(self = [super init]) {
        [self setDefaultProperty];
        _size = originalSize;
    }
    return self;
}

@end
