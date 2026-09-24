#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1] / "Pure Pets"
failures: list[str] = []

money_terms = re.compile(
    r"price|amount|subtotal|total|fee|cost|discount|refund|balance|rate|currency|qar|sar|vet|ر\.ق|ر\.س",
    re.I,
)
for path in ROOT.rglob("*"):
    if path.suffix.lower() not in {".m", ".mm", ".h", ".swift"} or "Pods" in path.parts:
        continue
    lines = path.read_text(errors="ignore").splitlines()
    for idx, line in enumerate(lines):
        if "%.0f" not in line or "%%" in line:
            continue
        context = " ".join(lines[max(0, idx - 2): min(len(lines), idx + 3)])
        if money_terms.search(context) and "meters" not in line:
            failures.append(f"whole-unit money format {path.relative_to(ROOT)}:{idx + 1}: {line.strip()}")

ad = (ROOT / "MainApp/PetsAdsFiles/New Ad/AddNewAd.m").read_text()
accessory = (ROOT / "MainApp/Accessories/AccessFiles/AddNewAccessory.m").read_text()
order_h = (ROOT / "MainApp/PAYMENTS/CartAndOrdersFiles/OrderModel.h").read_text()
order_m = (ROOT / "MainApp/PAYMENTS/CartAndOrdersFiles/OrderModel.m").read_text()
cart_calc = (ROOT / "MainApp/PAYMENTS/Manager/Cart/PPCartCalculator.m").read_text()
for label, needle, haystack in (
    ("ad price integer parsing", "adModel.price = value.length > 0 ? @(value.integerValue)", ad),
    ("ad price integer validation", "priceVal.integerValue <= 0", ad),
    ("ad snapshot integer price", "NSInteger price = [[self fieldForTag:kprice].value integerValue]", ad),
    ("order total uses float", "float totalPrice", order_h),
    ("order total loads float", 'dict[@"totalPrice"] floatValue', order_m),
):
    if needle in haystack:
        failures.append(label)

if "priceField.keyboardType = UIKeyboardTypeDecimalPad;" not in ad:
    failures.append("ad price does not request decimal keypad")
if "price.keyboardType = UIKeyboardTypeDecimalPad;" not in accessory:
    failures.append("accessory price does not request decimal keypad")
if "PPCartRoundMoney" not in cart_calc:
    failures.append("cart calculator does not normalize monetary totals to 2 decimals")

if failures:
    print("PRICE_DECIMAL_STATIC_TEST: FAIL")
    for failure in failures:
        print(f" - {failure}")
    raise SystemExit(1)
print("PRICE_DECIMAL_STATIC_TEST: PASS")
