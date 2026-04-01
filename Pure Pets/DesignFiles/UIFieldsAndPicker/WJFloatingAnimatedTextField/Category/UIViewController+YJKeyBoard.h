//
// UIViewController+YJKeyBoard.h
 // One line of code solves the iOS keyboard blocking problem



@interface UIViewController (YJKeyBoard)

// Automatically handle keyboard occlusion method
 - (void)yj_addKeyBoardHandle;

 /**
  Controls that move based on keyboard (optional)
  The default is self.view to change origin.y to move
  */
 @property (nonatomic, strong) UIView *yj_needScrollView;

 //Total distance moved by the control (read-only)
 @property (nonatomic, assign, readonly) CGFloat yj_moveDistance;
 //The control at focus is relative to the lowest point of the window (read-only)
 @property (nonatomic, assign, readonly) CGFloat yj_currentEditViewBottom;
 //The control where the focus is
 @property (nonatomic, strong) UIView *yj_currentEditView;

@end
