//
// UserModel.m
// Pure Pets
//
// Created by Mohammed Ahmed on 04/08/2024.
//

#import "CardModel.h"
#import "subSubKindModel.h"

#import "Language.h"

NSString *const _no_valueStringModel = @"لا يوجد";

// Keys for encoding/decoding
static NSString *const kIDKey = @"ID";
static NSString *const kdocID = @"docID";
static NSString *const kSubSubKindIDKey = @"subSubKindID";
static NSString *const kRingIDKey = @"RingID";
static NSString *const kSubKindKey = @"SubKind";
static NSString *const kSubKindItemsIDKey = @"subKindItemsID";
static NSString *const kSplitIDKey = @"splitID";
static NSString *const kAttributeKey = @"attribute";
static NSString *const kSexualKey = @"Sexual";
static NSString *const kBirdColorKey = @"birdColor";
static NSString *const kBirthDateKey = @"BirthDate";
static NSString *const kFatherRingIDKey = @"FatherRingID";
static NSString *const kMotherRingIDKey = @"MotherRingID";
static NSString *const kDnaKey = @"Dna";
static NSString *const kAdDescKey = @"AdDesc";
static NSString *const kAddedDateKey = @"AddedDate";
static NSString *const kCardLocationKey = @"CardLocation";
static NSString *const kLoanForUserKey = @"loanForUser";
static NSString *const kArchiveIDKey = @"archiveID";
static NSString *const kMasterArchiveIDKey = @"masterArchiveID";
static NSString *const kUserIDKey = @"UserID";
static NSString *const kImagesNamesKey = @"selectedImagesNames";
static NSString *const kcardInfoKey = @"cardInfo";
static NSString *const kIsDeletedKey = @"isDeleted";
static NSString *const kDeleteReasonKey = @"deleteReason";
static NSString *const kAttributeNoteKey = @"AttributeNote";
static NSString *const kCageIDKey = @"CageID";
static NSString *const kVideoNameKey = @"videoName";
static NSString *const kFilesArrayKey = @"FilesArray";
static NSString *const kisSold = @"isSold";
static NSString *const kcardSection = @"cardSection";
static NSString *const ksoldPrice = @"soldPrice";
static NSString *const klastUpdated = @"lastUpdated";
static NSString *const kageInfo = @"ageInfo";
//static NSString *const koldCardSection = @"oldCardSection";
@interface CardModel ()
{
    
}
@end

@implementation CardModel


#pragma mark - Image Items (Single Source of Truth)

- (NSArray<PetImageItem *> *)imageItems
{
    if (![self.FilesArray isKindOfClass:NSArray.class] ||
        self.FilesArray.count == 0) {
        return @[];
    }

    NSMutableArray<PetImageItem *> *items = [NSMutableArray array];

    for (FileModel *file in self.FilesArray) {

        // 0 = image (based on your existing logic)
        if (file.FileType != 0) continue;

        NSString *url = file.FileUrl;
        if (url.length == 0) continue;

        CGFloat width = 0;
        CGFloat height = 0;

        // If we already have a UIImage (edit / cache path)
        if ([file.imageFile isKindOfClass:UIImage.class]) {
            width = file.imageFile.size.width;
            height = file.imageFile.size.height;
        }

        PetImageItem *item =
        [PetImageItem itemWithURL:url
                            width:width
                           height:height
                         blurHash:nil];

        [items addObject:item];
    }

    return items.copy;
}


+ (NSMutableArray<CardModel *> *)fromSnapshot:(id)snapshotOrArray {
    NSMutableArray<CardModel *> *result = [NSMutableArray array];

    if (!snapshotOrArray || snapshotOrArray == (id)kCFNull) {
        return result;
    }

    // If it's a FIRQuerySnapshot, use its documents
    if ([snapshotOrArray isKindOfClass:NSClassFromString(@"FIRQuerySnapshot")]) {
        // FIRQuerySnapshot has a `documents` property
        NSArray *documents = [snapshotOrArray valueForKey:@"documents"];
        for (id doc in documents) {
            if ([doc respondsToSelector:@selector(documentID)] || [doc respondsToSelector:@selector(data)]) {
                @try {
                    CardModel *m = [[CardModel alloc] initWithSnapshot:doc];
                    if (m) [result addObject:m];
                }
                @catch (NSException *ex) {
                    NSLog(@"CardModel fromSnapshot: failed to init model for doc: %@, exception: %@", doc, ex);
                }
            }
        }
        return result;
    }

    // If it's a FIRDocumentSnapshot array
    if ([snapshotOrArray isKindOfClass:[NSArray class]]) {
        NSArray *docs = (NSArray *)snapshotOrArray;
        for (id doc in docs) {
            if ([doc respondsToSelector:@selector(documentID)] || [doc respondsToSelector:@selector(data)]) {
                @try {
                    CardModel *m = [[CardModel alloc] initWithSnapshot:doc];
                    if (m) [result addObject:m];
                }
                @catch (NSException *ex) {
                    NSLog(@"CardModel fromSnapshot: failed to init model for doc: %@, exception: %@", doc, ex);
                }
            }
        }
        return result;
    }

    // If the argument is a single FIRDocumentSnapshot
    if ([snapshotOrArray respondsToSelector:@selector(documentID)] && [snapshotOrArray respondsToSelector:@selector(data)]) {
        @try {
            CardModel *m = [[CardModel alloc] initWithSnapshot:snapshotOrArray];
            if (m) [result addObject:m];
        }
        @catch (NSException *ex) {
            NSLog(@"CardModel fromSnapshot: failed to init model for doc: %@, exception: %@", snapshotOrArray, ex);
        }
        return result;
    }

    // Unknown type: return empty array
    return result;
}


// بلو + اينو = البينو
// تركواز + لينو = كريمينو
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot {
    self = [super init];
    if (self) {
        
        self.AdDescString = kLang(@"_no_DescForCard");
        self.ID = snapshot.data[@"ID"];
        self.docID = snapshot.data[@"docID"];
        self.cardSection = [snapshot.data[kcardSection] integerValue];
        self.soldPrice = snapshot.data[ksoldPrice];
        //self.oldCardSection = [snapshot.data[koldCardSection] integerValue];
        self.subSubKindID = [snapshot.data[@"subSubKindID"] integerValue];
        self.RingID = snapshot.data[@"RingID"];
        self.SubKind = [snapshot.data[@"SubKind"] integerValue];
        self.subSubKindID =[snapshot.data[@"subSubKindID"] integerValue];
        self.subKindItemsID = snapshot.data[@"subKindItemsID"];
        self.splitID = snapshot.data[@"splitID"];
        self.attribute = [snapshot.data[@"attribute"] integerValue];
        self.Sexual = [snapshot.data[@"Sexual"] integerValue];
        self.birdColor = snapshot.data[@"birdColor"];
        
        FIRTimestamp *timestamp = snapshot.data[@"BirthDate"];
        if([timestamp.dateValue isKindOfClass:[NSDate class]])
            self.BirthDate =timestamp.dateValue;
        
        FIRTimestamp *timestamplastUpdated = snapshot.data[@"lastUpdated"];
        if([timestamplastUpdated.dateValue isKindOfClass:[NSDate class]])
            self.lastUpdated =timestamplastUpdated.dateValue;
        
        self.FatherRingID = snapshot.data[@"FatherRingID"];
        self.MotherRingID = snapshot.data[@"MotherRingID"];
        self.Dna = snapshot.data[@"Dna"];
        self.AdDesc = snapshot.data[@"AdDesc"];
        
        if([self.AdDesc isEqualToString:@"<null>"])
            self.AdDesc = @"no_value";
        
        //NSLog(@"self.AdDescself.AdDescself.AdDescself.AdDesc %@",self.AdDesc);
        self.AddedDate = snapshot.data[@"AddedDate"];
        self.CardLocation = snapshot.data[@"CardLocation"];
        self.loanForUser = snapshot.data[@"loanForUser"];
        self.archiveID = snapshot.data[@"archiveID"];
        if(snapshot.data[@"masterArchiveID"])
            self.masterArchiveID = snapshot.data[@"masterArchiveID"];
        else
            self.masterArchiveID = @"no_value";
        self.UserID = snapshot.data[@"UserID"];
        self.imagesNames = snapshot.data[@"selectedImagesNames"];
        self.cardInfo = [snapshot.data[@"cardInfo"] integerValue];
        self.isDeleted = [snapshot.data[@"isDeleted"] integerValue];
        self.deleteReason = snapshot.data[@"deleteReason"];
        self.AttributeNote = snapshot.data[@"AttributeNote"];
        self.CageID = snapshot.data[@"CageID"];
        
        self.isSold = [snapshot.data[@"isSold"] integerValue];
        if([snapshot.data[@"isSold"] integerValue] == 1)
            self.cardSection = CardSectionSold;
        
        
        self.videoName = snapshot.data[@"videoName"];
        
        NSArray<FileModel *> *unsortedFileModels = [NSArray<FileModel *> modelArrayWithClass:FileModel.class json:snapshot.data[@"FilesArray"]].mutableCopy;
        
        // Create an NSSortDescriptor to sort by the 'ID' property in ascending order
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"ID" ascending:YES];
        
        
        self.FilesArray= [[unsortedFileModels sortedArrayUsingDescriptors:@[sortDescriptor]] mutableCopy];
        
        //  NSLog(@"MODEL INIT FilesArray %@",[self.FilesArray modelToJSONString]);
        self.imagesNames = [[self.FilesArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.FileType == %ld", 0]] valueForKey:@"FileName"];
        self.imagesUrls = [self.FilesArray valueForKey:@"FirImageUrl"];
        
        if(self.BirthDate)
        {
            self.ageInfo = [self ageInfoFromBirthday:self.BirthDate adultHood:18];
        }
        
    }
    return self;
}


-(NSMutableArray<NSString *> *)imagesUrlsStrings
{
    NSMutableArray<NSString *> *imgArr = [[NSMutableArray<NSString *> alloc]init];
    for (NSString *urlStr in [self.FilesArray valueForKey:@"FileUrl"]) {
        [imgArr addObject:urlStr];
    }
    return imgArr;
}
-(NSMutableArray<NSURL *> *)imagesUrls
{
    NSMutableArray<NSURL *> *imgArr = [[NSMutableArray<NSURL *> alloc]init];
    for (NSString *urlStr in [self.FilesArray valueForKey:@"FileUrl"]) {
        [imgArr addObject:[NSURL URLWithString:urlStr]];
    }
    return imgArr;
}

-(NSString *)subKindString
{
    if([Language languageVal] == 0)
    {
        return  [[[MKM getSubKindArray:1] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", self.SubKind]] firstObject].SubKindNameEn;
    }
    else
    {
        return  [[[MKM getSubKindArray:1] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", self.SubKind]] firstObject].SubKindNameAr;
    }
    
}
-(SubKindModel *)subKind
{
    return  [[[MKM getSubKindArray:1] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", self.SubKind]] firstObject];
}

-(NSString *)subSubKindString
{
    
    if([Language languageVal] == 0)
    {
        return [[[self subKind].subSubKindArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", self.subSubKindID]] firstObject].nameEn;
    }
    else
    {
        return [[[self subKind].subSubKindArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", self.subSubKindID]] firstObject].nameAr;
    }
}
-(subSubKindModel *)subSubKind
{
    return [[[self subKind].subSubKindArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", self.subSubKindID]] firstObject];
}

-(NSMutableArray<subKindItemsModel *> *)subSubKindItemsArray
{
    return [self subSubKind].subKindItemsArray;
}

- (NSString *)CardTitle
{
    
    
    NSString *subKind;
    NSString *subSubKindID;

    if ([Language languageVal] == 0) {
        subKind = [self subKind].SubKindNameEn;
        subSubKindID = [self subSubKind].nameEn;
    } else {
        subKind = [self subKind].SubKindNameAr;
        subSubKindID = [self subSubKind].nameAr;
    }

    // Clean nulls
    if (!subKind || [subKind isEqualToString:@"(null)"]) subKind = @"";
    if (!subSubKindID || [subSubKindID isEqualToString:@"(null)"]) subSubKindID = @"";

    // Remove "no_value" and "لا يوجد"
    NSArray *emptyMarkers = @[@"no_value", @"لا يوجد", _no_valueStringModel, @"(null)", @"<null>"];

    #define CLEAN_STRING(str) \
        (([str isKindOfClass:[NSNull class]] || !str || [emptyMarkers containsObject:str]) ? @"" : str)

    subKind      = CLEAN_STRING(subKind);
    subSubKindID = CLEAN_STRING(subSubKindID);
    


    if ([subKind isEqualToString:subSubKindID]) {
        subSubKindID = @"";
    }

    NSString *Classification = [self ClassificationString];
    if (!Classification || [emptyMarkers containsObject:Classification]) Classification = @"";

    NSString *attribute = self.getBirdAttribute;
    if (!attribute || [emptyMarkers containsObject:attribute]) attribute = @"";

    if (self.attribute == 4 && self.AttributeNote.length) {
        attribute = self.AttributeNote;
    }

    NSString *birdColor = [NSString stringWithFormat:@"%@", self.birdColor];
    if (!birdColor || [emptyMarkers containsObject:birdColor]) birdColor = @"";

    Classification = CLEAN_STRING(Classification);
    attribute    = CLEAN_STRING(attribute);
    birdColor    = CLEAN_STRING(birdColor);
    
    
    // Build card string
    NSString *CardString;
    if ([subKind isEqualToString:@"طيور الحب"]) {
        CardString = [NSString stringWithFormat:@"%@ %@ %@ %@", subSubKindID, attribute, Classification, birdColor];
    } else {
        CardString = [NSString stringWithFormat:@"%@ %@ %@ %@ %@", subKind, subSubKindID, Classification, attribute, birdColor];
    }

    // Replace multiple spaces with single
    while ([CardString containsString:@"  "]) {
        CardString = [CardString stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    CardString = [CardString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    // ✅ Fallback if empty
    if (CardString.length == 0) {
        if (subKind.length) {
            CardString = subKind;
        } else {
            CardString = kLang(@"بدون عنوان"); // "No Title" fallback
        }
    }

    return CardString;
}



- (NSString *)ClassificationString
{
    
    NSMutableArray *selectedItems = [NSMutableArray new];
    NSArray *subKindItemsIDs = [self.subKindItemsID componentsSeparatedByString:@","];
    NSString *ST = @"no_value";
    for (NSString *ItemID in subKindItemsIDs) {
        if ([[[self subSubKindItemsArray] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject]) {
            NSString *ItemName;
            
            if([Language languageVal] == 0)
            {
                ItemName = [[[self subSubKindItemsArray] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject].itemNameEn;
            }
            else
            {
                ItemName = [[[self subSubKindItemsArray] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject].itemNameAr;
            }
            [selectedItems addObject:ItemName];
        }
    }
    if(selectedItems.count > 0)
        ST = [selectedItems componentsJoinedByString:@" "];

    if ([ST isEqualToString:@"no_value"]) {
        return _no_valueStringModel;
    } else {
        return ST;
    }
}


- (NSString *)AdDescString
{
    
    if ([self.AdDesc isEqualToString:@"no_value"] || [self.AdDesc isEqual:nil] || [self.AdDesc isEqual:NULL] || [self.AdDesc isEqualToString:@"<null>"]|| [self.AdDesc isEqualToString:@"(null)>"]) {
        
        return kLang(@"_no_DescForCard");
    } else {
        return self.AdDesc;
    }
}

- (NSString *)FatherRingIDString
{

    if ([_FatherRingID isEqual:nil] || [_FatherRingID isEqualToString:@"(null)"] || [_FatherRingID isEqualToString:@"no_value"]) {
        return _no_valueStringModel;
    } else {
        return [NSString stringWithFormat:@"%@", _FatherRingID];
    }
}

- (NSString *)MotherRingIDString
{
    NSString *ST = [NSString stringWithFormat:@"%@", _MotherRingID];

    if ([_MotherRingID isEqual:nil] || [_MotherRingID isEqualToString:@"(null)"] || [_MotherRingID isEqualToString:@"no_value"]) {
        return @"";
    } else {
        return ST;
    }
}

- (NSString *)splitIDString
{
    NSString *ST = [NSString stringWithFormat:@"%@", _splitID];

    if ([ST isEqualToString:@"no_value"] || [ST isEqualToString:@""]) {
        return _no_valueStringModel;
    } else {
        return [self getSubItemsNamesFromIds:ST];
    }
}

-(NSString *)getSubItemsNamesFromIds:(NSString *)IDs
{
    NSArray *subKindItemsIDs = [IDs componentsSeparatedByString:@","];
    NSString *selectedItemsDtring = @"";
    for (NSString *ItemID in subKindItemsIDs) {
        if ([[[self subSubKindItemsArray] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject]) {
            NSString *ItemName ;
            if([Language languageVal] == 0)
            {
                ItemName = [[[self subSubKindItemsArray] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject].itemNameEn;
            }
            else
            {
                ItemName = [[[self subSubKindItemsArray] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject].itemNameAr;
            }
            
            
            selectedItemsDtring = [NSString stringWithFormat:@"%@ %@",selectedItemsDtring,ItemName];
        }
    }
    return selectedItemsDtring;
}


- (NSArray<subKindItemsModel *> *)getsubKindItemsArray; {
    return [NSArray<subKindItemsModel *> modelArrayWithClass:subKindItemsModel.class json:self.subKindItemsID];
}



- (NSString *)getBirdAttribute
{
    switch (self.attribute) {
        case 1:
            return kLang(@"attributeValue_blue");

            break;

        case 2:
            return kLang(@"attributeValue_Green");

            break;

        case 3:
            return kLang(@"attributeValue_Trkqaz");

            break;

        case 4:
            return kLang(@"attributeValue_other");

            break;

        default:{
            //return @"no_value";
            return _no_valueStringModel;

            break;
        }
    }
}

- (NSString *)attributeValue {
    switch (self.attribute) {
        case 1:
            return kLang(@"attributeValue_blue");

            break;

        case 2:
            return kLang(@"attributeValue_Green");

            break;

        case 3:
            return kLang(@"attributeValue_Trkqaz");

            break;

        case 4:
            return kLang(@"attributeValue_other");

            break;

        default:{
            return kLang(@"no_value");

            break;
        }
    }
}


-(NSString *)SexualTXT
{
    return self.getBirdSexual;
}

// PURE VALES
- (NSString *)getBirdSexual
{
    switch (self.Sexual) {
        case 1:
            return kLang(@"Male");

            break;

        case 2:
            return kLang(@"Female");

            break;

        default:
            return kLang(@"no_value");

            break;
    }
}


-(id)formValue
{
    return self;
}

- (nonnull NSString *)formDisplayText {
    return self.RingID;
}


- (void)updateCardWithID:(NSString *)cardID
         updateDictionary:(NSDictionary *)updateDict
               completion:(void(^)(NSError *error))completion {


    if (!cardID || cardID.length == 0) {
        NSError *error = [NSError errorWithDomain:@"UPDATE ----->>> CardModelError"
                                             code:100
                                         userInfo:@{NSLocalizedDescriptionKey : @"Card ID cannot be empty."}];
        if (completion) {
            completion(error);
        }
        return;
    }
    
    if (!updateDict || updateDict.count == 0) {
        NSError *error = [NSError errorWithDomain:@"UPDATE ----->>> CardModelError"
                                             code:101
                                         userInfo:@{NSLocalizedDescriptionKey : @"Update dictionary cannot be empty."}];
        if (completion) {
            completion(error);
        }
        return;
    }



    // Get a reference to the Firestore database.
    FIRFirestore *db = [FIRFirestore firestore];

    // Reference to the 'cards' collection.
    FIRCollectionReference *cardsCollection = [db collectionWithPath:@"CardsCol"];

    // Reference to the document using the card ID.
    FIRDocumentReference *cardDocument = [cardsCollection documentWithPath:cardID];

    // Perform the update.
    [cardDocument updateData:updateDict completion:^(NSError * _Nullable error) {

        if (error) {
            NSLog(@"UPDATE ----->>> Error updating card with ID: %@, error: %@", cardID, error);
            if (completion) {
                completion(error);
            }

        } else {
            NSLog(@"UPDATE ----->>> Card with ID: %@ successfully updated!", cardID);
            if (completion) {
                completion(nil);
            }
        }
    }];
}

#pragma mark - Encoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.docID forKey:kdocID];
    [coder encodeObject:self.ID forKey:kIDKey];
    [coder encodeInteger:self.cardSection forKey:kcardSection];
    [coder encodeObject:self.soldPrice forKey:ksoldPrice];
    //[coder encodeInteger:self.oldCardSection forKey:koldCardSection];
    [coder encodeInteger:self.subSubKindID forKey:kSubSubKindIDKey];
    [coder encodeObject:self.RingID forKey:kRingIDKey];
    [coder encodeInteger:self.SubKind forKey:kSubKindKey];
    [coder encodeObject:self.subKindItemsID forKey:kSubKindItemsIDKey];
    [coder encodeObject:self.splitID forKey:kSplitIDKey];
    [coder encodeInteger:self.attribute forKey:kAttributeKey];
    [coder encodeInteger:self.Sexual forKey:kSexualKey];
    [coder encodeObject:self.birdColor forKey:kBirdColorKey];
    [coder encodeObject:self.BirthDate forKey:kBirthDateKey];
    [coder encodeObject:self.lastUpdated forKey:klastUpdated];
    [coder encodeObject:self.FatherRingID forKey:kFatherRingIDKey];
    [coder encodeObject:self.MotherRingID forKey:kMotherRingIDKey];
    [coder encodeObject:self.Dna forKey:kDnaKey];
    [coder encodeObject:self.AdDesc forKey:kAdDescKey];
    [coder encodeObject:self.AddedDate forKey:kAddedDateKey];
    [coder encodeObject:self.CardLocation forKey:kCardLocationKey];
    [coder encodeObject:self.loanForUser forKey:kLoanForUserKey];
    [coder encodeObject:self.archiveID forKey:kArchiveIDKey];
    [coder encodeObject:self.masterArchiveID forKey:kMasterArchiveIDKey];
    [coder encodeObject:self.UserID forKey:kUserIDKey];
    [coder encodeObject:self.imagesNames forKey:kImagesNamesKey];
    [coder encodeInteger:self.cardInfo forKey:kcardInfoKey];
    [coder encodeInteger:self.isDeleted forKey:kIsDeletedKey];
    [coder encodeObject:self.deleteReason forKey:kDeleteReasonKey];
    [coder encodeObject:self.AttributeNote forKey:kAttributeNoteKey];
    [coder encodeObject:self.CageID forKey:kCageIDKey];
    [coder encodeObject:self.videoName forKey:kVideoNameKey];
    [coder encodeObject:self.FilesArray forKey:kFilesArrayKey];
    [coder encodeInteger:self.isSold forKey:kisSold];
    [coder encodeObject:self.ageInfo forKey:kageInfo];

}

#pragma mark - Decoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _ID = [coder decodeObjectForKey:kIDKey];
        _docID = [coder decodeObjectForKey:kdocID];
        _cardSection = [coder decodeIntegerForKey:kcardSection];
        _soldPrice = [coder decodeObjectForKey:ksoldPrice];
        //_oldCardSection = [coder decodeIntegerForKey:koldCardSection];
        _subSubKindID = [coder decodeIntegerForKey:kSubSubKindIDKey];
        _RingID = [coder decodeObjectForKey:kRingIDKey];
        _SubKind = [coder decodeIntegerForKey:kSubKindKey];
        _subKindItemsID = [coder decodeObjectForKey:kSubKindItemsIDKey];
        _splitID = [coder decodeObjectForKey:kSplitIDKey];
        _attribute = [coder decodeIntegerForKey:kAttributeKey];
        _Sexual = [coder decodeIntegerForKey:kSexualKey];
        _birdColor = [coder decodeObjectForKey:kBirdColorKey];
        _BirthDate = [coder decodeObjectForKey:kBirthDateKey];
        _lastUpdated = [coder decodeObjectForKey:klastUpdated];

        _FatherRingID = [coder decodeObjectForKey:kFatherRingIDKey];
        _MotherRingID = [coder decodeObjectForKey:kMotherRingIDKey];
        _Dna = [coder decodeObjectForKey:kDnaKey];
        _AdDesc = [coder decodeObjectForKey:kAdDescKey];
        _AddedDate = [coder decodeObjectForKey:kAddedDateKey];
        _CardLocation = [coder decodeObjectForKey:kCardLocationKey];
        _loanForUser = [coder decodeObjectForKey:kLoanForUserKey];
        _archiveID = [coder decodeObjectForKey:kArchiveIDKey];
        _masterArchiveID = [coder decodeObjectForKey:kMasterArchiveIDKey];
        _UserID = [coder decodeObjectForKey:kUserIDKey];
        _imagesNames = [coder decodeObjectForKey:kImagesNamesKey];
        _cardInfo = [coder decodeIntegerForKey:kcardInfoKey];
        _isDeleted = [coder decodeIntegerForKey:kIsDeletedKey];
        _deleteReason = [coder decodeObjectForKey:kDeleteReasonKey];
        _AttributeNote = [coder decodeObjectForKey:kAttributeNoteKey];
        _CageID = [coder decodeObjectForKey:kCageIDKey];
        _videoName = [coder decodeObjectForKey:kVideoNameKey];
        _FilesArray = [coder decodeObjectForKey:kFilesArrayKey];
        _isSold = [coder decodeIntegerForKey:kisSold];
        _cardSection = [coder decodeIntegerForKey:kcardSection];
        _ageInfo = [coder decodeObjectForKey:kageInfo];

    }
    return self;
}



// Function to get the CardLocation enum value from a string.
CardLocation getCardLocationValueFromString(NSString *string) {
    if ([string isEqualToString:@"Cards"]) {
        return CardLocationCards;
    } else if ([string isEqualToString:@"cage"]) {
        return CardLocationCage;
    } else if ([string isEqualToString:@"archive"]) {
        return CardLocationArchive;
    } else {
        // Handle the case where the string doesn't match any known location.
        // You might want to return a default value or raise an exception.
        NSLog(@"Error: Unknown card location string: %@", string);
        return CardLocationCards; // Default to CardLocationCards
    }
}

// Function to get the string representation of a CardLocation enum value.
NSString *getCardStringFromValue(CardLocation location) {
    switch (location) {
        case CardLocationCards:
            return @"Cards";
        case CardLocationCage:
            return @"cage";
        case CardLocationArchive:
            return @"archive";
        default:
            // Handle the case where the enum value is invalid.
            // You might want to return a default value or raise an exception.
            NSLog(@"Error: Unknown card location value: %ld", (long)location);
            return @"Cards"; // Default to "Cards"
    }
}


+(CardModel *)getCardForID:(NSString *)cardID;
{
    return [[AppData.AllCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", cardID]] firstObject];
}


- (AgeInfoModel *)ageInfoFromBirthday:(NSDate *)birthdate
                           adultHood:(NSInteger)adultHood {
    
    if (!birthdate) {
        return [[AgeInfoModel alloc] initWithYears:0
                                            months:0
                                              days:0
                                       totalMonths:0
                                           isAdult:NO
                                         ageString:@"0"
                                       readyString:@""];
    }

    NSDate *today = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];

    NSDateComponents *components =
    [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                fromDate:birthdate
                  toDate:today
                 options:0];

    NSInteger years = components.year;
    NSInteger months = components.month;
    NSInteger days = components.day;
    NSInteger totalMonths = years * 12 + months;

    BOOL isAdult = totalMonths >= adultHood;
    NSString *readyString = isAdult ? kLang(@"readyToMarrage") : @"";

    BOOL isArabic = [[Language currentLanguageCode] isEqualToString:@"ar"];
    NSString *ageString = @"";

    if (years > 0 && months > 0) {
        ageString = isArabic
        ? [NSString stringWithFormat:@"%ld س %ld ش", (long)years, (long)months]
        : [NSString stringWithFormat:@"%ldy %ldm", (long)years, (long)months];
        
    } else if (years > 0) {
        ageString = isArabic
        ? [NSString stringWithFormat:@"%ld سنة", (long)years]
        : [NSString stringWithFormat:@"%ldy", (long)years];
        
    } else if (months > 0) {
        ageString = isArabic
        ? [NSString stringWithFormat:@"%ld شهر", (long)months]
        : [NSString stringWithFormat:@"%ld month%@", (long)months, months > 1 ? @"s" : @""];
        
    } else if (days > 0) {
        ageString = isArabic
        ? [NSString stringWithFormat:@"%ld أيام", (long)days]
        : [NSString stringWithFormat:@"%ld day%@", (long)days, days > 1 ? @"s" : @""];
        
    } else {
        ageString = isArabic ? @"اليوم" : @"today";
    }

    return [[AgeInfoModel alloc] initWithYears:years
                                        months:months
                                          days:days
                                   totalMonths:totalMonths
                                       isAdult:isAdult
                                     ageString:ageString
                                   readyString:readyString];
}


@end









@implementation AgeInfoModel

- (instancetype)initWithYears:(NSInteger)years
                        months:(NSInteger)months
                          days:(NSInteger)days
                   totalMonths:(NSInteger)totalMonths
                       isAdult:(BOOL)isAdult
                     ageString:(NSString *)ageString
                   readyString:(NSString *)readyString {
    self = [super init];
    if (self) {
        _years = years;
        _months = months;
        _days = days;
        _totalMonths = totalMonths;
        _isAdult = isAdult;
        _ageString = [ageString copy];
        _readyString = [readyString copy];
    }
    return self;
}

@end
