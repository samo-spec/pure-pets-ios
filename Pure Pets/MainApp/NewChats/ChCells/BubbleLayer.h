//  BubbleLayer.h
//  VideoCoreTest

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Some names used in comments
 // Arrow: The triangle that the bubble shape protrudes from is called [arrow]
 //The top and bottom points of the arrow: The point pointed by the arrow is called the [vertex], and the other two points are called [bottom points]
 //Height and width of arrow: The distance between the vertex of the arrow and the line connecting the bottom point is called [height of arrow], and the distance between the two bottom points is called [width of arrow]
// Rectangular box: Except for the arrow, the rest of the bubble shape is called [rectangular box]
 // Relative position of the arrow: 0 if the direction of the arrow is to the right or left means the arrow is at the top, 1 means the arrow is at the bottom
 // If the direction of the arrow is up or down, 0 means the arrow is on the far left, 1 means the arrow is on the far right
 // The default is 0.5, which is in the middle

 //Arrow direction enumeration
typedef enum {
    ArrowDirectionRight = 0, //Point to the right, that is, on the right side of the rounded rectangle
    ArrowDirectionBottom = 1, //point down
    ArrowDirectionLeft = 2,  //Point to the left
    ArrowDirectionTop = 3,  //Point upward
    
} ArrowDirection;


@interface BubbleLayer : NSObject

// Radius of the rounded corners of the rectangle
@property CGFloat cornerRadius;
//The fillet radius of the arrow position
@property CGFloat arrowRadius;
//The height of the arrow
@property CGFloat arrowHeight;
//The width of the arrow
@property CGFloat arrowWidth;
// Arrow direction
@property ArrowDirection arrowDirection;
// Relative position of the arrow
@property CGFloat arrowPosition;


//The size here is the size of the view that needs to be masked into a bubble shape.
- (instancetype) initWithSize:(CGSize) originalSize;

- (CAShapeLayer *) layer; //Finally use this layer to set the mask

@end

