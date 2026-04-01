//
//  main.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/07/2024.
//



#import "AppDelegate.h"
int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv,nil,appDelegateClassName);
}
/*
 self.isReloadingCollectionView = YES;
 [self.collectionView reloadData];
 self.isReloadingCollectionView = NO; // Reset immediately (reloadData is synchronous)
 
    m,bv

 
 
 */


