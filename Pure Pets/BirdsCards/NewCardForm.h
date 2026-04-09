//
//  NewCardForm.h
//  Pure Pets
//
//  Created by IQRQA on 12/14/16.
//  Refactored: XLForm fully removed — modern UIScrollView form.
//

#import "importantFiles.h"
#import "CardModel.h"
#import "RelativeDateDescriptor.h"
#import "PPImageCollection.h"

@protocol refreshNewDelegate <NSObject>
- (void)refreshView;
- (void)refreshSelectedChild;
- (void)updateViewDone;
- (void)referchChils:(BOOL)showHUD;
@end

@interface NewCardForm : UIViewController <PPImageCollectionDelegate, UITextFieldDelegate, UITextViewDelegate>

@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong) PPImageCollection *imageCollection;
@property (nonatomic, weak) id<refreshNewDelegate> delegate;
@property (strong, nonatomic) CardModel *serverCardClass;
@property (strong, nonatomic) UIView *topView;
@property (strong, nonatomic) NSString *FromVC;
@property (copy, nonatomic) NSString *prefilledRingID;
@property (strong, nonatomic) UILabel *topTitle;

@end
