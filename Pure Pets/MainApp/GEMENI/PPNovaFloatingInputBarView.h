//
//  PPNovaFloatingInputBarView.h
//  Pure Pets
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPNovaFloatingInputBarView;

@protocol PPNovaFloatingInputBarViewDelegate <NSObject>

- (void)novaInputBar:(PPNovaFloatingInputBarView *)bar didSendText:(NSString *)text;

@optional
- (void)novaInputBar:(PPNovaFloatingInputBarView *)bar didChangeHeight:(CGFloat)height;
- (void)novaInputBarDidBeginEditing:(PPNovaFloatingInputBarView *)bar;
- (void)novaInputBar:(PPNovaFloatingInputBarView *)bar didChangeText:(NSString *)text;

@end

@interface PPNovaFloatingInputBarView : UIView

@property (nonatomic, weak, nullable) id<PPNovaFloatingInputBarViewDelegate> delegate;

- (void)clearText;
-(void)setText:(NSString *)txt;
- (void)focusTextInput;
@end

NS_ASSUME_NONNULL_END
