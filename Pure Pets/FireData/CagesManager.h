//
//  CagesManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/12/2025.
//  Updated by ChatGPT — Arabic docs added.
//

#import <Foundation/Foundation.h>
@import FirebaseFirestore;
#import "CageModel.h"
#import "ChildModel.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^CagesArrayCompletion)(NSArray<CageModel *> * _Nullable cages, NSError * _Nullable error);
typedef void(^ChildsArrayCompletion)(NSArray<ChildModel *> * _Nullable childs, NSError * _Nullable error);
typedef void(^SingleChildCompletion)(ChildModel * _Nullable child, NSError * _Nullable error);
typedef void(^VoidWithError)(NSError * _Nullable error);
 
/// مدير الأقفاص والأطفال (Subcollections) — واجهة عامة للعمليات الشائعة.
@interface CagesManager : NSObject
- (void)upsertCage:(CageModel *)cage;

+ (instancetype)sharedManager;
// CagesManager.m
- (void)listenForCageWithID:(NSString *)cageID
                   onChange:(void (^)(CageModel *cage))onChange;
#pragma mark - Cages (الأقفاص)

/// جلب كل الأقفاص لمستخدم معين (نداء لمرة واحدة).
/// @param userID معرّف المستخدم
/// @param completion مصحوب بمصفوفة CageModel أو خطأ
- (void)fetchCagesForUserID:(NSString *)userID completion:(CagesArrayCompletion)completion;

/// الاستماع للتغييرات على الأقفاص لمستخدم (يرجع FIRListenerRegistration لتمكين الإلغاء).
/// @param userID معرّف المستخدم
/// @param changeHandler يعطى مصفوفة أقفاص أو خطأ عند كل تحديث
- (id<FIRListenerRegistration>)listenToCagesForUserID:(NSString *)userID changeHandler:(CagesArrayCompletion)changeHandler;

#pragma mark - Childs (الأطفال / الفروخ)

/// جلب الأطفال لقفص محدد (نداء لمرة واحدة).
/// @param cageID معرّف القفص
/// @param completion مصحوب بمصفوفة ChildModel أو خطأ
- (void)fetchChildsForCageID:(NSString *)cageID completion:(ChildsArrayCompletion)completion;

/// الاستماع للتغييرات في Subcollection الطفل داخل القفص.
/// @param cageID معرّف القفص
/// @param changeHandler يعطى مصفوفة أطفال أو خطأ عند كل تحديث
- (id<FIRListenerRegistration>)listenToChildsForCageID:(NSString *)cageID changeHandler:(ChildsArrayCompletion)changeHandler;

#pragma mark - CRUD للطفل

/// إضافة طفل جديد داخل Subcollection لقفص.
/// @param child موديل الطفل (يمكن أن يحتوي على بيانات قبل الحفظ)
/// @param cageID معرّف القفص المستهدف
/// @param completion يعيد ChildModel المنشأ مع ID أو خطأ
- (void)addChild:(ChildModel *)child toCageID:(NSString *)cageID completion:(SingleChildCompletion)completion;

/// تحديث طفل موجود (child.ID و child.CageID يجب أن تكون معبأة).
/// @param child موديل الطفل المعدّل
/// @param completion استدعاء مع خطأ إن وُجد
- (void)updateChild:(ChildModel *)child completion:(VoidWithError)completion;

/// حذف منطقي للطفل (isDeleted = 1) — لا يحذف المستند.
- (void)softDeleteChild:(ChildModel *)child completion:(VoidWithError)completion;

/// حذف كامل للمستند (خطر) — استخدم بحذر.
- (void)deleteChildDocument:(ChildModel *)child completion:(VoidWithError)completion;

#pragma mark - نقل الطفل (Atomic / Transaction)

/// نقل طفل من قفص إلى قفص آخر باستخدام Firestore transaction لضمان الاتساق.
/// يقوم بقراءة مستند الطفل الأصلي داخل المعاملة، يكتب نسخة في subcollection الهدف، ثم يعلّم الأصل isDeleted=1.
/// @param child موديل الطفل (ID و CageID الحالي يجبان أن يكونوا موجودين)
/// @param targetCageID المعرف المستهدف
/// @param completion استدعاء عند الانتهاء بخطأ إن وُجد
- (void)moveChild:(ChildModel *)child toCageID:(NSString *)targetCageID completion:(VoidWithError)completion;

#pragma mark - Update Cage

/// تحديث بيانات القفص (مثل ReminderDate أو FristEggDate أو الاسم).
- (void)updateCage:(CageModel *)cage completion:(VoidWithError)completion;

@end

NS_ASSUME_NONNULL_END
