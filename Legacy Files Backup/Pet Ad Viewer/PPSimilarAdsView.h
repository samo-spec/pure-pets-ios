#import <UIKit/UIKit.h>

@class PPUniversalCellViewModel;

NS_ASSUME_NONNULL_BEGIN

typedef void (^PPSimilarAdsContentHandler)(BOOL hasContent, NSInteger itemCount);

@interface PPSimilarAdsView : UIView


/// Provide already-built VMs (from your VM layer)
- (void)updateWithViewModels:(NSArray<PPUniversalCellViewModel *> *)viewModels;

/// Forward selection like PPDataViewVC
@property (nonatomic, copy) void (^didSelectViewModel)(PPUniversalCellViewModel *vm);
@property (nonatomic, strong) NSString *titleString;
@property (nonatomic, copy, nullable) PPSimilarAdsContentHandler didUpdateContentState;

@property (nonatomic, assign, readonly) BOOL hasContent;

@end

NS_ASSUME_NONNULL_END
