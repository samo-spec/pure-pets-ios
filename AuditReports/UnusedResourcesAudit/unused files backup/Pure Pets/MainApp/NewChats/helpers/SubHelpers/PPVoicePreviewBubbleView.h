//
//  PPVoicePreviewBubbleView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/01/2026.
//


@interface PPVoicePreviewBubbleView : UIView

@property (nonatomic, copy) void (^onSend)(void);
@property (nonatomic, copy) void (^onDelete)(void);
@property (nonatomic, copy) void (^onPlay)(void);

- (void)configureWithDuration:(NSTimeInterval)duration;

@end