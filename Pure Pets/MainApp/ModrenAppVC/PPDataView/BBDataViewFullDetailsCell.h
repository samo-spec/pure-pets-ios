#import <UIKit/UIKit.h>

@class PPUniversalCellViewModel;
@class BBDataViewFullDetailsCell;

NS_ASSUME_NONNULL_BEGIN

typedef void (^BBDataViewFullDetailsImageLoader)(UIImageView *_Nullable imageView,
                                                 NSString *_Nullable url,
                                                 UIImage *_Nullable placeholder,
                                                 UIView *_Nullable card);

@protocol BBDataViewFullDetailsCellDelegate <NSObject>
@optional
- (void)fullDetailsCellDidRequestOpen:(BBDataViewFullDetailsCell *)cell
                            viewModel:(PPUniversalCellViewModel *)viewModel;
- (void)fullDetailsCellDidRequestShare:(BBDataViewFullDetailsCell *)cell
                             viewModel:(PPUniversalCellViewModel *)viewModel;
- (void)fullDetailsCellDidRequestEdit:(BBDataViewFullDetailsCell *)cell
                            viewModel:(PPUniversalCellViewModel *)viewModel;
- (void)fullDetailsCellDidRequestDelete:(BBDataViewFullDetailsCell *)cell
                              viewModel:(PPUniversalCellViewModel *)viewModel;
- (void)fullDetailsCellDidRequestVisibilityToggle:(BBDataViewFullDetailsCell *)cell
                                        viewModel:(PPUniversalCellViewModel *)viewModel;
- (void)fullDetailsCell:(BBDataViewFullDetailsCell *)cell
 didRequestQuantityDelta:(NSInteger)delta
              viewModel:(PPUniversalCellViewModel *)viewModel;
@end

@interface BBDataViewFullDetailsCell : UICollectionViewCell

@property (nonatomic, weak, nullable) id<BBDataViewFullDetailsCellDelegate> delegate;

+ (NSString *)reuseIdentifier;
- (void)configureWithViewModel:(PPUniversalCellViewModel *)viewModel
                   imageLoader:(nullable BBDataViewFullDetailsImageLoader)imageLoader
                      delegate:(nullable id<BBDataViewFullDetailsCellDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
