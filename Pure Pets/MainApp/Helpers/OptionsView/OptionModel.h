
//
//  OptionModel.h
//

#import <Foundation/Foundation.h>
 
NS_ASSUME_NONNULL_BEGIN

@interface OptionModel : NSObject <XLFormOptionObject, NSSecureCoding, NSCopying>

/// Stable identifier for the option (e.g. "newAd", "addUsedButton")
@property (nonatomic, copy, readonly) NSString *optID;

/// Primary display title
@property (nonatomic, copy) NSString *title;

/// Optional subtitle (smaller secondary text)
@property (nonatomic, copy, nullable) NSString *subtitle;

/// App asset image name (e.g. from your xcassets)
@property (nonatomic, copy, nullable) NSString *imageName;

/// SF Symbol name (iOS 13+) if you prefer system icons
@property (nonatomic, copy, nullable) NSString *systemImageName;

/// Optional ordering hint (lower comes first)
@property (nonatomic) NSInteger sortOrder;

/// Pin to top (before regular options)
@property (nonatomic, getter=isPinned) BOOL pinned;

/// MARK: - Designated initializer
- (instancetype)initWithID:(NSString *)optID
                     title:(NSString *)title
                  subtitle:(nullable NSString *)subtitle
                 imageName:(nullable NSString *)imageName
           systemImageName:(nullable NSString *)systemImageName NS_DESIGNATED_INITIALIZER;

/// Convenience
- (instancetype)initWithID:(NSString *)optID title:(NSString *)title;
+ (instancetype)optionWithID:(NSString *)optID title:(NSString *)title imageName:(nullable NSString *)imageName;
+ (instancetype)optionWithID:(NSString *)optID title:(NSString *)title systemImage:(nullable NSString *)systemImageName;
+ (instancetype)optionWithID:(NSString *)optID title:(NSString *)title imageName:(nullable NSString *)imageName systemImage:(nullable NSString *)systemImageName desc:(NSString *)desc;
@property (nonatomic, copy) NSString *desc; // optional description
- (instancetype)initWithID:(NSString *)optID title:(NSString *)title desc:(NSString *)desc;

/// MARK: - XLFormOptionObject
- (id)formValue;                 // returns self
- (NSString *)formDisplayText;   // returns title

/// MARK: - Persistence (NSUserDefaults)
+ (NSArray<OptionModel *> *)getSavedOptionModels;
+ (void)saveOptionModel:(OptionModel *)newOption;                 // upsert by optID
+ (BOOL)removeOptionWithID:(NSString *)optID;
+ (nullable OptionModel *)getOptionByID:(NSString *)optID;
+ (nullable NSString *)getOptionTitleByID:(NSString *)optionID;

/// Replace entire list at once (persists atomically)
+ (void)saveOptionsArray:(NSArray<OptionModel *> *)options;

/// MARK: - Dictionary bridge (for interoperability)
- (NSDictionary *)toDictionary;
+ (OptionModel *)fromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
