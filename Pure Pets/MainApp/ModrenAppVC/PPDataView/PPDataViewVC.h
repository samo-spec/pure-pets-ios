#import <UIKit/UIKit.h>
#import "PPDataViewInput.h"
 
@interface PPDataViewVC : UIViewController <UICollectionViewDelegate>
- (instancetype)initWithInput:(PPDataViewInput *)input;
- (PPDataSection)sectionFromDeepLinkTarget:(PPDeepLinkTarget)target;
@end
