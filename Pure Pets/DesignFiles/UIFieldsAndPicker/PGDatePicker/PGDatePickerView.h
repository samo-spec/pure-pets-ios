//
//  PGDatePickerView.h
//
//  Created by piggybear on 2017/7/25.
//  Copyright © 2017年 piggybear. All rights reserved.
//



@interface PGDatePickerView : UITableViewCell
@property (nonatomic, copy) NSString *content;
@property (nonatomic, assign, getter = isCurrentDate) BOOL currentDate;
@end
