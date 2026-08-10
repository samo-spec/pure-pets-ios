#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources" / "SpearLivingChatHeader"
production_files = [
    path for path in SOURCE.glob("*.swift")
    if path.name != "SpearChatHeaderPreviewLab.swift"
]
text = "\n".join(path.read_text(encoding="utf-8") for path in production_files)
actions_source = (SOURCE / "SpearChatHeaderActions.swift").read_text(encoding="utf-8")
models_source = (SOURCE / "SpearChatHeaderModels.swift").read_text(encoding="utf-8")
copy_source = (SOURCE / "SpearChatHeaderCopy.swift").read_text(encoding="utf-8")
context_source = (SOURCE / "SpearConversationContext.swift").read_text(encoding="utf-8")
context_view_source = (SOURCE / "SpearChatHeaderContext.swift").read_text(encoding="utf-8")
expansion_source = (SOURCE / "SpearChatHeaderExpansion.swift").read_text(encoding="utf-8")
states_source = (SOURCE / "SpearChatHeaderStates.swift").read_text(encoding="utf-8")
header_source = (SOURCE / "SpearChatHeader.swift").read_text(encoding="utf-8")
ready_source = (SOURCE / "SpearReadyHeader.swift").read_text(encoding="utf-8")
presence_source = (SOURCE / "SpearChatHeaderPresence.swift").read_text(encoding="utf-8")
deck_source = (SOURCE / "SpearChatHeaderDeck.swift").read_text(encoding="utf-8")
style_source = (SOURCE / "SpearChatHeaderStyle.swift").read_text(encoding="utf-8")

checks: list[tuple[str, bool]] = []
checks.append(("production files stay under 300 lines", all(len(p.read_text().splitlines()) <= 300 for p in production_files)))
checks.append(("no AsyncImage inside the reusable component", "AsyncImage" not in text))
checks.append(("no minimumScaleFactor compression", "minimumScaleFactor" not in text))
checks.append(("no nested thin/regular material surfaces", ".thinMaterial" not in text and ".regularMaterial" not in text))
checks.append(("adaptive layout uses ViewThatFits", text.count("ViewThatFits") >= 2))
checks.append(("back remains present in loading state", "SpearHeaderLoadingRow" in text and "SpearChatHeaderAccessibilityID.back" in states_source))
checks.append(("optional actions use explicit availability", "SpearActionAvailability" in text and "case hidden" in actions_source and "case disabled" in actions_source))
checks.append(("back action is required", bool(re.search(r"public init\(\s*onBack: @escaping", actions_source, re.S))))
model_fields = models_source.split("public enum SpearTrustState", 1)[0]
checks.append(("trust is represented by one typed state", "public enum SpearTrustState" in text and "public var trust: SpearTrustState" in model_fields and "public var isVerified" not in model_fields))
checks.append(("presence excludes active-call action state", "case activeCall" not in models_source and "case offline(lastActiveAt: Date)" in models_source))
checks.append(("active call owns its end action", "public enum SpearCallControl" in actions_source and "case active(elapsedSeconds: Int, end: () -> Void)" in actions_source))
checks.append(("active call remains actionable in failure states", states_source.count("actions.call.isActive") >= 3 and states_source.count("actions.call.buttonAction") >= 3))
checks.append(("response speed is semantic", "public enum SpearResponseSpeed" in models_source and "responseNote" not in models_source))
checks.append(("metric IDs are normalized", "normalizedMetrics" in models_source and "seenIDs.insert" in models_source))
checks.append(("order progress rejects non-finite values", "value.isFinite" in context_source))
checks.append(("presence copy uses explicit returns", "case .typing:\n      return typingText" in copy_source and "case .viewingOffer:\n      return viewingOfferText" in copy_source))
checks.append(("context motion respects Reduce Motion", "accessibilityReduceMotion" in context_view_source and "if reduceMotion" in context_view_source))
checks.append(("custom avatar boundary exists", "@ViewBuilder avatar:" in (SOURCE / "SpearChatHeader.swift").read_text()))
checks.append(("motion arbiter exists", "internal enum SpearMotionMode" in text and "call.isActive" in (SOURCE / "SpearChatHeaderStyle.swift").read_text()))
checks.append(("stable UI-test identifiers exist", "public enum SpearChatHeaderAccessibilityID" in text))
checks.append(("semantic main background owns the header field", "mainBackgroundColor" in style_source and "style.mainBackgroundColor" in header_source))
checks.append(("legacy lilac and community blue are absent from the header", "quietLilac" not in text and "618CB8" not in text and "SpearHeaderAtmosphere" not in text))
checks.append(("live and warning states use adaptive semantic colors", "SpearHeaderSemanticColor" in style_source and ".green" not in text and ".orange" not in text))
checks.append(("context and trust share one conversation deck", "if isExpanded && canExpand" in ready_source and "else if let context = model.context" in ready_source and "SpearHeaderDeck" in context_view_source and "SpearHeaderDeck" in expansion_source and "struct SpearHeaderDeck" in deck_source))
checks.append(("presence meaning is not wrapped in a redundant status pill", ".background(semanticColor.opacity" not in presence_source))
checks.append(("loading reserves the More action footprint", "actions.more.availability.isVisible" in states_source and "hasLoadingActionFootprint" in states_source))
checks.append(("header motion has no unbounded repeat loop", "repeatForever" not in text))

failed = [name for name, passed in checks if not passed]
for name, passed in checks:
    print(f"{'PASS' if passed else 'FAIL'}: {name}")

if failed:
    print(f"\n{len(failed)} source-contract checks failed.", file=sys.stderr)
    sys.exit(1)

print(f"\nAll {len(checks)} source-contract checks passed.")
