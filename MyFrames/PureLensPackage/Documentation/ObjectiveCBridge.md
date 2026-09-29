# Objective-C discovery bridge

`PureLensViewControllerFactory` lets an Objective-C owner present the SwiftUI
scanner without moving marketplace behavior into the package.

The delegate implements three responsibilities:

```objc
- (void)pureLensSearchImage:(NSData *)imageData
                contentType:(NSString *)contentType
                     animal:(NSDictionary *)animal
                  completion:(void (^)(NSArray *items, NSError *error))completion;

- (void)pureLensSearchMarketplace:(NSString *)category
                            animal:(NSDictionary *)animal
                        completion:(void (^)(NSArray *items, NSError *error))completion;

- (void)pureLensOpenDiscoveryItem:(NSDictionary *)item
                        completion:(void (^)(NSError *error))completion;
```

The host must map detected species to live taxonomy, reuse the existing Search
by Image service, return only compatible/displayable marketplace records, and
route taps through existing product, service, or medicine details.

`PureLensObjCConfiguration` retains its older endpoint and Pet Profile fields
for binary/source compatibility. The active discovery implementation does not
instantiate that compatibility configuration, call its endpoint, or consult its
profile fields. Existing legacy callers may remain source-compatible, while new
integrations must compose the independent discovery client instead of fabricating
or threading profile placeholders through the scanner.

Delegate completions must be called exactly once. Return partial category data
as soon as it is ready. Errors are category-scoped and must not be converted
into an all-or-nothing scanner failure.

The consumer app normally uses `PPPureLensHostPresenter`, which already composes
`PPPureLensDiscoveryBridge`, analytics, localization, consent and canonical
detail routing for both Home and Account.
