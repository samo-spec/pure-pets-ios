//
//  WelcomeView.m
//  GuideWelcomeView
//
//  Created by yxhe on 16/10/11.
//  Copyright © 2016年 tashaxing. All rights reserved.
//

// ---- 启动后的欢迎页或者广告页 ---- //


#import "WelcomeView.h"

@interface WelcomeView ()
{
    UIButton *timerBtn;
    NSTimer *stipTimer;
}
@end

@implementation WelcomeView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        // 这里用一张本地图片，实际工程中涉及到读缓存，从网络获取广告图以及一些动画等
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        UIImage *welcomeImage = [UIImage imageNamed:@"welcome.jpg"];
        imageView.image = welcomeImage;
        [self addSubview:imageView];
        
        // 添加欢迎语
        UILabel *welcomeLabel = [[UILabel alloc] init];
        welcomeLabel.frame = CGRectMake(self.frame.size.width / 2 - 70, 500, 140, 30);
        welcomeLabel.text = @"欢迎";
        welcomeLabel.textAlignment = NSTextAlignmentCenter;
        welcomeLabel.font = [UIFont systemFontOfSize:25];
        welcomeLabel.textColor = [UIColor whiteColor];
        [imageView addSubview:welcomeLabel];
        
        // 添加计时button
        timerBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        timerBtn.frame = CGRectMake(self.frame.size.width - 50, 25, 50, 20);
        [timerBtn setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
        [timerBtn setTitle:@"4 s" forState:UIControlStateNormal];
        timerBtn.layer.cornerRadius = 10;
        timerBtn.layer.borderWidth = 1;
        timerBtn.enabled = NO;
        [self addSubview:timerBtn];
        
        stipTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(tickTime)
                                                        userInfo:nil
                                                         repeats:YES];
    }
    return self;
}

- (void)tickTime
{
    // 3秒后可以跳转到主页
    static NSInteger seconds = 3;
    [timerBtn setTitle:[NSString stringWithFormat:@"%ld s", seconds] forState:UIControlStateNormal];
    seconds--;
    if (seconds == 0)
    {
        timerBtn.enabled = YES;
        [timerBtn setTitle:@"skip" forState:UIControlStateNormal];
        // button生效，立即点击就跳过
        [timerBtn addTarget:self action:@selector(skipNext) forControlEvents:UIControlEventTouchUpInside];
        [stipTimer invalidate];
        
        // 2秒后消失
        [self performSelector:@selector(skipNext) withObject:nil afterDelay:2];
    }
}

- (void)skipNext
{
    // 判断如果self已经不在了，则两秒后什么也不做，防止内存泄露
    if (self)
    {
        [UIView animateWithDuration:0.5 animations:^{
            self.transform = CGAffineTransformMakeScale(0.01, 0.01);
        } completion:^(BOOL finished) {
            [self removeFromSuperview];
        }];
    }
}

@end
