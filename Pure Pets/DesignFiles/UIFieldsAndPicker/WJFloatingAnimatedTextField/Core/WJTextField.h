//
//  WJTextField.h
//  WJFloatingAnimatedTextField
//
//  Created by VanJay on 2018/8/13.
//  Copyright © 2018年 VanJay. All rights reserved.
//



@interface WJTextField : UITextField

/**
  Cancel editing function
  */
 @property (nonatomic, assign) BOOL canelEdit;
 /**
  * The range selected by the cursor
  *
  * @return Get the cursor selection range
  */
 - (NSRange)selectedRange;

 /**
  * Set the cursor selection range
  *
  * @param range The range selected by the cursor
  */
- (void)setSelectedRange:(NSRange)range;
@end
