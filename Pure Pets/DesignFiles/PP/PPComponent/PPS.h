//
//  PPS.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//


//  PPS.h
//  Reusable search control with blur "glass" background, shadow & fuzzy search.
//  MIT-style – feel free to adapt.

#import <UIKit/UIKit.h>

 
typedef NS_ENUM(NSInteger, PPGlassDateButtonSize) {
    PPGlassDateButtonSizeCompact,
    PPGlassDateButtonSizeLarge
};


@interface PPGlassDateButton : UIButton
- (void)showTipOnceWithText:(NSString *)text
           inViewController:(UIViewController *)controller;
@property (nonatomic) PPGlassDateButtonSize sizeVariant;
/// Current date displayed by the button
@property (nonatomic, strong) NSDate *date;
- (void)presentDatePickerFrom:(UIViewController *)controller
                    completion:(void (^ _Nullable)(NSDate *selectedDate))completion;/// Update displayed date (animated)
- (void)setDate:(NSDate *)date animated:(BOOL)animated;
@property (nonatomic) BOOL hapticsEnabled;
/// Convenience: reset to today
- (void)setToday;

@end
 
typedef NS_ENUM(NSInteger, PPSBarStyle) {
    PPSBarStyleSearch,
    PPSBarStyleTextfield
};


@class PPS;

@protocol PPSDelegate <NSObject>
@optional
- (void)searchViewDidBeginEditing:(PPS *)view;
- (void)searchViewDidEndEditing:(PPS *)view;
- (void)searchView:(PPS *)view didChangeText:(NSString *)text;
- (void)searchViewDidSubmit:(PPS *)view; // Return key tapped
- (void)searchViewPrimaryButtonTapped:(PPS *)view;
- (void)searchViewSecondaryButtonTapped:(PPS *)view;
@end

/// Provider that converts an item to a searchable string.
typedef NSString * _Nonnull (^PPSearchStringProvider)(id item);
/// Completion for async fuzzy results.
typedef void (^PPSearchResultsHandler)(NSString *query, NSArray *results);

@interface PPS : UIView <UITextFieldDelegate>
- (void)setEditingState:(BOOL)editing animated:(BOOL)animated;
/// Public subviews
@property (nonatomic, strong, readonly) UITextField *textField;
@property (nonatomic, strong, readonly) UIButton *primaryButton;   // Hidden by default
@property (nonatomic, strong, readonly) UIButton *secondaryButton; // Hidden by default
@property (nonatomic) PPSBarStyle barStyle;               // default YES

/// Layout & appearance
@property (nonatomic) UIEdgeInsets contentInsets;       // default {8, 12, 8, 8}
@property (nonatomic) CGFloat cornerRadius;             // default 12
@property (nonatomic) BOOL shadowEnabled;               // default YES
@property (nonatomic, strong) UIColor *shadowColor;     // default black 0,0,0
@property (nonatomic) CGFloat shadowOpacity;            // default 0.08
@property (nonatomic) CGFloat shadowRadius;             // default 8
@property (nonatomic) CGSize  shadowOffset;             // default {0, 3}

@property (nonatomic) BOOL blurEnabled;                 // default YES
@property (nonatomic, strong) UIBlurEffect *blurEffect; // default systemMaterial / light fallback
@property (nonatomic) CGFloat glassAlpha;               // default 1.0 (opacity for blur holder)
@property (nonatomic, strong) UIColor *strokeColor;     // optional 1px outline, default clear

@property (nonatomic, strong) UIButton *btn1;
@property (nonatomic, strong) UIButton *btn2;

@property (nonatomic, strong) UIViewController *vcParent;

/// Behaviour
@property (nonatomic, weak, nullable) id<PPSDelegate> delegate;
@property (nonatomic) NSTimeInterval debounceInterval;  // default 0.18s
@property (nonatomic) UIReturnKeyType returnKeyType;    // default UIReturnKeySearch

/// Buttons configuration (nil image keeps current)
- (void)configurePrimaryButtonWithImage:(nullable UIImage *)image target:(nullable id)target action:(nullable SEL)action;
- (void)configureSecondaryButtonWithImage:(nullable UIImage *)image target:(nullable id)target action:(nullable SEL)action;
- (void)configurePrimaryButtonWithImage:(UIImage *)image selectedImage:(UIImage *)selectedImage target:(id)target action:(SEL)action;
/// Convenience toggles
@property (nonatomic) BOOL showsPrimaryButton;   // default NO
@property (nonatomic) BOOL showsSecondaryButton; // default NO
@property (nonatomic) BOOL showsDateButton; // default NO
/// Become first responder passthrough
- (BOOL)focus;
- (void)unfocus;

/// Update iOS 26 glass background tint (safe no-op on older iOS)
- (void)updateGlassBackgroundColor:(UIColor *)color
                           opacity:(CGFloat)opacity;

@property (nonatomic, strong) PPGlassDateButton *dateButton;
/// ---------- Fuzzy Search (optional) ----------
@property (nonatomic) BOOL fuzzyEnabled;             // default YES
@property (nonatomic) NSInteger maxEditDistance;     // default 2
@property (nonatomic) CGFloat minRelevanceScore;     // 0..1, default 0.55
@property (nonatomic) BOOL caseInsensitive;          // default YES
@property (nonatomic) BOOL diacriticsInsensitive;    // default YES
@property (nonatomic) NSInteger maxResults;          // default 50
@property (nonatomic) BOOL sortByRelevance;          // default YES

/// Provide items + a string provider to enable built-in fuzzy filtering.
- (void)setSearchItems:(NSArray *)items
       stringProvider:(PPSearchStringProvider)provider;

/// Trigger async fuzzy filtering (uses internal queue + debounce token).
- (void)filterAsyncForText:(NSString *)query completion:(PPSearchResultsHandler)completion;

/// Option A: Provide keyPaths to search on each item (e.g., @"name", @"email", @"phone")
- (void)setSearchItems:(NSArray *)items
              keyPaths:(NSArray<NSString *> *)keyPaths;

/// Option B: Provide multiple searchable strings per item
typedef NSArray<NSString *> * _Nonnull (^PPMultiStringProvider)(id item);
- (void)setSearchItems:(NSArray *)items
  multiStringProvider:(PPMultiStringProvider)provider;

- (void)configureGlassButton:(UIButton *)button
                       image:(UIImage *)image
               selectedImage:(UIImage *)selectedImage
                      target:(id)target
                      action:(SEL)action;

@property (nonatomic, strong) UIButton *glassView;
@end
 
