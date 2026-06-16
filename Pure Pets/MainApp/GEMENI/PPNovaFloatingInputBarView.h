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
- (void)novaInputBarDidTapSuggestions:(PPNovaFloatingInputBarView *)bar;
- (void)novaInputBarDidTapAttachment:(PPNovaFloatingInputBarView *)bar;
- (void)novaInputBarDidTapMicrophone:(PPNovaFloatingInputBarView *)bar;

@end

@interface PPNovaFloatingInputBarView : UIView

@property (nonatomic, weak, nullable) id<PPNovaFloatingInputBarViewDelegate> delegate;

@property (nonatomic, assign) BOOL attachmentEnabled;
@property (nonatomic, assign) BOOL microphoneEnabled;
@property (nonatomic, assign) BOOL suggestionsEnabled;
@property (nonatomic, assign) NSInteger attachmentCount;
@property (nonatomic, assign) BOOL thinking;
@property (nonatomic, assign, getter=isTextInputFocused) BOOL textInputFocused;

- (void)clearText;
- (void)setText:(NSString *)txt;
- (void)focusTextInput;
- (void)setThinking:(BOOL)thinking animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
