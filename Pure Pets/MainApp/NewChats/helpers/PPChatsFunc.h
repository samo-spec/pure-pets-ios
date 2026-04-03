//
//  PPChatsFunc.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 19/01/2026.
//

#import <Foundation/Foundation.h>


 
NS_ASSUME_NONNULL_BEGIN

@protocol ChatMessageStatusUpdatable <NSObject>
- (void)updateMessageStatus:(ChatMessageModel *)message;
@end


@protocol PPChatBubbleColorProviding <NSObject>
@required
- (UIColor *)pp_bubbleBackgroundColor;
@end


 
@interface PPChatsFunc : NSObject
+ (NSString *)formattedCurrency:(CGFloat)value;
+ (void)applyGlowIfNeededToBubble:(UIView *)bubble
                             path:(UIBezierPath *)path
                         showGlow:(BOOL)showGlow
                       isIncoming:(BOOL)isIncoming;


+ (void)applyBubbleMask:(UIView *)bubble
             isIncoming:(BOOL)isIncoming
          groupPosition:(PPChatGroupPosition)position
               showGlow:(BOOL)showGlow;


//- (instancetype)init NS_UNAVAILABLE;
+ (UIButton *)buttonWithSystemName:(NSString *)imageName
                        buttonSide:(float)side
                            target:(id)target
                            action:(nullable SEL)action;
 
 
@end


@interface PPChatGradientView : UIView

- (void)applyTopGradient;
- (void)applyBottomGradient;

@end



  
@interface PPChatBackgroundManager : NSObject

+ (instancetype)shared;

/// Fetch random background (1–10)
- (void)fetchRandomChatBackground:(void (^)(UIImage * _Nullable image))completion;

/// Fetch background by index (1–10)
- (void)fetchChatBackgroundAtIndex:(NSInteger)index
                        completion:(void (^)(UIImage * _Nullable image))completion;

@end










@interface PPChatBackgroundPickerController : UIViewController

- (instancetype)initWithSelectedIndex:(NSInteger)index
                            selection:(void (^)(NSInteger selectedIndex))selection;

@end





























//
//  PPAmazingBar.h
//  PurePets
//
//  A custom input accessory bar supporting text, voice, and media.
//  Use iOS 16+ (keyboardLayoutGuide) and HXPhotoPicker for media.
//  Author: Generated for PurePets app.
//
 

@class PPAmazingBar;
typedef NS_ENUM(NSInteger, PPMediaPickerStyle) {
    PPMediaPickerStyleOverlay,   // present picker modally over content
    PPMediaPickerStyleSlideUp    // slide up from bar (attached)
};

// Delegate protocol for PPAmazingBar events.
@protocol PPAmazingBarDelegate <NSObject>
@required
// Called when user taps Send with text (non-empty).
- (void)amazingBar:(PPAmazingBar *)bar didSendText:(NSString *)text;
// Called when user starts voice recording.
- (void)amazingBarDidStartRecording:(PPAmazingBar *)bar;
// Called when user stops recording and sends the audio.
// The URL points to the recorded file, duration is in seconds.
- (void)amazingBar:(PPAmazingBar *)bar didSendRecording:(NSURL *)audioURL duration:(NSTimeInterval)duration;
// Called when user attaches media (array of UIImage).
- (void)amazingBar:(PPAmazingBar *)bar didAttachMedia:(NSArray<UIImage *> *)media;
@end

@interface PPAmazingBar : UIView

@property (nonatomic, weak) id<PPAmazingBarDelegate> delegate;
@property (nonatomic, assign) PPMediaPickerStyle mediaPickerStyle;

// Maximum lines for text input (default 5).
@property (nonatomic, assign) NSInteger maxLines;

// Attach and customize appearance if needed.
- (instancetype)initWithMaxLines:(NSInteger)maxLines;

@end
NS_ASSUME_NONNULL_END
