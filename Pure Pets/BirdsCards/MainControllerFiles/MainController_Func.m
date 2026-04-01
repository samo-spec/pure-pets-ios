//
//  MainController+ PPFunc.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 24/12/2025.
//

#import "MainController_Func.h"
 

@interface MainController_Func () {
    __weak MainController *_mainController;
}

@end

@implementation MainController_Func

-(instancetype)initWithController:(MainController *)vc
{
    self = [super init];
    if (self) {
        // Store the passed-in controller. If a property exists, this will set it; otherwise, it will create an ivar named _controller implicitly if declared in the header.
        _mainController = vc;
    }
    return self;
}

@end

