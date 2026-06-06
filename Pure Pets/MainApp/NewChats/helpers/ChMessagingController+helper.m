//
//  ChMessagingController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 19/01/2026.
//
#import "ChMessagingController+helper.h"
#import <objc/runtime.h>


@interface ChMessagingController ()<PHPickerViewControllerDelegate>

@end
@implementation ChMessagingController (CHHelper)

 

#pragma mark - Incoming Message Feedback
 
  
  
#pragma mark - Setup Views

- (void)setupTableView {
   
  
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.tableView registerClass:[ChatMessageCell class]
           forCellReuseIdentifier:@"ChatMessageCell"];
    [self.tableView registerClass:[ChatAudioMessageCell class]
           forCellReuseIdentifier:@"ChatAudioMessageCell"];
    [self.tableView registerClass:ChatImageMessageCell.class
           forCellReuseIdentifier:@"ChatImageMessageCell"];
    [self.tableView registerClass:ChatVideoMessageCell.class
           forCellReuseIdentifier:@"ChatVideoMessageCell"];

    
  

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
     self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:self.tableView];
    self.tableView.backgroundColor = UIColor.clearColor;
    
    self.tableView.contentInset = UIEdgeInsetsMake(PPNavBarHeightFull + 6, 0, 8, 0);
     
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.inputbar.topAnchor],
    ]];
}



- (void)presentMediaPickerForType:(NSString *)uti
{
    [self.inputbar endEditing:YES];
    [self.view endEditing:YES];
    PHPickerConfiguration *config =
        [[PHPickerConfiguration alloc] init];

    config.selectionLimit = 1;

    if ([uti isEqualToString:UTTypeImage.identifier]) {
        config.filter = PHPickerFilter.imagesFilter;
    } else if ([uti isEqualToString:UTTypeMovie.identifier]) {
        config.filter = PHPickerFilter.videosFilter;
    }

    PHPickerViewController *picker =
        [[PHPickerViewController alloc] initWithConfiguration:config];

    picker.delegate = self;
    [PPFunc presentSheetFrom:self sheetVC:picker detentStyle:PPSheetDetentStyleSemiLargAndLarge];
}



 

- (void)setupChatHeader
{
   //UserModel *other = [ChatThreadModel otherUserInThread:self.chatThread];
    self.chatHeaderView = [[PPChatHeaderView alloc] init];
    self.chatHeaderView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.chatHeaderView];

    [self.chatHeaderView pp_setShadowColor:[UIColor.blackColor colorWithAlphaComponent:0.5]];
    self.chatHeaderView.layer.shadowOpacity = 0.02;
    self.chatHeaderView.layer.shadowRadius = 8;
    self.chatHeaderView.layer.shadowOffset = CGSizeMake(0, 3);

   
   
   CGFloat headerHeight = 64;

   [NSLayoutConstraint activateConstraints:@[
       [self.chatHeaderView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
       [self.chatHeaderView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
       [self.chatHeaderView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
       [self.chatHeaderView.heightAnchor constraintEqualToConstant:headerHeight]
   ]];
     
}

 


- (void)pp_animateHeaderStatusText:(NSString *)text {
    if (!self.chatHeaderView)
        return;

    UILabel *statusLabel = [self.chatHeaderView valueForKey:@"statusLabel"];
    if (!statusLabel)
        return;

    [UIView transitionWithView:statusLabel
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                      statusLabel.text = text;
                      statusLabel.alpha = 1.0;
                    }
                    completion:nil];
}


#pragma mark - Associated Objects
 
- (UITableView *)tableView {
    return objc_getAssociatedObject(self, @selector(tableView));
}

-(void)setTableView:(UITableView *)tableView
{
    objc_setAssociatedObject(self,
                             @selector(tableView),
                             tableView,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

  

-(id<FIRListenerRegistration>)typingListener
{
    return objc_getAssociatedObject(self, @selector(typingListener));

}

- (void)setTypingListener:(id<FIRListenerRegistration>)typingListener
{
    objc_setAssociatedObject(self,
                             @selector(typingListener),
                             typingListener,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id<FIRListenerRegistration>)typeListener {
    return objc_getAssociatedObject(self, @selector(typeListener));
}

- (void)setTypeListener:(id<FIRListenerRegistration>)listener {
    objc_setAssociatedObject(self,
                             @selector(typeListener),
                             listener,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (id<FIRListenerRegistration>)messageListener {
   return objc_getAssociatedObject(self, @selector(messageListener));
}

- (void)setMessageListener:(id<FIRListenerRegistration>)listener {
   objc_setAssociatedObject(self,
                            @selector(messageListener),
                            listener,
                            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


 
-(FIRAuthStateDidChangeListenerHandle)authListenerHandle
{
    return objc_getAssociatedObject(self, @selector(authListenerHandle));
}

-(void)setAuthListenerHandle:(FIRAuthStateDidChangeListenerHandle)authListenerHandle
{
    objc_setAssociatedObject(self,
                             @selector(authListenerHandle),
                             authListenerHandle,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end
