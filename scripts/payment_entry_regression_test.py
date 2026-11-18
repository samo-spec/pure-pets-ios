#!/usr/bin/env python3
"""Source contracts for the recorded cart transition watchdog and malformed payment data.

These checks do not compile Objective-C, reproduce a hang, or establish device performance.
"""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
PAYMENTS = ROOT / "Pure Pets/MainApp/PAYMENTS"


def source(relative):
    return (PAYMENTS / relative).read_text()


def method_body(text, signature):
    start = text.index(signature)
    opening = text.index("{", start)
    depth = 1
    for index in range(opening + 1, len(text)):
        depth += (text[index] == "{") - (text[index] == "}")
        if depth == 0:
            return text[opening + 1:index]
    raise AssertionError(f"Unclosed method: {signature}")


class PaymentEntryContracts(unittest.TestCase):
    def test_cart_transition_does_not_force_a_nested_summary_layout(self):
        cart = source("CartAndOrdersFiles/CartViewController.m")
        for signature in ("- (void)viewDidLayoutSubviews", "- (void)setSummuryViewAtBottom", "-(void)viewWillAppear:"):
            body = method_body(cart, signature)
            self.assertNotIn("[self.summaryView layoutIfNeeded]", body, signature)
        layout = method_body(cart, "- (void)viewDidLayoutSubviews")
        self.assertIn("[super viewDidLayoutSubviews]", layout)
        self.assertIn("didPrimeInitialCartScrollPosition", layout)

    def test_cart_cta_still_validates_and_uses_the_payment_router(self):
        body = method_body(source("CartAndOrdersFiles/CartViewController.m"), "- (void)checkoutTapped")
        self.assertIn("isUserLoggedIn", body)
        self.assertIn("cartItems.count == 0", body)
        self.assertIn("[PPSelectPaymentVC pushFromViewController:self]", body)
        self.assertIn("@finally", body)
        self.assertNotIn("@catch", body)
        self.assertIn('"CartCheckoutTap"', body)

    def test_raw_instrument_fields_cannot_reach_string_or_boolean_selectors(self):
        model = source("PPPaymentsFiles/UserPaymentInstrument.m")
        body = method_body(model, "- (instancetype)initWithDictionary:")
        for field in ("userID", "methodID", "maskedDetails"):
            self.assertIn(f'_{field} = PPInstrumentStringFromValue(payload[@"{field}"])', body)
        self.assertIn('PPInstrumentBoolFromValue(payload[@"isDefault"])', body)
        self.assertIn("isKindOfClass:NSString.class", method_body(model, "static NSString *PPInstrumentStringFromValue"))
        boolean = method_body(model, "static BOOL PPInstrumentBoolFromValue")
        self.assertIn("isKindOfClass:NSNumber.class", boolean)
        self.assertIn("isKindOfClass:NSString.class", boolean)

    def test_nested_masked_display_values_are_typed(self):
        body = method_body(source("PPPaymentsFiles/UserPaymentInstrument.m"), "- (NSString *)displaySummary")
        self.assertIn("PPInstrumentStringFromValue(self.maskedDetails)", body)
        self.assertIn('PPInstrumentStringFromValue(metadata[@"maskedCard"])', body)

    def test_method_lookup_rejects_non_strings_before_normalization(self):
        body = method_body(source("PPPaymentsFiles/PaymentMethod.m"), "+ (nullable PaymentMethod *)methodForID:")
        self.assertLess(body.index("isKindOfClass:NSString.class"), body.index("stringByTrimmingCharactersInSet"))
        helper = source("PPPaymentsFiles/PPSelectPaymentVC+Helper.m")
        normalizer = method_body(helper, "static NSString *PPPaymentSelectionNormalizedMethodID")
        self.assertIn("isKindOfClass:NSString.class", normalizer)
        for alias in ('@"cod"', '@"cash_on_delivery"'):
            self.assertIn(alias, normalizer)
        self.assertIn("if (normalizedMethodID.length == 0) { continue; }", helper)

    def test_instrument_deadline_can_recover_late_and_rejects_stale_sessions(self):
        body = method_body(source("PPPaymentsFiles/PPSelectPaymentVC.m"), "- (void)fetchUserPaymentInstruments")
        watchdog = body[body.index("// Bound the first-result"):]
        for guard in ("paymentInstrumentLoadGeneration != generation", "!self.isLoadingPaymentInstruments", "isEqualToString:uid"):
            self.assertIn(guard, watchdog)
        self.assertIn("20 * NSEC_PER_SEC", watchdog)
        self.assertIn("paymentInstrumentsLoadFailed = YES", watchdog)
        self.assertNotIn("stopListening", watchdog)
        self.assertNotIn("paymentInstrumentLoadGeneration +=", watchdog)
        self.assertNotIn("isCheckoutInProgress =", watchdog)

    def test_successful_address_callbacks_do_not_duplicate_review_updates(self):
        payment = source("PPPaymentsFiles/PPSelectPaymentVC.m")
        matches = re.findall(
            r"if \(!error\) \[self pp_applyAddresses:addresses \?: @\[\]\];\s*else \[self pp_updateCheckoutReview\];", payment
        )
        self.assertEqual(2, len(matches))
        self.assertEqual(1, method_body(payment, "- (void)pp_applyAddresses:").count("[self pp_updateCheckoutReview]"))

    def test_unchanged_address_text_does_not_rebuild_its_layout(self):
        body = method_body(source("PPPaymentsFiles/PPAddressPickerView.m"), "- (void)setAddressText:")
        self.assertLess(body.index("isEqualToString:resolvedText"), body.index("pp_updateMetrics"))
        self.assertIn("if (self.onLayoutHeightChange) self.onLayoutHeightChange()", body)


if __name__ == "__main__":
    unittest.main(verbosity=2)
