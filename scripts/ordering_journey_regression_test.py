#!/usr/bin/env python3
"""Source-contract guards for consumer ordering. These do not execute UIKit/Firebase."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PAYMENTS = ROOT / 'Pure Pets/MainApp/PAYMENTS'

def read(path):
    return path.read_text(encoding='utf-8')

def method(source, name):
    for start in re.finditer(r'(?m)^[+-]\s*\([^\n]+?\)' + re.escape(name) + r'(?=\s|:|$)', source):
        signature_end = re.search(r'[;{]', source[start.end():])
        if not signature_end or signature_end.group() != '{':
            continue  # A declaration is not executable evidence.
        following = re.search(r'(?m)^[+-]\s*\(', source[start.end():])
        end = start.end() + following.start() if following else len(source)
        return source[start.start():end]
    raise AssertionError(f'Missing implementation {name}')

class OrderingContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.checkout = read(PAYMENTS / 'PPPaymentsFiles/PPSelectPaymentVC.m')
        cls.helper = read(PAYMENTS / 'PPPaymentsFiles/PPSelectPaymentVC+Helper.m')
        cls.manager = read(PAYMENTS / 'Manager/Cart/CartManager.m')
        cls.cell = read(PAYMENTS / 'CartAndOrdersFiles/PPCartTableCell.m')
        cls.cart = read(PAYMENTS / 'CartAndOrdersFiles/CartViewController.m')
        cls.form = read(ROOT / 'Pure Pets/MainApp/UserFiles/Adressess/AddressFormVC.m')
        cls.picker = read(ROOT / 'Pure Pets/DesignFiles/PP/PPSelectOptionViewController/PPSelectAddressVC.m')
        cls.map = read(ROOT / 'Pure Pets/MainApp/Helpers/LocationPickerViewController.m')
        cls.summary = read(ROOT / 'Pure Pets/DesignFiles/PP/PPNAV/PPContextAwareCheckoutView.swift')

    def test_quantity_cells_send_intent_without_mutating_shared_models(self):
        for name, action in [('didTapPlus', 'plus'), ('didTapMinus', 'minus')]:
            body = method(self.cell, name)
            self.assertIn(f'self.onAction(self.currentItem, @"{action}")', body)
            self.assertNotRegex(body, r'(?:currentItem\.quantity\s*(?:=(?!=)|\+=|-=|\+\+|--)|(?:\+\+|--)\s*self\.currentItem\.quantity)')

    def test_failed_quantity_write_restores_acknowledged_value_and_finishes(self):
        body = method(self.manager, 'pp_flushQuantityMutation')
        self.assertIn('if (!error) mutation.confirmedQuantity = submittedQuantity', body)
        self.assertIn('current.quantity = mutation.confirmedQuantity', body)
        self.assertLess(body.index('mutation.revision != submittedRevision'), body.index('current.quantity = mutation.confirmedQuantity'))
        self.assertIn('success:error == nil', body)

    def test_listener_does_not_race_quantity_writer(self):
        body = method(self.manager, 'startListeningToCartChanges')
        self.assertRegex(body, r'if \(!self.quantityMutations\[localKey\]\)\s*\{\s*\[self pp_syncCartItemToFirestore:')
        self.assertIn('generation != self.cartListenerGeneration', body)
        self.assertIn('userID isEqualToString:PPCurrentFIRAuthUser.uid', body)

    def test_undo_cannot_be_erased_by_late_delete(self):
        body = method(self.manager, 'undoLastRemoval')
        self.assertIn('if ([self.pendingDeletedItemKeys containsObject:cartKey]) return NO', body)
        self.assertNotIn('pendingDeletedItemKeys removeObject', body)
        undo_ui = method(self.cart, 'pp_undoLastRemovalTapped')
        self.assertIn('CartManager.sharedManager undoLastRemoval', undo_ui)
        self.assertNotIn('insertObject:', undo_ui)
        removal = method(self.cart, 'pp_removeItemAtIndexPath')
        self.assertIn('!removalSettled || !removalSucceeded || !animationFinished', removal)

    def test_checkout_locks_before_first_async_refresh(self):
        body = method(self.checkout, 'finishPayments')
        self.assertLess(body.index('[self pp_setPreparingCheckout:YES]'), body.index('[self pp_refreshLatestAddressesForCheckout:'))
        for guard in ['self.isCheckoutInProgress || self.isPreparingCheckout', 'checkoutPreflightGeneration', 'currentUser.uid isEqualToString:uid', 'hasPendingSyncOperations']:
            self.assertIn(guard, body)

    def test_confirmation_rechecks_exact_customer_choice(self):
        body = method(self.checkout, 'finishPayments')
        for value in ['addressID', 'instrumentID', 'methodID', 'itemsSnapshot', 'phoneSnapshot', 'addressSnapshot', '.finalTotal - total', 'id visible =']:
            self.assertIn(value, body)
        self.assertLess(body.index('if (changed)'), body.index('[self pp_startCheckoutWithPaymentMethodId:'))

    def test_removed_address_is_not_silently_replaced(self):
        body = method(self.checkout, 'pp_preferredAddressFrom')
        sticky = body[body.index('if (selectedID.length > 0)'):body.index('if (address.isDefault')]
        self.assertIn('return nil;', sticky)

    def test_stale_refresh_cannot_confirm_or_replace_a_newer_address(self):
        body = method(self.checkout, 'pp_refreshLatestAddressesForCheckout')
        self.assertLess(body.index('generation != self.addressRefreshGeneration'), body.index('[self pp_applyAddresses:'))
        self.assertIn('code:1004', body)

    def test_initial_and_explicit_address_loads_expose_retry_after_timeout(self):
        for name in ['pp_setupInitialAddressState', 'pp_refreshLatestAddressesForCheckout']:
            body = method(self.checkout, name)
            self.assertIn('dispatch_after', body)
            self.assertIn('self.isLoadingAddresses = NO', body)
            self.assertIn('self.addressesLoadFailed = YES', body)

    def test_explicit_payment_choice_never_falls_back(self):
        default = method(self.helper, 'pp_applyDefaultSelectionIfNeeded')
        self.assertIn('!resolved && !self.paymentSelectionWasExplicit', default)
        self.assertNotIn('return displayed.firstObject', method(self.helper, 'pp_resolvedSelectedInstrument'))

    def test_contact_save_returns_to_review_without_purchase(self):
        body = method(self.checkout, 'pp_showQIBMobileNumberSheetForAddress')
        self.assertNotIn('finishPayments', body)
        self.assertNotIn('pp_startCheckoutWithPaymentMethodId', body)
        self.assertIn('phoneEditorGeneration != editorGeneration', body)
        self.assertIn('checkout_contact_save_waiting', body)
        self.assertIn('__weak UIView *weakOverlay', body)

    def test_current_location_always_goes_through_saved_address_form(self):
        body = method(self.picker, 'pp_handleDeliverCurrentLocationTapped')
        self.assertIn('pp_presentAddressForm:nil useLocation:YES', body)
        self.assertNotIn('pp_completeWithAddress', body)
        self.assertNotIn('pp_startResolvingCurrentLocation', method(self.picker, 'viewDidLoad'))
        self.assertNotIn('requestWhenInUseAuthorization', method(self.form, 'viewDidLoad'))

    def test_confirmed_deleted_address_cannot_remain_selectable_when_refresh_fails(self):
        # The delegate is emitted only after a successful server deletion.
        deletion = self.picker[self.picker.index('didDeleteAddress:(PPAddressModel *)address'):]
        deletion = deletion[:deletion.index('#pragma mark - Appearance')]
        self.assertIn('currentAuthenticatedUserID] isEqualToString:self.pickerUserID', deletion)
        self.assertIn('[[self pp_effectiveAddressID:option] isEqualToString:deletedID]) continue', deletion)
        self.assertLess(deletion.index('self.allOptions = remaining'), deletion.index('[self pp_reloadAddressesFromServerSelectingID:nil]'))
        self.assertIn('self.selectedOption = nil', deletion)
        # A failed reload must retain the acknowledged local list.
        refresh = method(self.picker, 'pp_reloadAddressesFromServerSelectingID')
        error_path = refresh[refresh.index('if (error)'):refresh.index('NSString *currentID')]
        self.assertIn('return;', error_path)
        self.assertNotIn('self.allOptions =', error_path)

    def test_geocoding_never_overwrites_newer_input_or_other_account(self):
        body = method(self.form, 'pp_reverseGeocodeCoordinateForRowTitle')
        for guard in ['self.geocodeGeneration != generation', 'isEqualToString:requestedPoints', 'isEqualToString:requestedUID', 'lineAtRequest.length == 0 && self.draftAddressLine1.length == 0', 'postalAtRequest.length == 0 && self.draftPostalCode.length == 0']:
            self.assertIn(guard, body)
        self.assertNotIn('pp_nearestCityForCoordinate', body)

    def test_location_samples_are_fresh_and_requests_can_recover(self):
        body = method(self.form, 'pp_isUsableLocationSample')
        self.assertIn('horizontalAccuracy <= 200.0', body)
        self.assertIn('timeIntervalSinceNow) <= 30.0', body)
        for source, name in [(self.form, 'pp_startPrefillFromCurrentLocationIfNeeded'), (self.map, 'pp_requestCurrentLocation')]:
            request = method(source, name)
            self.assertIn('locationRequestGeneration', request)
            self.assertIn('dispatch_after', request)
            self.assertIn('ordering_address_location_unavailable', request)

    def test_address_edit_is_detached_and_retry_keeps_document_identity(self):
        body = method(self.form, 'saveButtonPressed')
        self.assertIn('if (!self.persistenceDraft)', body)
        self.assertIn('initWithDictionary:self.persistenceDraft.toDictionary', body)
        self.assertNotRegex(body, r'self\.address\.(?:fullName|addressLine1|cityID|postalCode)\s*=')
        waiting = body[body.index('dispatch_after'):body.index('void (^handleResult)')]
        self.assertNotIn('pp_setSavingState:NO', waiting)
        self.assertIn('self.activeSaveToken != saveToken', body)
        self.assertIn('isEqualToString:self.formUserID', body)

    def test_bill_visible_outside_item_disclosure(self):
        self.assertIn('contentStack.addArrangedSubview(pricingBreakdownStack)', self.summary)
        self.assertNotIn('itemsContainer.addSubview(pricingBreakdownStack)', self.summary)
        self.assertIn('self.pricingBreakdownStack.isHidden = !hasItems', self.summary)
        self.assertIn('actionMaximumWidthConstraint?.isActive = !shouldStack', self.summary)

    def test_hidden_checkout_actions_do_not_require_nonzero_stack_height(self):
        body = method(self.checkout, 'pp_reviewActionButtonWithTitle')
        self.assertIn('minimumHeight.priority = UILayoutPriorityRequired - 1.0', body)
        self.assertNotIn('[button.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin].active = YES', body)

    def test_checkout_dock_visibility_does_not_reenter_layout_during_construction(self):
        body = self.summary.split('private func updateContextVisibility(animated: Bool)', 1)[1]
        body = body.split('private func setReviewExpanded', 1)[0]
        changes = body.split('let changes = {', 1)[1].split('\n        }', 1)[0]
        self.assertNotIn('layoutIfNeeded()', changes)
        self.assertNotIn('layoutIfNeeded', method(self.checkout, 'pp_applyAdaptiveSummaryPresentation'))

    def test_adaptive_checkout_axis_does_not_depend_on_its_own_wrapped_label(self):
        body = self.summary.split('private func updateAdaptiveDecisionLayout()', 1)[1]
        body = body.split('private func updateShadowPath()', 1)[0]
        self.assertNotIn('totalLabel.intrinsicContentSize', body)
        self.assertIn('guard bounds.width.isFinite, bounds.width > 1 else { return }', body)
        self.assertLess(body.index('guard decisionStack.axis != nextAxis'), body.index('actionMinimumWidthConstraint?.isActive'))

    def test_new_copy_has_arabic_english_and_matching_format_arguments(self):
        sources = '\n'.join([self.checkout, self.cell, self.cart, self.form, self.picker, self.map])
        names = set(re.findall(r'@"((?:ordering_address_|cart_quantity_|address_picker_)[a-z_]+)"', sources))
        names.update(['checkout_add_delivery_address', 'checkout_choose_delivery_address', 'checkout_address_changed_review', 'checkout_choose_payment', 'checkout_complete_address', 'checkout_details_changed_review', 'checkout_loading_addresses', 'checkout_payment_contact_format', 'checkout_payment_contact_hint', 'checkout_payment_contact_missing', 'checkout_save_contact', 'checkout_wait_for_cart', 'checkout_contact_save_waiting', 'checkout_payment_contact_title'])
        catalogs=[]
        for lang in ['en', 'ar']:
            entries = re.findall(r'^"([^"\n]+)"\s*=\s*"((?:\\.|[^"\\])*)";', read(ROOT / f'Pure Pets/{lang}.lproj/Localizable.strings'), re.M)
            catalogs.append(dict(entries))
            for name in names:
                with self.subTest(lang=lang, key=name):
                    self.assertEqual(sum(k == name for k, _ in entries), 1)
                    self.assertTrue(catalogs[-1].get(name))
        for name in names:
            self.assertEqual(re.findall(r'%(?:\d+\$)?(?:ld|@|d|f)', catalogs[0][name]), re.findall(r'%(?:\d+\$)?(?:ld|@|d|f)', catalogs[1][name]), name)

if __name__ == '__main__':
    unittest.main(verbosity=2)
