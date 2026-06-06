// MainControllerHelper.m
#import "MainControllerHelper.h"
#import <objc/runtime.h>

@implementation MainController (MainControllerHelper)


#pragma mark - PPS Search View

- (PPS *)searchView {
    return objc_getAssociatedObject(self, @selector(searchView));
}

- (void)setSearchView:(PPS *)searchView {
    objc_setAssociatedObject(self,
                             @selector(searchView),
                             searchView,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Floating background (emulates iOS 26 look)
- (void)pp_configureFloatingBackgroundForAppearance:(UITabBarAppearance *)appearance {
    if (@available(iOS 26.0, *)) {
        [appearance configureWithTransparentBackground];
    } else if (@available(iOS 13.0, *)) {
        //UITabBarAppearance *appearance = [UITabBarAppearance new];
        [appearance configureWithTransparentBackground];
        
        
    } else {
        appearance.backgroundImage = [UIImage new];
        appearance.shadowImage = [UIImage new];
    }
}

- (void)configureAppearance {
    // WHY: Make selected title invisible while keeping normal visible.
    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [UITabBarAppearance new];
        [self pp_configureFloatingBackgroundForAppearance:appearance];
        
        NSDictionary<NSAttributedStringKey, id> *clearSelectedTitle =
        @{ NSForegroundColorAttributeName: [AppPrimaryTextClr colorWithAlphaComponent:1.0] ,
           NSFontAttributeName: [GM boldFontWithSize:12]};
        
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;
        
        NSDictionary<NSAttributedStringKey, id> *normalTitle =
        @{ NSForegroundColorAttributeName: UIColor.secondaryLabelColor ,
           NSFontAttributeName: [GM boldFontWithSize:12]};
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalTitle;
        
        appearance.shadowColor = UIColor.clearColor;          // 🔴 remove top line
             appearance.backgroundEffect = nil;
        
        // 🫁 Add breathing space between icon and title
        UIOffset titleOffset = UIOffsetMake(0, 4);

        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = titleOffset;
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = titleOffset;

        appearance.inlineLayoutAppearance.normal.titlePositionAdjustment = titleOffset;
        appearance.inlineLayoutAppearance.selected.titlePositionAdjustment = titleOffset;

        appearance.compactInlineLayoutAppearance.normal.titlePositionAdjustment = titleOffset;
        appearance.compactInlineLayoutAppearance.selected.titlePositionAdjustment = titleOffset;
        
        
        self.mainTabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.mainTabBar.scrollEdgeAppearance = appearance;
        }
        
    } else {
        NSDictionary<NSAttributedStringKey, id> *clearSelectedTitle =
        @{ NSForegroundColorAttributeName: UIColor.clearColor };
        [[UITabBarItem appearance] setTitleTextAttributes:clearSelectedTitle forState:UIControlStateSelected];
    }
}
- (void)applyTabBarShadowToContainer:(UIView *)container
{
    if (!container) {
        return;
    }

    container.layer.cornerRadius = 28;
    container.layer.masksToBounds = NO;

    [container pp_setShadowColor:[UIColor blackColor]];
    container.layer.shadowOpacity = 0.10;
    container.layer.shadowRadius = 20;
    container.layer.shadowOffset = CGSizeMake(0, 8);

    container.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:container.bounds
                                    cornerRadius:28].CGPath;
}
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    NSLog(@"Selected tab: %@ (tag:%ld)", item.title, (long)item.tag);
    
    [self topSegChanged:(long)item.tag];
}



- (void)updateChildIsDeletedWithChildID:(NSString *)childID
                                 CageID:(NSString *)cageID
                              isDeleted:(NSInteger)isDeletedValue
{
    if (!childID.length || !cageID.length) return;

    FIRDocumentReference *childRef =
    [[[[[AppManager sharedInstance].dF
           collectionWithPath:@"CagesCol"]
          documentWithPath:cageID]
      collectionWithPath:@"ChildsCol"] documentWithPath:childID];

    [childRef updateData:@{ @"isDeleted": @(isDeletedValue) }
              completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Failed to update child isDeleted: %@", error);
        }
    }];
}

 

- (void)updateIsDeletedForArchiveID:(NSString *)archiveID
             andArchiveDetailsID:(NSString *)detailID
                     withNewValue:(NSInteger)newValue
                       completion:(void (^)(NSError * _Nullable))completion
{
    FIRDocumentReference *ref =
    [[[[[FIRFirestore firestore]
           collectionWithPath:@"ArchiveCol"]
          documentWithPath:archiveID]
         collectionWithPath:@"ArchiveDetailsCol"] documentWithPath:detailID];

    [ref updateData:@{ @"isDeleted": @(newValue) }
          completion:completion];
}

-(void)updateIsDeletedForCardID:(NSString *)cardID isDeleted:(NSInteger)isDeleted completion:(void (^_Nullable)(NSError * _Nullable error))completion
{
    FIRDocumentReference *CardRef = [[[AppManager sharedInstance].dF collectionWithPath:@"CardsCol"] documentWithPath:cardID];//cardData.ID
    [CardRef updateData:@{ @"isDeleted":@(isDeleted), @"deleteReason": @"" }
             completion:^(NSError *_Nullable error) {
        if (error != nil) {
            NSLog(@"Error removing document: %@", error);
            completion(error);
        } else {
            NSLog(@"Document successfully removed CardRef !");
            completion(nil);
        }
    }];
}

- (void)showViewer:(CardModel *)cardData
{
    if (!cardData) {
        return;
    }

    if (self.presentedViewController && !self.presentedViewController.isBeingDismissed) {
        return;
    }

    viewDataVC *add = [viewDataVC new];
    add.cardModel = cardData;
    PPNavigationController *nav = [[PPNavigationController alloc]initWithRootViewController:add];
    [PPFunc presentSheetFrom:self sheetVC:nav detentStyle:PPSheetDetentStyle80];
}

- (void)deleteEditArchiveOptions:(long)index
                     ArchiveData:(ArchiveModel *)ArchiveData
                        cellView:(UIView *)cellView
                   cellIndexPath:(NSIndexPath *)cellIndexPath
{
    NSLog(@"deleteEditArchiveOptions");

    // 1️⃣ QR
    if (index == 2) {
        [self QrForID:ArchiveData.ID];
        return;
    }

    // 2️⃣ Edit archive title
    if (index == 0) {

        [PPAlertHelper showTextFieldAlertIn:self
                                      title:kLang(@"EditArchive")
                                   subtitle:kLang(@"EnterNewArchiveName")
                                placeholder:kLang(@"EnterNewArchiveName")
                                initialText:ArchiveData.archiveTitle ?: @""
                                confirmText:kLang(@"edit")
                                 cancelText:kLang(@"cancel")
                                  completion:^(NSString * _Nullable text, BOOL didConfirm)
        {
            if (!didConfirm || text.length == 0) return;

            [PPHUD showLoading];

            NSDictionary *update =
            @{
                @"archiveTitle": text,
                @"ModifyDate": [NSDate date]
            };

            [[[[FIRFirestore firestore]
              collectionWithPath:@"ArchiveCol"]
             documentWithPath:ArchiveData.ID]
            updateData:update
            completion:^(NSError * _Nullable error)
            {
                [PPHUD dismiss];
                if (error) {
                    NSLog(@"Archive rename error: %@", error);
                    return;
                }

                [self.dataManager showSnakBar:kLang(@"EditSuccess")
                                    withColor:[GM appPrimaryColor]
                                  andDuration:3
                                containerView:self.view];

                ArchiveData.archiveTitle = text;
                [self applySnapshotAnimated:YES];
            }];
        }];

        return;
    }

    // 3️⃣ Delete archive (SOFT DELETE – manager only)
    if (index == 1) {

        NSString *desc =
        (ArchiveData.detailsCount == 0)
        ? kLang(@"ArchivewikkDeleteSure?")
        : kLang(@"ArchiveNotEmpty");

        [PPAlertHelper showConfirmationIn:self
                                    title:kLang(@"ArchiveDeleteTitle")
                                 subtitle:desc
                            confirmButton:kLang(@"yes")
                             cancelButton:kLang(@"no")
                                     icon:PPSYSImage(@"trash")
                             confirmBlock:^(NSString * _Nullable text, BOOL didConfirm)
        {
            if (!didConfirm) return;

            [PPHUD showLoading];

            [[ArchivesManager shared]
             softDeleteArchiveByID:ArchiveData.ID
             completion:^(NSError * _Nullable error)
            {
                [PPHUD dismiss];

                if (error) {
                    NSLog(@"Archive delete failed: %@", error);
                    return;
                }

                [self.dataManager showSnakBar:kLang(@"ArchiveDeleted")
                                    withColor:[GM appPrimaryColor]
                                  andDuration:3
                                containerView:self.view];

                // Update local source and UI
                self.UserArchivesDocs = AppData.UserArchivesDocs;
                [self applySnapshotAnimated:YES];
            }];

        } cancelBlock:^{}];
    }
}

-(void)DetaildsFromTrash:(CardModel *)cardData
{
    [self showViewer:cardData];
}

- (void)cellSectionChanged {
    // Default state
    [PPHUD dismiss];
    [self scrollCollectionViewToTopAnimated:NO];
    self.FilterBTN.enabled = NO;
   
    switch (self.cellSection) {
            
        case CellSectionCards: {
            self.userCardsArray = AppData.UserCardsDocs;
            self.allCardsArray  = AppData.AllCardsDocs;
            //NSLog(@"allCardsArray %@",self.allCardsArray);
            [self applySnapshotAnimated:YES];
            
            [self.collectionView emptyViewConfigerBlock:^(FOREmptyAssistantConfiger *configer) {
                configer.emptyTitle = kLang(@"cardsEmptyTitle");
                configer.emptySubtitle = kLang(@"cardsEmptyDesc");
                configer.emptyImage = [UIImage imageNamed:@"empty-boxx"];
                configer.allowScroll = YES;
                [PPHUD dismiss];
            }];
            
            [UIView animateWithDuration:0.3 animations:^{
                self.FilterBTN.enabled = YES;
               // self.bottomBg.image = [UIImage imageNamed:@"dogCus.fill"];
            }];
            break;
        }
            
        case CellSectionCage: {
            self.CagedataSource = AppData.UserCaGeDocs;
            //NSLog(@"CagedataSource %@",self.CagedataSource);
            [self applySnapshotAnimated:YES];
           
            
            [self.collectionView emptyViewConfigerBlock:^(FOREmptyAssistantConfiger *configer) {
                configer.emptyTitle = kLang(@"boxEmptyTitle");
                configer.emptySubtitle = kLang(@"boxEmptyDesc");
                configer.emptyImage = [UIImage imageNamed:@"empty-boxx"];
                configer.allowScroll = YES;
                [PPHUD dismiss];
            }];
            
            [UIView animateWithDuration:0.3 animations:^{
                self.FilterBTN.enabled = YES;
                //self.bottomBg.image = [UIImage imageNamed:@"love-birdsCus.fill"];
            }];
            break;
        }
            
        case CellSectionArchive: {
            self.UserArchivesDocs = AppData.UserArchivesDocs;
           // NSLog(@"archiveArray %@",self.UserArchivesDocs);
            [self applySnapshotAnimated:YES];
            [PPHUD dismiss];
            
            [self.collectionView emptyViewConfigerBlock:^(FOREmptyAssistantConfiger *configer) {
                configer.emptyTitle = kLang(@"archiveEmptyTitle");
                configer.emptySubtitle = kLang(@"archiveEmptyDesc");
                configer.emptyImage = [UIImage imageNamed:@"empty-boxx"];
                configer.allowScroll = YES;
                [PPHUD dismiss];
            }];
            
            [UIView animateWithDuration:0.3 animations:^{
                self.FilterBTN.enabled = YES;
               // self.bottomBg.image = [UIImage imageNamed:@"archiveCus.fill"];
            }];
            break;
        }
            
        case CellSectionTrash: {
            self.trachArray = AppData.trashDocs.mutableCopy;
            //NSLog(@"trachArray %@", self.trachArray);
            [self applySnapshotAnimated:YES];
            [PPHUD dismiss];
            
            [self.collectionView emptyViewConfigerBlock:^(FOREmptyAssistantConfiger *configer) {
                configer.emptyTitle = kLang(@"trashEmptyTitle");
                configer.emptySubtitle = kLang(@"trashEmptyDesc");
                configer.emptyImage = [UIImage imageNamed:@"empty-boxx"];
                configer.allowScroll = YES;
                [PPHUD dismiss];
            }];
            
            [UIView animateWithDuration:0.3 animations:^{
                self.FilterBTN.enabled = YES;
                //self.bottomBg.image = [UIImage imageNamed:@"deleteCus.fill"];
            }];
            break;
        }
            
        case CellSectionSalesBuyer: {
            self.SalesBuyerArr = AppData.BuyerArray;
            //NSLog(@"SalesBuyerArr %@",self.SalesBuyerArr);
            [self applySnapshotAnimated:YES];
            [PPHUD dismiss];
            
            [self.collectionView emptyViewConfigerBlock:^(FOREmptyAssistantConfiger *configer) {
                configer.emptyTitle = kLang(@"salesEmptyTitle");
                configer.emptySubtitle = kLang(@"salesEmptyDesc");
                configer.emptyImage = [UIImage imageNamed:@"empty-boxx"];
                configer.allowScroll = YES;
                [PPHUD dismiss];
            }];
            [UIView animateWithDuration:0.3 animations:^{
                self.FilterBTN.enabled = YES;
                //self.bottomBg.image = [UIImage imageNamed:@"hotSalee.fill"];
            }];
            break;
        }
            
        default: {
            // Default fallback
            self.userCardsArray = AppData.UserCardsDocs;
            self.allCardsArray  = AppData.AllCardsDocs;
            //NSLog(@"allCardsArray %@",self.userCardsArray);
            [self applySnapshotAnimated:YES];
            [self.collectionView emptyViewConfigerBlock:^(FOREmptyAssistantConfiger *configer) {
                configer.emptyTitle = kLang(@"cardsEmptyTitle");
                configer.emptySubtitle = kLang(@"cardsEmptyDesc");
                configer.emptyImage = [UIImage imageNamed:@"empty-boxx"];
                configer.allowScroll = YES;
                [PPHUD dismiss];
            }];
            [UIView animateWithDuration:0.3 animations:^{
                self.FilterBTN.enabled = YES;
            }];
            break;
        }
    }
    
    // ✅ Configure filter button behavior
    if (self.cellSection == CellSectionCage) {
        [self.FilterBTN setImage:[UIImage systemImageNamed:@"arrow.up.arrow.down"] forState:UIControlStateNormal];
        [self.FilterBTN removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [self.FilterBTN addTarget:self action:@selector(sortCagesNames) forControlEvents:UIControlEventTouchUpInside];
    } else {
        [self.FilterBTN setImage:[UIImage systemImageNamed:@"line.3.horizontal.decrease"] forState:UIControlStateNormal];
        [self.FilterBTN removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [self.FilterBTN addTarget:self action:@selector(showFilter:) forControlEvents:UIControlEventTouchUpInside];
    }
}





- (void)sortCagesNames {
    self.sort = [[NSUserDefaults standardUserDefaults] integerForKey:@"SortType"];
    if(self.sort == SortAsc)
    {
        [[NSUserDefaults standardUserDefaults] setInteger:SortDesc forKey:@"SortType"];
        [self sortDesc];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setInteger:SortAsc forKey:@"SortType"];
        [self sortAsc];
    }
}


// MARK: - Sort and Filetr
// MARK: Sort Ascending

- (void)sortAsc {
    NSSortDescriptor *sortDescriptorAscending = [[NSSortDescriptor alloc] initWithKey:@"CageName" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    [self.CagedataSource sortUsingDescriptors:@[sortDescriptorAscending]];
    [self applySnapshotAnimated:YES];
}

// MARK: Sort Descending
- (void)sortDesc {
    NSSortDescriptor *sortDescriptorDescending = [[NSSortDescriptor alloc] initWithKey:@"CageName" ascending:NO selector:@selector(localizedCaseInsensitiveCompare:)];
    [self.CagedataSource sortUsingDescriptors:@[sortDescriptorDescending]];
    [self applySnapshotAnimated:YES];
}



-(void) restoreCurrentDataSource {
    self.userCardsArray = AppData.UserCardsDocs;
    self.CagedataSource = AppData.UserCaGeDocs;
    self.UserArchivesDocs = AppData.UserArchivesDocs;
    self.SalesBuyerArr = AppData.BuyerArray;
    self.allCardsArray = AppData.AllCardsDocs;
}

- (void)showParentData:(NSString *)ParentID
{
    if([ParentID isEqualToString:@"sold"])
        return;
    
    CardModel *ParentClass = [[AppData.UserCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", ParentID]] firstObject];
    NSLog(@"showParentData ParentID %@  \n ParentClass: %@  \n ParentClass: %@", ParentID, ParentClass.ID, ParentClass.imagesNames);
    [self showViewer:ParentClass];
}


-(void)FliterDependOnSubKindID:(NSInteger)subKind
{
    if (self.cellSection == CellSectionCards) {
        NSPredicate *predicates =
        [NSCompoundPredicate orPredicateWithSubpredicates:
         @[[NSPredicate predicateWithFormat:@"SELF.SubKind == %ld", subKind]]];
        
        self.userCardsArray = [AppData.UserCardsDocs filteredArrayUsingPredicate:predicates].mutableCopy;
        [self applySnapshotAnimated:YES];
    }
}


- (void)searchStringWithBarCode:(NSString *)searchedString
{
    
    //return;
    if (self.cellSection == CellSectionCards) {
        NSPredicate *predicates = [NSCompoundPredicate orPredicateWithSubpredicates:
                                   @[
            [NSPredicate predicateWithFormat:@"SELF.ID == %@",
             [NSString stringWithFormat:@"%@", searchedString]],
            [NSPredicate predicateWithFormat:@"SELF.CardTitle like[cd] %@",
             [NSString stringWithFormat:@"*%@*", searchedString]]
            
        ]];
        
        self.userCardsArray = [AppData.UserCardsDocs filteredArrayUsingPredicate:predicates].mutableCopy;
        if(self.userCardsArray.count == 0)
        {
            [[AppManager sharedInstance] showSnakBar:kLang(@"no_data_barcode") withColor:[GM appPrimaryColor] andDuration:5 containerView:self.collectionView];
            //  [self restoreCurrentDataSource];
        }
        [self applySnapshotAnimated:YES];
        
    } else if (self.cellSection == CellSectionTrash) {
    } else if (self.cellSection == CellSectionArchive) {
        NSPredicate *predicates = [NSCompoundPredicate orPredicateWithSubpredicates:
                                   @[
            [NSPredicate predicateWithFormat:@"SELF.ID like[cd] %@",
             [NSString stringWithFormat:@"*%@*", searchedString]]
        ]];
        
        self.UserArchivesDocs = [AppData.UserArchivesDocs filteredArrayUsingPredicate:predicates].mutableCopy;
        if(self.UserArchivesDocs.count == 0)
        {
            [[AppManager sharedInstance] showSnakBar:kLang(@"no_data_barcode") withColor:[GM appPrimaryColor] andDuration:5 containerView:self.collectionView];
            //[self restoreCurrentDataSource];
        }
        
        [self applySnapshotAnimated:YES];
    } else if (self.cellSection == CellSectionSalesBuyer) {
        NSPredicate *predicates = [NSCompoundPredicate orPredicateWithSubpredicates:
                                   @[
            [NSPredicate predicateWithFormat:@"SELF.buyerName like[cd] %@",
             [NSString stringWithFormat:@"*%@*", searchedString]],
            [NSPredicate predicateWithFormat:@"SELF.birdID like[cd] %@",
             [NSString stringWithFormat:@"*%@*", searchedString]],
            [NSPredicate predicateWithFormat:@"SELF.buyerMobile like[cd] %@",
             [NSString stringWithFormat:@"*%@*", searchedString]],
            [NSPredicate predicateWithFormat:@"SELF.UserID like[cd] %@",
             [NSString stringWithFormat:@"*%@*", searchedString]]
        ]];
        
        self.SalesBuyerArr = [AppData.BuyerArray filteredArrayUsingPredicate:predicates].mutableCopy;
        if(self.SalesBuyerArr.count == 0)
        {
            [[AppManager sharedInstance] showSnakBar:kLang(@"no_data_barcode") withColor:[GM appPrimaryColor] andDuration:5 containerView:self.collectionView];
            //  [self restoreCurrentDataSource];
        }
        [self applySnapshotAnimated:YES];
    }
    else {
        NSPredicate *predicates = [NSCompoundPredicate orPredicateWithSubpredicates:
                                   @[
            [NSPredicate predicateWithFormat:@"SELF.ID like[cd] %@",
             [NSString stringWithFormat:@"*%@*", searchedString]],
            [NSPredicate predicateWithFormat:@"SELF.FatherRingID like[cd] %@",
             [NSString stringWithFormat:@"*%@*", searchedString]],
            [NSPredicate predicateWithFormat:@"SELF.MotherRingID like[cd] %@",
             [NSString stringWithFormat:@"*%@*", searchedString]]
        ]];
        
        self.CagedataSource = [AppData.UserCaGeDocs filteredArrayUsingPredicate:predicates].mutableCopy;
        if(self.CagedataSource.count == 0)
        {
            [[AppManager sharedInstance] showSnakBar:kLang(@"no_data_barcode") withColor:[GM appPrimaryColor] andDuration:5 containerView:self.collectionView];
            //  [self restoreCurrentDataSource];
        }
        [self applySnapshotAnimated:YES];
    }
    [UIView animateWithDuration:0.3 animations:^{
        self.refershArrow.alpha = 1;
    }];
    NSLog(@"End search Using Predicates ");
}
- (IBAction)showAllDataBTN:(id)sender; {
    [self restoreCurrentDataSource];
    [self applySnapshotAnimated:YES];
    [UIView animateWithDuration:0.3 animations:^{
        self.refershArrow.alpha = 0;
    }];
}

// MARK: - SearchBar Delegate Methods ******************************************
// MARK: - searchBarTextDidBeginEditing
 
- (void)showEggDateController:(CageModel *)CageData
{
    self.selectedCage = CageData;
    // transition.startingPoint = button.center;
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    FirstEggVC *VC = [FirstEggVC new];
    VC.CageModelData = self.selectedCage;
    [self presentViewController:VC
                         inSize:CGSizeMake(self.view.frame.size.width, 340)
                      direction:PVCDirectionBottom
                     completion:^{
    }];
}


- (void)deleteEditCageOptions:(long)index CageData:(CageModel *)CageData cellView:(UIView *)cellView cellIndexPath:(NSIndexPath *)cellIndexPath
{
    if (index == 0) {
        NewCageVC *VC = [NewCageVC new];
        VC.CagedataSource = self.CagedataSource;
        VC.FromAction = @"Edit";
        if(CageData.FatherCard.isSold == 1) CageData.FatherCard.ID = @"sold";
        if(CageData.MotherCard.isSold == 1) CageData.MotherCard.ID = @"sold";
        VC.CageData = CageData;
        [PPFunc presentSheetFrom:self sheetVC:VC detentStyle:PPSheetDetentStyle70];
    }
    
    if (index == 1) {
        [PPAlertHelper showConfirmationIn:self title:kLang(@"deleteBoxAlertTitle") subtitle:kLang(@"deleteBoxAlertDesc") confirmButton:kLang(@"yes") cancelButton:kLang(@"no") icon:PPSYSImage(@"trash") confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            if(!didConfirm) return;
            
            [PPHUD showLoading];
            FIRDocumentReference *CagesCol = [[[AppManager sharedInstance].dF collectionWithPath:@"CagesCol"] documentWithPath:CageData.ID];
            [CagesCol updateData:@{ @"isDeleted": @1 }
                      completion:^(NSError *_Nullable error) {
                if (error != nil) {
                    NSLog(@"Error removing document: %@", error);
                    [PPHUD dismiss];
                } else {
                    NSLog(@"Document successfully removed CardRef !");
                    [self.dataManager showSnakBar:kLang(@"DeletedSuccess")
                                        withColor:[GM appPrimaryColor]
                                      andDuration:3 containerView:self.view];
                    [PPHUD dismiss];
                    
                    // }];
                }
            }];
            
            
        } cancelBlock:^{
            
        }];
        
    }
}


#pragma mark - Helper Methods

- (NSString *)formatLabel:(NSString *)label value:(NSString *)value {
    return [NSString stringWithFormat:@"%@ : %@", label, [self safeValue:value]];
}

- (NSString *)safeValue:(NSString *)value {
    if (!value || [value isKindOfClass:[NSNull class]]) return @"";
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed.lowercaseString isEqualToString:@"no_value"] ||
        [trimmed.lowercaseString containsString:@"null"]) return @"";
    return trimmed;
}

- ( NSString * _Nullable)primaryImageURLForCard:(CardModel *)cardData {
    if (cardData.imagesNames.count == 0) {
        return @""; //https://firebasestorage.googleapis.com/v0/b/pure-pets-49199.firebasestorage.app/o/Placers%2FbirdPlace.png?alt=media&token=5dca1e6a-1e6f-4771-b4be-759f322447fa
    }
    if (cardData.FilesArray.count > 0) {
        for (FileModel *file in cardData.FilesArray) {
            if (file.FileType == 0) return file.FileUrl;
        }
        return cardData.FilesArray.firstObject.FileUrl;
    }
    return @"";
}


















// MARK: - Associated Objects Getters & Setters

#pragma mark - UI Elements
- (UIButton *)segEmptyCard {
    return objc_getAssociatedObject(self, @selector(segEmptyCard));
}


- (Sort)sort {
    NSNumber *sortType = objc_getAssociatedObject(self, @selector(sort));
    if (!sortType) {
        self.sort = SortAsc; // Default sort
        return SortAsc;
    }
    return [sortType integerValue];
}

- (void)setSort:(Sort)sort {
    objc_setAssociatedObject(self, @selector(sort), @(sort), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setSegEmptyCard:(UIButton *)segEmptyCard {
    objc_setAssociatedObject(self, @selector(segEmptyCard), segEmptyCard, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIButton *)searchEmptyCard {
    return objc_getAssociatedObject(self, @selector(searchEmptyCard));
}

- (void)setSearchEmptyCard:(UIButton *)searchEmptyCard {
    objc_setAssociatedObject(self, @selector(searchEmptyCard), searchEmptyCard, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UISegmentedControl *)topSeg {
    return objc_getAssociatedObject(self, @selector(topSeg));
}

- (void)setTopSeg:(UISegmentedControl *)topSeg {
    objc_setAssociatedObject(self, @selector(topSeg), topSeg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


-(UITabBar *)mainTabBar
{
    return objc_getAssociatedObject(self, @selector(mainTabBar));
}

-(void)setMainTabBar:(UITabBar *)mainTabBar
{
    objc_setAssociatedObject(self, @selector(mainTabBar), mainTabBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIButton *)FilterBTN {
    return objc_getAssociatedObject(self, @selector(FilterBTN));
}

- (void)setFilterBTN:(UIButton *)FilterBTN {
    objc_setAssociatedObject(self, @selector(FilterBTN), FilterBTN, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (EmptyStateView *)emptyStateView {
    return objc_getAssociatedObject(self, @selector(emptyStateView));
}

- (void)setEmptyStateView:(EmptyStateView *)emptyStateView {
    objc_setAssociatedObject(self, @selector(emptyStateView), emptyStateView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UITextField *)searchTextField {
    return objc_getAssociatedObject(self, @selector(searchTextField));
}

- (void)setSearchTextField:(UITextField *)searchTextField {
    objc_setAssociatedObject(self, @selector(searchTextField), searchTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Data Models
- (CardModel *)selectedCard {
    return objc_getAssociatedObject(self, @selector(selectedCard));
}

- (void)setSelectedCard:(CardModel *)selectedCard {
    objc_setAssociatedObject(self, @selector(selectedCard), selectedCard, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIImage *)selectedImage {
    return objc_getAssociatedObject(self, @selector(selectedImage));
}

- (void)setSelectedImage:(UIImage *)selectedImage {
    objc_setAssociatedObject(self, @selector(selectedImage), selectedImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<CardModel *> *)allCardsArray {
    return objc_getAssociatedObject(self, @selector(allCardsArray));
}

- (void)setAllCardsArray:(NSArray<CardModel *> *)allCardsArray {
    objc_setAssociatedObject(self, @selector(allCardsArray), allCardsArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray<CardModel *> *)userCardsArray {
    NSMutableArray *array = objc_getAssociatedObject(self, @selector(userCardsArray));
    if (!array) {
        array = AppData.UserCardsDocs;
        self.userCardsArray = array;
    }
    return array;
}

- (void)setUserCardsArray:(NSMutableArray<CardModel *> *)userCardsArray {
    objc_setAssociatedObject(self, @selector(userCardsArray), userCardsArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray<TrashModel *> *)trachArray {
    NSMutableArray *array = objc_getAssociatedObject(self, @selector(trachArray));
    if (!array) {
        array = [NSMutableArray new];
        //self.trachArray =AppData.trashDocs;
    }
    return array;
}

- (void)setTrachArray:(NSMutableArray<TrashModel *> *)trachArray {
    objc_setAssociatedObject(self, @selector(trachArray), trachArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
  

-(NSMutableArray<BuyerModel *> *)SalesBuyerArr
{
    NSMutableArray *array = objc_getAssociatedObject(self, @selector(SalesBuyerArr));
    if (!array) {
        array = [NSMutableArray new];
        self.SalesBuyerArr = AppData.BuyerArray;
    }
    return array;
}

-(void)setSalesBuyerArr:(NSMutableArray<BuyerModel *> *)SalesBuyerArr
{
    objc_setAssociatedObject(self,@selector(SalesBuyerArr),SalesBuyerArr,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray<ArchiveModel *> *)UserArchivesDocs {
    NSMutableArray *array = objc_getAssociatedObject(self, @selector(UserArchivesDocs));
    if (!array) {
        array = [NSMutableArray new];
        self.UserArchivesDocs = AppData.UserArchivesDocs;
    }
    return array;
}

- (void)setUserArchivesDocs:(NSMutableArray<ArchiveModel *> *)userArchivesDocs {
    objc_setAssociatedObject(self, @selector(UserArchivesDocs), userArchivesDocs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray<CageModel *> *)CagedataSource {
    NSMutableArray *array = objc_getAssociatedObject(self, @selector(CagedataSource));
    if (!array) {
        array = [NSMutableArray new];
        self.CagedataSource = AppData.UserCaGeDocs;
    }
    return array;
}

- (void)setCagedataSource:(NSMutableArray<CageModel *> *)CagedataSource {
    objc_setAssociatedObject(self, @selector(CagedataSource), CagedataSource, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<SubKindModel *> *)SubKindsArrayLocal {
    return objc_getAssociatedObject(self, @selector(SubKindsArrayLocal));
}

- (void)setSubKindsArrayLocal:(NSArray<SubKindModel *> *)SubKindsArrayLocal {
    objc_setAssociatedObject(self, @selector(SubKindsArrayLocal), SubKindsArrayLocal, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray<SubKindModel *> *)SubKinsFilterArr {
    NSMutableArray *array = objc_getAssociatedObject(self, @selector(SubKinsFilterArr));
    if (!array) {
        array = [NSMutableArray new];
        self.SubKinsFilterArr = array;
    }
    return array;
}

- (void)setSubKinsFilterArr:(NSMutableArray<SubKindModel *> *)SubKinsFilterArr {
    objc_setAssociatedObject(self, @selector(SubKinsFilterArr), SubKinsFilterArr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - User & Managers
- (NSString *)userID {
    return objc_getAssociatedObject(self, @selector(userID));
}

- (void)setUserID:(NSString *)userID {
    objc_setAssociatedObject(self, @selector(userID), userID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UserModel *)CurrentUser {
    return objc_getAssociatedObject(self, @selector(CurrentUser));
}

- (void)setCurrentUser:(UserModel *)CurrentUser {
    objc_setAssociatedObject(self, @selector(CurrentUser), CurrentUser, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (AppManager *)dataManager {
    AppManager *manager = objc_getAssociatedObject(self, @selector(dataManager));
    if (!manager) {
        manager = [AppManager sharedInstance];
        self.dataManager = manager;
    }
    return manager;
}

- (void)setDataManager:(AppManager *)dataManager {
    objc_setAssociatedObject(self, @selector(dataManager), dataManager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - State & Configuration
- (NSString *)currentLanguage {
    NSString *lang = objc_getAssociatedObject(self, @selector(currentLanguage));
    if (!lang) {
        lang = @"ar"; // Default to Arabic
        self.currentLanguage = lang;
    }
    return lang;
}

- (void)setCurrentLanguage:(NSString *)currentLanguage {
    objc_setAssociatedObject(self, @selector(currentLanguage), currentLanguage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)lastSegmentedIndex {
    return [objc_getAssociatedObject(self, @selector(lastSegmentedIndex)) integerValue];
}

- (void)setLastSegmentedIndex:(NSInteger)lastSegmentedIndex {
    objc_setAssociatedObject(self, @selector(lastSegmentedIndex), @(lastSegmentedIndex), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CellSection)cellSection {
    return [objc_getAssociatedObject(self, @selector(cellSection)) integerValue];
}

- (void)setCellSection:(CellSection)cellSection {
    objc_setAssociatedObject(self, @selector(cellSection), @(cellSection), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)lastContentOffset {
    return [objc_getAssociatedObject(self, @selector(lastContentOffset)) floatValue];
}

- (void)setLastContentOffset:(CGFloat)lastContentOffset {
    objc_setAssociatedObject(self, @selector(lastContentOffset), @(lastContentOffset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isScrollingUp {
    return [objc_getAssociatedObject(self, @selector(isScrollingUp)) boolValue];
}

- (void)setIsScrollingUp:(BOOL)isScrollingUp {
    objc_setAssociatedObject(self, @selector(isScrollingUp), @(isScrollingUp), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (LayoutType)layoutType {
    NSNumber *type = objc_getAssociatedObject(self, @selector(layoutType));
    if (!type) {
        self.layoutType = LayoutTypeDefault; // Default to grid
        return LayoutTypeDefault;
    }
    return [type integerValue];
}

- (void)setLayoutType:(LayoutType)layoutType {
    objc_setAssociatedObject(self, @selector(layoutType), @(layoutType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CellType)cellType {
    NSNumber *type = objc_getAssociatedObject(self, @selector(cellType));
    if (!type) {
        self.cellType = CellTypeDefault; // Default to card
        return CellTypeDefault;
    }
    return [type integerValue];
}

- (void)setCellType:(CellType)cellType {
    objc_setAssociatedObject(self, @selector(cellType), @(cellType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)reloadCollection {
    return [objc_getAssociatedObject(self, @selector(reloadCollection)) integerValue];
}

- (void)setReloadCollection:(NSInteger)reloadCollection {
    objc_setAssociatedObject(self, @selector(reloadCollection), @(reloadCollection), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (float)emptyCardHeight {
    return [objc_getAssociatedObject(self, @selector(emptyCardHeight)) floatValue];
}

- (void)setEmptyCardHeight:(float)emptyCardHeight {
    objc_setAssociatedObject(self, @selector(emptyCardHeight), @(emptyCardHeight), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)puaseAnimation {
    return [objc_getAssociatedObject(self, @selector(puaseAnimation)) integerValue];
}

- (void)setPuaseAnimation:(NSInteger)puaseAnimation {
    objc_setAssociatedObject(self, @selector(puaseAnimation), @(puaseAnimation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
 




- (void)refreshCollectionView {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Assuming you have a collectionView property
        if ([self respondsToSelector:@selector(collectionView)]) {
            UICollectionView *collectionView = [self performSelector:@selector(collectionView)];
            [collectionView reloadData];
        }
        
        // Update empty state
        [self updateEmptyState];
    });
}


- (void)updateEmptyState {
  
    PPEmptyStateConfig *cfg = [PPEmptyStateConfig new];
    cfg.animationName = @"Emptyred.json";
    cfg.title      = kLang(@"SearchNoResultsGeneric");
    cfg.subTitle  = @"";
    cfg.buttonTitle  = kLang(@"SearchNoResultsCTA");
    cfg.target       = self;
    //cfg.action       = @selector(retrySegment);
    cfg.isNetworkFile = YES;

    //[PPEmptyStateHelper updateEmptyStateForListView:self.collectionView
             //                             dataCount:10
                            //                 config:cfg];
}


#pragma mark - PPButton circle button helper
- (UIButton *)Local_ButtonWithSystemName:(NSString *)imageName {
    UIButton *btn;
    CGFloat btnSize = PPIOS26() ? 50 :42 ;
    
    if (@available(iOS 26.0, *)) {
        
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        //cfg.preferredSymbolConfigurationForImage
        cfg.baseForegroundColor = AppForgroundColr;
        cfg.background.backgroundColor = AppPrimaryClr;
        cfg.baseBackgroundColor = AppPrimaryClr;
        cfg.image = [UIImage pp_symbolNamed:imageName pointSize:18 weight:UIImageSymbolWeightBold scale:UIImageSymbolScaleLarge palette:@[AppForgroundColr,AppBackgroundClrLigter] makeTemplate:YES];
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];

        
    }
    else if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        
        // ✅ Set background color through configuration
        cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6] ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        cfg.background.cornerRadius = btnSize / 2;
        
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
        btn.layer.cornerRadius = btnSize/2;
    }
    
    // Try SF Symbol first → fallback to asset
    UIImage *icon = [UIImage systemImageNamed:imageName];
    if (!icon) {
        icon = [UIImage imageNamed:imageName];
        icon = [UIImage pp_resizedImage:icon toPointSize:PPIOS26() ? 18 : 15];
    }
    
    if (!icon) {
        DLog(@"[pp_circleButton] ⚠️ No image found for name: %@", imageName);
        icon = [UIImage new]; // fallback empty
    }
    
    if([imageName isEqualToString:@"headset"]) {
        icon = [[UIImage pp_resizedImage:icon toPointSize:18] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    
    [btn setImage:icon forState:UIControlStateNormal];
    
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    
    
    // ✅ Remove the old backgroundColor assignment for iOS 15+
    if (@available(iOS 26.0, *)) {
        // Background is already set in configuration
        btn.tintColor = AppForgroundColr;
        btn.configuration.baseForegroundColor = AppForgroundColr;
        btn.imageView.tintColor = AppForgroundColr;
    } else {
        btn.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6] ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        btn.layer.cornerRadius = btnSize/2;
        btn.layer.masksToBounds = YES;
        
        btn.tintColor = UIColor.labelColor;
        
        [self addLiquidGlassBorderToView:btn];
    }

    btn.layer.masksToBounds = NO; // shadow needs this
  
    
    // 🔹 If it's SF Symbol, apply config
    if ([UIImage systemImageNamed:imageName]) {
        UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:20
                                                        weight:UIImageSymbolWeightRegular
                                                         scale:UIImageSymbolScaleMedium];
        [btn setImage:[icon imageByApplyingSymbolConfiguration:config]
             forState:UIControlStateNormal];
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    //[PPButtonHelper attachTapAnimationToButton:btn style:PPButtonAnimationStylePulse];
    return btn;
}

- (UIButton *)Local_setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style{
    if (@available(iOS 26.0, *)) {
        return [self Local_setButtonAsBackroundButtonWithStyle:style configType:Local_PPButtonConfigrationGlass];
    } else {
        return [self Local_setButtonAsBackroundButtonWithStyle:style configType:Local_PPButtonConfigrationFilled];
    }
}

- (UIButton *)Local_setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style configType:(Local_PPButtonConfigration)configType{
    UIButton *bgButton;
    
    
    
    
    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+ system glass button
        UIButtonConfiguration *cfg = configType == Local_PPButtonConfigrationGlass ? [UIButtonConfiguration glassButtonConfiguration] :
        configType == Local_PPButtonConfigrationClearGlass ? [UIButtonConfiguration glassButtonConfiguration] :
        configType == Local_PPButtonConfigrationFilled ? [UIButtonConfiguration filledButtonConfiguration] :
        configType == Local_PPButtonConfigrationPromp ? [UIButtonConfiguration prominentGlassButtonConfiguration] :
        configType == Local_PPButtonConfigrationClearPromp ? [UIButtonConfiguration prominentClearGlassButtonConfiguration] :
        configType == Local_PPButtonConfigrationTintedBorderd ? [UIButtonConfiguration borderedTintedButtonConfiguration] :
        configType == Local_PPButtonConfigrationTinted ? [UIButtonConfiguration tintedButtonConfiguration] : [UIButtonConfiguration plainButtonConfiguration] ;
        
        
        cfg.cornerStyle = style;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.background.cornerRadius = 0;
        cfg.background.backgroundColor = [UIColor clearColor];
        cfg.baseBackgroundColor = [UIColor clearColor];
        
        
        bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
        bgButton.clipsToBounds = NO;
    } else {
        
        
        // 🌫️ Fallback for iOS <26
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = 16;
        bgButton.layer.masksToBounds = YES;
        [bgButton pp_setShadowColor:AppShadowClr];
        bgButton.layer.shadowOpacity = 0.15;
        bgButton.layer.shadowRadius = 0;
        bgButton.layer.shadowOffset = CGSizeMake(0, 4);
    }
    
    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    return bgButton;
}



@end

/*
 "Add New Parrot Card" = "Add New Parrot Card"
 "Add New Archive" = "Add New Archive"
 "" = ""
 "" = ""
 _m_BottomBar = [[PPNewBottomBar alloc] init];
 _m_BottomBar.barBackStyle = BarBackStyleFade;
 _m_BottomBar.blurBarViewHeight = 58;
 [_m_BottomBar configureWithItems:@[
 @{@"icon":@"qrcode.viewfinder", @"title":kLang(@"barcodeReader")},
 @{@"icon":@"list.clipboard", @"title":kLang(@"sales")},
 @{@"icon":@"headset", @"title":kLang(@"Support")},
 ]];
 [self.view addSubview:_m_BottomBar];
 
 [NSLayoutConstraint activateConstraints:@[
 [_m_BottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
 [_m_BottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
 [_m_BottomBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:10],
 [_m_BottomBar.heightAnchor constraintEqualToConstant:58]
 ]];
 __weak typeof(self) weakSelf = self;
 _m_BottomBar.onButtonTapped = ^(NSInteger index, UIButton * _Nonnull button) {
 
 if(index == 5)
 {
 NSLog(@"[NEW BOTTOM BAR] NewCardForm at index %ld", index);
 
 UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
 weakSelf.navigationController.delegate = weakSelf;
 NewCardForm *vc = [NewCardForm new];
 vc.FromVC =  @"main";
 
 [weakSelf.navigationController pushViewController:vc animated:YES];
 
 }
 else if(index == 2)
 {
 NSLog(@"[NEW BOTTOM BAR] CompanyLocationVC at index %ld", index);
 CompanyLocationVC *vc = [[CompanyLocationVC alloc] init];
 [weakSelf.navigationController pushViewController:vc animated:YES];
 }
 else if(index == 1)
 {
 NSLog(@"[NEW BOTTOM BAR] showSales at index %ld", index);
 [weakSelf showSales];
 }
 else if(index ==0)
 {
 NSLog(@"[NEW BOTTOM BAR] barCodeScannerTapped at index %ld", index);
 [weakSelf barCodeScannerTapped];
 }
 
 };
 */
