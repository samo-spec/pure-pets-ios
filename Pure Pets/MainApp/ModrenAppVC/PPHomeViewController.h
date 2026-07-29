//
//  PPHomeViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 24/12/2025.
//


//
//  PPHomeViewController.h
//  PurePets
//
 #import <UIKit/UIKit.h>
#import "AdoptPetsViewController.h"
#import "PPHomeFunc.h"
#import "CartViewController.h"
#import "PPHomeHelper.h"
#import "PPDataViewVC.h"


// =========================
// Deep Link Target Enum
// =========================


NS_ASSUME_NONNULL_BEGIN

 

@interface PPHomeViewController : UIViewController

// Forward declaration for deep-link helper (clean)
- (PPDataViewVC *)buildDataViewVCForTarget:(PPDeepLinkTarget)target
                                  mainKind:(MainKindsModel *_Nullable)mainKind
                                    source:(PPInputSource)source;
@property (nonatomic) PPMainKindsLayoutMode mainKindsLayoutMode;
@property (nonatomic, assign) NSInteger initialSelectedMainKindID;
@end

NS_ASSUME_NONNULL_END




/*
 
 
 @swiftify-ui

 # Pure Pets Home — PPHomeViewController to SwiftUI HomeView Flagship 10/10 Execution Contract

 Mode: `migration + flagship redesign + contract-safe refactor`

 ## Mission

 Transform the production Objective-C `PPHomeViewController` into a world-class SwiftUI `HomeView` while preserving every existing business rule, data source, route, analytics event, notification, cart behavior, user state, pet state, service integration, and Objective-C runtime contract.

 This is an implementation assignment—not another audit, recommendation list, mockup, or isolated SwiftUI sample.

 Inspect the actual repository, implement the real production Home, build it, run it, validate it, correct defects, and continue until all applicable release gates pass.

 The migration and visual upgrade must happen through one controlled working path:

 * Preserve a working application throughout the migration.
 * Replace the Home in testable vertical slices.
 * Improve each section as it becomes SwiftUI.
 * Retire its legacy UIKit owner once parity is demonstrated.
 * Finish with exactly one active production owner for every Home responsibility.

 Do not finish with a pixel-for-pixel SwiftUI copy of the current Home. The final result must preserve its functionality while materially improving its hierarchy, creativity, personalization, accessibility, localization, performance, and perceived quality.

 ## Final product direction

 Implement the flagship direction:

 **Pure Pets Pulse — Living Pet Command Center**

 Product promise:

 > Tell the customer what matters for their pet now, then connect them to the right product, advertisement, service, care destination, or action in one confident step.

 The Home must feel like the living center of Pure Pets—not a generic marketplace feed decorated with pink.

 Arabic is the primary experience. English is secondary.

 The brand-pink authority derived from `#CB2654` remains central, but it must be represented through semantic tokens and supported by restrained contextual accent colors.

 ## Current evidence baseline

 Use the supplied 38.74-second, 1284×2778 Home recording as behavioral and visual evidence. It contains 891 encoded frames and demonstrates:

 1. A rotating contextual search or discovery prompt.
 2. A dynamic hero switching between birds and the full marketplace.
 3. Category selection and horizontally scrolling species.
 4. A marketplace listing route with loading skeletons and image loading.
 5. Back navigation to Home.
 6. Featured products.
 7. Available, unavailable, discounted, in-cart, low-stock, favorite, and notify states.
 8. Personalized advertisements and accessories.
 9. Nearby content.
 10. Pet-profile promotion.
 11. Food, veterinary, pharmacy, service-provider, reorder, and recommendation sections.
 12. Persistent cart, search, tab-bar, central-create, and cart-badge controls.
 13. Deep vertical scrolling with many horizontally scrolling rails.

 The current confirmed baseline is approximately:

 * Visual craftsmanship: `7.9/10`
 * Complete Home experience: `6.7/10`
 * Verified 10/10 readiness: `UNVERIFIED`

 ## Confirmed experience problems

 Resolve these issues as part of the migration:

 1. The Home is a long sequence of similarly weighted horizontal rails; important, personalized, commercial, and secondary content compete equally.
 2. The current Home does not immediately answer what the user should do next.
 3. The rotating hero changes its text, color, selected category, illustration, and action through partially independent transitions. During the recorded transition, old and new layers visibly overlap.
 4. Automatic hero changes lack a clear progress or page model and can compete with user interaction.
 5. The sticky top surface remains large while scrolling and visually interferes with underlying content.
 6. The persistent bottom navigation occupies considerable height and can cover the final portion of sections.
 7. Marketplace navigation spends several frames in a mostly empty skeleton state.
 8. The return transition exposes a split-screen seam and transient material distortion.
 9. Product, advertisement, and service cards have inconsistent information hierarchies and action semantics.
 10. `أضف إلى السلة`, `في السلة`, `نبّهني عند التوفر`, `التفاصيل`, and disabled actions are not always visually distinct enough.
 11. Repeated section-header decorations create monotony instead of meaningful hierarchy.
 12. Partially visible edge cards are sometimes clipped too aggressively.
 13. Long titles, prices, metadata, availability, and action rows do not always produce stable card heights.
 14. Status information relies heavily on pale green, red, yellow, and gray.
 15. `QAR`, `1000G`, and localized `ر.ق` appear in the same Arabic experience.
 16. Service cards prominently display a `0.0` rating, which reads as a negative trust signal rather than missing data.
 17. The selected pet or pet profile does not clearly control the Home’s hierarchy.
 18. The create-pet-profile invitation appears too far down the feed despite its strategic importance.
 19. Multiple nested horizontal rails create gesture, VoiceOver, and performance risks.
 20. Loading, partial, empty, image-failure, offline, stale, permission-denied, and per-section retry states are incomplete or visually unverified.
 21. Dynamic Type, dark mode, VoiceOver, Increased Contrast, Reduce Motion, memory behavior, and ProMotion performance remain unverified.
 22. The Home needs slightly more decoration and creative distinction, but additional decoration must remain controlled and functional.

 ## Phase 1 — Repository and contract inspection

 Before modifying code, inspect:

 * Repository and nested `AGENTS.md` instructions.
 * Current Git status and all existing user changes.
 * Workspace, schemes, targets, deployment target, Swift version, and target membership.
 * `PPHomeViewController.h` and `PPHomeViewController.m`.
 * All extensions, categories, subclasses, runtime lookups, storyboards, XIBs, outlets, and actions involving the Home.
 * Root controller, tab controller, navigation controller, coordinator, and deep-link ownership.
 * Every cell, supplementary view, hero, header, category selector, product rail, advertisement rail, service card, pet-profile card, nearby module, and loading view used by Home.
 * Objective-C bridging headers and generated Swift interfaces.
 * Current SwiftUI design system, tokens, fonts, colors, materials, card styles, images, icons, motion grammar, and reusable components.
 * API clients, repositories, caches, persistence, Firebase integrations, notifications, authentication, location, cart, favorites, pet profiles, products, advertisements, services, and recommendations.
 * Analytics events, parameters, impression logic, timing, and deduplication.
 * Tests, fixtures, feature flags, snapshot tools, device workflow, and build scripts.

 Search the entire repository for `PPHomeViewController` and every symbol it references. Trace callers in both Objective-C and Swift.

 Establish a clean permitted baseline build before implementation when the environment allows it.

 ## Phase 2 — Migration ledgers

 Create internal implementation ledgers before replacing the legacy screen:

 ### Symbol ledger

 Record:

 * Runtime class names.
 * Objective-C-visible types.
 * Public initializers.
 * Factory methods.
 * `@objc` selectors.
 * Properties accessed through Objective-C.
 * KVC and KVO keys.
 * Delegate protocols.
 * Notifications and `userInfo` keys.

 ### Call-site ledger

 Record every place that:

 * Creates or presents Home.
 * Switches to the Home tab.
 * Refreshes Home.
 * Updates its cart badge.
 * Opens a product, advertisement, seller, service, pet, clinic, pharmacy, search, filter, cart, order, chat, or create flow.
 * Uses deep links or push notifications to enter a Home destination.

 ### Behavioral parity ledger

 Record:

 * Search and rotating discovery suggestions.
 * Hero state and category synchronization.
 * Selected species or category behavior.
 * Product and advertisement filtering.
 * Favorites.
 * Cart additions and in-cart quantities.
 * Unavailable and notify behavior.
 * Service-provider destinations.
 * Nearby content.
 * Reorder or previously purchased content.
 * Pet-profile behavior.
 * Refresh, pagination, retry, and cancellation.
 * Scroll restoration where applicable.
 * Authentication and permission requirements.
 * Analytics and impression behavior.

 ### Ownership ledger

 For every Home responsibility, identify:

 * Current owner.
 * Intended SwiftUI owner.
 * Migration point.
 * Evidence of parity.
 * Legacy owner removal or deactivation.

 The final production target must contain exactly one active owner for each responsibility.

 ## Migration architecture

 All visible Home UI must become SwiftUI.

 A thin Objective-C compatibility shell may remain only when existing Objective-C callers or runtime contracts require it. If retained, `PPHomeViewController` may only:

 * Preserve its expected Objective-C runtime identity.
 * Receive existing dependencies.
 * Create or request the SwiftUI Home host.
 * Forward lifecycle and coordinator events.
 * Preserve the expected navigation and tab behavior.

 It must not continue owning:

 * Collection views.
 * Layout.
 * Cells or supplementary views.
 * Visible loading states.
 * Business state.
 * Network orchestration.
 * Scroll behavior.
 * Hero state.
 * Product-section rendering.

 If repository inspection proves that no Objective-C caller requires the shell, remove it cleanly and migrate callers to the established Swift entry point.

 Use repository conventions, but aim for a compact architecture comparable to:

 * `HomeView.swift` — readable composition root.
 * `HomeStore.swift` — one authoritative state and action owner.
 * `HomeViewState.swift` — explicit renderable states.
 * `HomeSection.swift` — stable section identity and presentation model.
 * `HomeRouter.swift` or existing coordinator adapter.
 * `HomeModelAdapter.swift` — maps existing models without rewriting backend logic.
 * Focused reusable components for the hero, command bar, cards, section header, pet context, and state surfaces.
 * A compatibility host or factory only when Objective-C requires it.

 Keep the file structure proportionate. Each meaningful public production type should have one clear file, while tiny private one-use helpers may remain with their owner. Avoid both a giant Home file and a forest of trivial wrappers.

 ## Business-contract preservation

 Preserve the actual repository behavior for:

 * Home entry and tab reselection.
 * Search.
 * Trending or rotating prompts.
 * Category and species selection.
 * Filters and marketplace listing.
 * Products, advertisements, food, accessories, and services.
 * Product and seller navigation.
 * Veterinary and pharmacy navigation.
 * Nearby results and location handling.
 * Pet profiles.
 * Create-pet flow.
 * Favorites and saved content.
 * Cart badge, additions, quantities, replacement rules, and stock state.
 * Unavailable and notify behavior.
 * Orders and reorder behavior.
 * Authentication and session changes.
 * Notifications and refresh triggers.
 * Analytics events, parameters, impressions, and single-fire behavior.
 * Caching, persistence, and language switching.
 * Existing pagination and retry semantics.
 * Repeated-tap and duplicate-request protection.

 Existing services and models should be adapted, not unnecessarily rewritten.

 Never fabricate personalization, reminders, delivery promises, ratings, availability, nearby distance, medical advice, stock, discounts, or backend content. Render only genuine data. Use honest absence and recovery states when fields are unavailable.

 ## Structural design concepts

 Evaluate these three structures against the repository and include the comparison in the final handoff.

 ### Concept A — Marketplace Spotlight

 A refined version of the current commerce-first Home: dynamic hero, category rail, featured products, advertisements, services, and recommendations.

 Expected strengths:

 * Familiar behavior.
 * Low migration risk.
 * Strong commerce visibility.

 Expected weakness:

 * Still risks becoming a generic scrolling marketplace.

 ### Concept B — Pet Daybook

 A pet-profile-first Home centered on the selected pet’s care, reminders, recent activity, services, and relevant products.

 Expected strengths:

 * Strong emotional relevance.
 * Clear pet-specific identity.
 * High recurring utility.

 Expected weakness:

 * Can underserve customers without a pet profile and bury marketplace discovery.

 ### Concept C — Pure Pets Pulse

 An adaptive command center combining selected-pet relevance with commerce, care, advertisements, and services. It changes priority based on the real data available while preserving access to every current destination.

 Expected strengths:

 * Strongest Pure Pets identity.
 * Clear first action.
 * Personalized without abandoning marketplace discovery.
 * Best balance of commercial value, pet care, accessibility, and differentiation.

 Expected weakness:

 * Requires disciplined section composition and model adaptation.

 Score all concepts from 0–5 on:

 * Product-DNA fit.
 * Five-second clarity.
 * Distinctiveness.
 * Arabic and accessibility resilience.
 * State completeness.
 * Performance feasibility.
 * Migration safety.
 * Commercial discoverability.
 * Pet relevance.
 * Maintainability.

 `Pure Pets Pulse` is the selected direction unless repository evidence reveals a blocking contract or data limitation. Document any necessary adaptation rather than silently reverting to the current generic feed.

 ## Selected Home architecture

 ### 1. Adaptive command bar

 Create a stable, compact command surface containing the real controls supported by the application:

 * Search.
 * Contextual prompt or recent search.
 * Cart and badge.
 * Selected pet or account context when appropriate.
 * Required notification or location context when genuinely relevant.

 Requirements:

 * It must remain understandable without the rotating text.
 * Search must look and behave like search.
 * Cart and badge remain distinct and accessible.
 * Its collapsed state protects underlying content.
 * Its expanded and compact forms have stable geometry.
 * It respects the status bar and safe area.
 * It never collides with section titles.
 * It does not remain unnecessarily tall during deep scrolling.
 * Dynamic text does not move the user’s tap target.

 ### 2. Pet Pulse Hero — signature component

 Replace the generic rotating banner with an adaptive hero that answers:

 > What matters for my pet today?

 When real pet-profile data exists, it may use:

 * Pet name and photo.
 * Species or life stage.
 * Genuine care reminders.
 * Relevant reorder.
 * A suitable product or service destination.
 * A real appointment, saved item, or marketplace context.

 When no pet profile exists, the hero becomes an elegant onboarding invitation that explains the value of creating one while preserving immediate marketplace access.

 When only generic data exists, present a curated marketplace or service destination without pretending it is personalized.

 Signature visual moment:

 * The pet, species, or marketplace artwork occupies one intentional focal layer.
 * A restrained brand aura responds to the current context.
 * Headline, supporting line, artwork, accent, selection, and CTA transition as one atomic state.
 * The hero may gently compress into the command bar during scroll.
 * The transition remains meaningful with Reduce Motion disabled and becomes a concise crossfade when Reduce Motion is enabled.

 Automatic rotation requirements:

 * Provide a clear page or progress model.
 * Pause during touch, VoiceOver, app backgrounding, and active navigation.
 * Avoid rapid rotation.
 * Preserve user-selected content.
 * Transition the complete state atomically so old and new text, colors, art, and selected category never overlap.

 ### 3. Priority actions

 Directly after the hero, show a compact set of high-value actions based on real application capabilities, such as:

 * Shop.
 * Adopt or marketplace advertisements.
 * Veterinary care.
 * Pharmacy.
 * Services.
 * Create or switch pet.

 The selected pet and the user’s current context should influence order when supported by real data.

 Keep the primary destinations visible without forcing the user through the entire feed.

 ### 4. Relevance-first feed

 Compose the feed in this order when corresponding data exists:

 1. Immediate selected-pet or user priority.
 2. Resume, reorder, saved, or in-cart content.
 3. Highly relevant products or advertisements.
 4. Nearby or time-sensitive services.
 5. Care destinations.
 6. Category discovery.
 7. Broader marketplace exploration.

 Do not render every possible horizontal rail merely because data exists. Consolidate duplicated or low-value sections and preserve full access through clear “see all” destinations.

 Each section must have:

 * Stable identity.
 * A clear purpose.
 * Appropriate heading semantics.
 * Optional subtitle only when it adds meaning.
 * One consistent “see all” pattern.
 * Independent loading, error, empty, and retry behavior.
 * Analytics impression behavior consistent with existing contracts.

 ### 5. Category and species discovery

 Retain access to every supported category and species.

 Improve the rail by:

 * Prioritizing the selected pet’s species when possible.
 * Maintaining stable, correctly localized ordering.
 * Showing a clear selected state without relying only on color.
 * Using predictable snapping.
 * Preserving the user’s selection.
 * Providing appropriate accessibility actions.
 * Preventing aggressive edge clipping.
 * Keeping the category rail secondary to the immediate Home purpose.

 ### 6. Unified card system

 Create a coherent family rather than forcing every content type into one generic card.

 #### Product card

 Display, when available:

 * Consistently framed product media.
 * Favorite state.
 * Concise two-line title.
 * Locale-aware price.
 * Original price and discount with correct semantics.
 * Availability or low-stock information.
 * In-cart quantity.
 * One clear primary action.

 #### Advertisement card

 Display, when available:

 * Media or video affordance.
 * Advertisement type.
 * Concise title.
 * Location.
 * Price.
 * Relevant pet metadata.
 * Favorite state.
 * One clear details action.

 #### Service card

 Display, when available:

 * Service identity.
 * Service category.
 * Provider or verification context.
 * Rating only when meaningful and supported by real data.
 * Availability or location context.
 * One details or booking destination consistent with existing behavior.

 Never render a prominent `0.0` rating as if it were trustworthy evidence. Treat missing ratings as missing data or use an honest “new” state when supported.

 #### Card consistency

 Across every card:

 * Use stable heights within the same card family.
 * Clamp text without hiding essential meaning.
 * Preserve touch targets of at least 44×44 points.
 * Distinguish enabled, disabled, in-cart, unavailable, notify, loading, success, and failure states.
 * Avoid color-only status.
 * Maintain correct RTL order.
 * Use stable identity, not collection indices.
 * Prevent partial content from being hidden by the tab bar.

 ### 7. Pet-profile module

 When no pet profile exists, position the create-pet module high enough to be discoverable.

 Explain the genuine benefits supplied by the application:

 * Relevant products.
 * Care organization.
 * Reminders.
 * Veterinary or service relevance.
 * Faster marketplace discovery.

 When profiles exist, replace the onboarding invitation with a compact switcher or pet summary rather than continuing to advertise profile creation.

 ### 8. Care and service hub

 Unify veterinary, pharmacy, and nearby services through a clear care destination.

 The Home preview should:

 * Differentiate medical, pharmacy, grooming, training, boarding, or other real categories.
 * Avoid implying medical certainty.
 * Respect location permission and missing-location states.
 * Offer manual discovery when location access is denied.
 * Avoid burying the care destination underneath repetitive commerce rails.

 ### 9. Persistent bottom navigation

 Inspect whether the tab bar is owned by Home or the application root.

 Preserve existing route semantics and central-create behavior.

 Refine its Home integration so:

 * The feed has the correct bottom content inset.
 * The final card remains fully reachable.
 * The central action has an accessible label and purpose.
 * Active state does not depend only on color.
 * Badge behavior remains correct.
 * Material remains legible above complex cards.
 * AX5 content does not collide.
 * The navigation is not duplicated inside SwiftUI if the root already owns it.

 ## Creativity and decoration contract

 Increase visual creativity deliberately, not excessively.

 Use an approximate balance of:

 * `80%` clarity, hierarchy, content, and action.
 * `20%` atmosphere, brand expression, and delight.

 The final Home should contain:

 1. One unmistakable signature hero moment.
 2. Two or three restrained micro-interactions.
 3. A small set of pet-specific decorative motifs.
 4. Meaningful variation between major section archetypes.
 5. No ambient clutter competing with commerce or care.

 Approved creative ingredients:

 * High-quality existing pet imagery or approved product imagery.
 * Soft contextual color auras.
 * Layered species cutouts.
 * Subtle depth and controlled elevation.
 * Small pet-context emblems.
 * A refined “pulse” or path motif connecting priority content.
 * Carefully placed highlights and soft color fields.
 * A premium contextual transition between pet, care, and marketplace modes.

 Decoration must:

 * Reinforce context.
 * Respect light and dark mode.
 * Maintain readable contrast.
 * disappear or simplify under Increased Contrast.
 * remain understandable with Reduce Motion.
 * avoid continuous energy-consuming animation.
 * avoid repeating the same line-and-dot decoration on every section.
 * avoid generic random gradients, glass bubbles, confetti, or decorative paw prints without purpose.

 Use existing assets and design tokens first. If a genuinely necessary visual asset is missing, create or source a proper raster asset through the permitted design workflow rather than approximating it with improvised UI shapes.

 ## Glass and material hierarchy

 Use glass for navigational or floating elevation:

 * Compact command bar.
 * Controlled hero controls.
 * Root tab bar where appropriate.
 * Small contextual floating actions.

 Prefer clear, calm surfaces for:

 * Product cards.
 * Advertisement cards.
 * Service cards.
 * Trust information.
 * Long-form content.

 Requirements:

 * No uncontrolled glass-on-glass stacking.
 * No material that allows underlying text to collide with foreground text.
 * No deployment-target increase for a visual effect.
 * Use availability-gated modern material APIs only when the current target supports them.
 * Provide an intentional fallback for older supported systems.
 * Centralize spacing, radius, elevation, color, typography, material, and motion tokens.

 ## Navigation and loading continuity

 Correct the recorded marketplace transition.

 When navigating from Home:

 * Preserve the source context.
 * Render the destination’s structure immediately.
 * Use geometry-matched or contextual continuity only when stable and supported.
 * Keep interactive back navigation intact.
 * Keep cancellation ownership clear.
 * Avoid an empty white shell.

 Skeleton requirements:

 * Match the final card and section geometry.
 * Preserve layout while data loads.
 * Use restrained shimmer or opacity behavior.
 * Disable unnecessary shimmer under Reduce Motion.
 * Load sections progressively without moving already visible controls.
 * Fade imagery into its reserved frame.
 * Provide section-level retry instead of replacing the entire destination where possible.

 The back transition must not expose:

 * A split-screen seam.
 * Blank content.
 * Incorrect snapshots.
 * Material bubbles or distortion.
 * Duplicated tab or navigation bars.

 ## Complete Home state matrix

 Implement and verify every reachable applicable state.

 ### Screen states

 * Cold initial load.
 * Warm cached load.
 * Loaded.
 * Partial data.
 * Pull-to-refresh.
 * Background refresh.
 * Section pagination.
 * Global failure.
 * Section failure.
 * Offline with cache.
 * Offline without cache.
 * Stale cache.
 * Empty Home.
 * Authentication required.
 * Session changed.
 * Language changed.
 * Deep-link entry.
 * Background return.

 ### Pet states

 * No pet profile.
 * One pet.
 * Multiple pets.
 * Missing pet photo.
 * Deleted or unavailable profile.
 * Pet switch.
 * Stale pet context.

 ### Location states

 * Location available.
 * Permission not determined.
 * Permission denied.
 * Restricted.
 * Location failure.
 * Nearby results empty.
 * Manual-area fallback.

 ### Card states

 * Idle.
 * Pressed.
 * Selected.
 * Favorite.
 * Favorite mutation.
 * Favorite failure.
 * Available.
 * Low stock.
 * Unavailable.
 * Notify supported.
 * Notify loading.
 * Notification registered.
 * Notify failure.
 * Add-to-cart idle.
 * Add-to-cart loading.
 * Add success.
 * Add failure.
 * Already in cart.
 * Maximum quantity.
 * Price changed.
 * Inventory changed.
 * Missing image.
 * Image loading.
 * Image failure.
 * Missing rating.
 * Missing seller or provider.
 * Repeated tap.

 ### Layout and environment states

 * Arabic RTL.
 * English LTR.
 * Light mode.
 * Dark mode.
 * Increased Contrast.
 * Differentiate Without Color.
 * Reduce Motion.
 * Dynamic Type XS through AX5.
 * Supported portrait sizes.
 * Supported landscape behavior.
 * Any regular-width layout genuinely supported by the application.

 Mark genuinely inapplicable states `N/A` with evidence. Do not silently omit them.

 ## Arabic and localization

 Arabic must look authored—not mirrored.

 * Use one shared locale-aware price formatter throughout Home and every Home card.
 * Never manually concatenate the amount with `QAR` or `ر.ق`.
 * Protect currency and numbers from bidirectional reordering.
 * Replace raw `1000G`-style presentation with the project’s localized measurement formatter.
 * Format weights, quantities, percentages, distances, and dates consistently.
 * Use localized user-facing strings.
 * Use leading and trailing alignment.
 * Flip only directional symbols.
 * Preserve neutral icons such as hearts, stars, search, cart, media, and pet imagery.
 * Use RTL-aware carousels and snapping.
 * Test Arabic content at least 30% longer than the current examples.
 * Maintain a genuinely authored English LTR layout.
 * Review Arabic spacing, punctuation, grammar, truncation, and price order.
 * Keep category, product, service, and availability wording consistent across Home and destination screens.

 ## Accessibility

 Verify behavior rather than inferring it from screenshots.

 * Give every action a meaningful accessibility label, value, trait, and hint where necessary.
 * Use proper headings for major Home sections.
 * Keep VoiceOver order aligned with the visual priority.
 * Combine card content into a useful summary instead of producing excessive stops.
 * Provide card custom actions for favorite, add, notify, or details when appropriate.
 * Make horizontal rails understandable and navigable with VoiceOver.
 * Announce pet switches, refresh results, cart changes, notify registration, and failures.
 * Give the central-create action an explicit purpose.
 * Keep all touch targets at least 44×44 points.
 * Maintain at least 4.5:1 contrast for normal text.
 * Maintain appropriate contrast for large text and meaningful controls.
 * Do not encode availability, selection, or success through color alone.
 * Support Voice Control and Switch Control through semantic controls.
 * Ensure AX5 does not clip titles, prices, section destinations, or essential actions.
 * Preserve all meaning under Reduce Motion.
 * Pause automatic hero transitions while VoiceOver is active.

 ## SwiftUI engineering

 * Preserve the project’s deployment target and toolchain.
 * Follow the architecture already established in the repository.
 * Keep authoritative UI state on the correct actor.
 * Use the observation mechanism supported by the deployment target and current project.
 * Give async tasks explicit ownership and cancellation.
 * Keep navigation in the existing coordinator or a deliberate adapter.
 * Keep API and persistence logic outside `View.body`.
 * Use stable IDs for every section and item.
 * Build the feed with lazy containers.
 * Avoid deeply nested scrolling containers and uncontrolled geometry feedback.
 * Calculate formatters, section models, and expensive derived values outside `body`.
 * Decode and resize images off the main thread.
 * Reuse the existing image cache when valid and keep caching bounded.
 * Prevent duplicate subscriptions, duplicate requests, retain cycles, and abandoned tasks.
 * Debounce or deduplicate repeated refresh, favorite, notify, and cart mutations.
 * Preserve analytics impression timing without duplicate fires caused by SwiftUI updates.
 * Keep previews and fixtures isolated from production.
 * Keep unrelated files and existing user changes intact.
 * Remove legacy target memberships, dead cells, duplicate public classes, and backup implementations once parity is confirmed.

 ## Performance

 Target excellent perceived performance on the required iPhone 13 Pro Max.

 * Keep scrolling, horizontal rails, hero transitions, sticky-header morphing, tab interaction, and image loading smooth.
 * Aim for the available ProMotion frame budget without claiming a fixed refresh rate.
 * Keep synchronous I/O and image decoding off the main thread.
 * Avoid eager creation of the complete long feed.
 * Load offscreen sections lazily.
 * Bound image prefetching and caches.
 * Cancel invisible section work.
 * Prevent unstable identity and full-feed invalidation from a single card mutation.
 * Preserve already loaded content during background refresh.
 * Profile cold entry, warm entry, refresh, deep scroll, rapid horizontal swiping, category changes, pet switching, navigation, and memory growth.
 * Inspect leaks around the Objective-C host, SwiftUI hosting controller, store, coordinators, notifications, and async tasks.

 ## Controlled migration sequence

 1. Capture a clean baseline build and behavioral evidence.
 2. Complete symbol, caller, behavior, analytics, and ownership ledgers.
 3. Isolate existing APIs and models behind repository-consistent adapters.
 4. Introduce the SwiftUI host while preserving Objective-C entry contracts.
 5. Implement the authoritative Home store and complete state model.
 6. Implement the adaptive command bar and Pet Pulse Hero.
 7. Migrate category and priority actions.
 8. Migrate one card family and one section family at a time.
 9. Verify parity for each vertical slice.
 10. Remove that slice’s legacy owner after validation.
 11. Complete care, nearby, pet-profile, recommendations, and reorder modules.
 12. Correct navigation, loading, sticky surfaces, and safe-area integration.
 13. Finish localization, accessibility, state, and performance validation.
 14. Remove the legacy Home layout path and unused target memberships.
 15. Confirm that only one visible production Home remains.

 A temporary development feature flag may be used during migration. The final production result must not keep two independently maintained Home implementations.

 ## Required validation

 Use the repository’s actual workspace, scheme, signing, and device workflow.

 Runtime validation must use only the already-connected iPhone 13 Pro Max:

 * Do not substitute a simulator.
 * Do not use another device.
 * Do not change signing, provisioning, bundle identifiers, or unrelated project settings.

 Validate:

 * Baseline build.
 * Final build.
 * Relevant unit tests.
 * Relevant UI tests.
 * Snapshot tests where available.
 * Arabic and English.
 * Light and dark mode.
 * Normal text and AX5.
 * Increased Contrast.
 * Reduce Motion.
 * VoiceOver reading order and actions.
 * Cold and warm loading.
 * Offline and partial data.
 * Missing images.
 * Empty sections.
 * Pet-profile absence and presence.
 * Category switching.
 * Cart and favorites.
 * Unavailable and notify states.
 * Location denied and nearby empty.
 * Every Home destination.
 * Interactive back navigation.
 * Memory and performance.

 Capture before-and-after evidence at equivalent Home states and device conditions.

 If the required device is unavailable, complete every safe static, build, and test action possible, then mark device-dependent results `UNVERIFIED`. Do not convert missing evidence into a pass.

 ## CodeRabbit review

 After the real implementation diff exists, run CodeRabbit when its CLI and authentication are available.

 Use the scope that matches the final diff, such as:

 `coderabbit review --agent -t uncommitted`

 Include the relevant repository configuration when present.

 * Treat only actual CodeRabbit output as CodeRabbit evidence.
 * Resolve all applicable critical and major issues.
 * Resolve relevant minor issues when they improve safety or maintainability.
 * Re-run the review after corrections.
 * If the service is unavailable, unauthenticated, or blocked, report the exact status as `UNVERIFIED`.
 * Do not label a manual review as CodeRabbit output.

 ## Anti-template gates

 The final Home must pass:

 1. **Five-second test:** The user understands the current context and primary next action immediately.
 2. **Pet relevance test:** The hierarchy meaningfully changes when genuine pet context changes.
 3. **No-pet test:** The Home remains useful and welcoming without a pet profile.
 4. **Logo-removal test:** It still feels unmistakably like Pure Pets.
 5. **Template test:** Replacing pet content with unrelated retail products breaks the design logic.
 6. **One-thumb test:** Search, cart, priority actions, and primary cards remain practically reachable.
 7. **Safe-dead test:** Empty, unavailable, offline, stale, denied, and failed states still provide a useful next step.
 8. **RTL-native test:** Arabic feels deliberately authored.
 9. **Reduce-Motion test:** All meaning remains without movement.
 10. **AX5 test:** Nothing clips, overlaps, disappears, or blocks an essential action.
 11. **Repeat-visit test:** Returning customers see useful continuity, not only promotional repetition.
 12. **Decoration test:** The result feels more creative and premium without becoming busy or childish.

 Revise the implementation whenever an applicable gate fails.

 ## 100-point release gate

 Award points only from actual finished evidence:

 * Contract integrity: `25 points`.
 * Creative direction: `20 points`.
 * Production behavior: `15 points`.
 * Accessibility and localization: `15 points`.
 * Engineering health: `15 points`.
 * Performance: `10 points`.

 Full credit requires:

 ### Contract integrity — 25

 * Every route, caller, callback, analytics event, notification, state mutation, persistence key, and runtime requirement is preserved.
 * Exactly one active Home owner remains.

 ### Creative direction — 20

 * Product promise and design DNA are explicit.
 * All three structural concepts were evaluated.
 * Pure Pets Pulse was implemented or an evidence-backed alternative was documented.
 * The semantic visual system is coherent.
 * The Home contains one distinctive signature moment.
 * Decoration remains restrained and purposeful.

 ### Production behavior — 15

 * All applicable loading, loaded, partial, empty, failure, offline, stale, denied, retry, cancellation, and navigation states are reachable and useful.

 ### Accessibility and localization — 15

 * Arabic and English are complete.
 * Currency and measurement formatting are unified.
 * VoiceOver, Dynamic Type, RTL, contrast, target size, Reduce Motion, and state announcements are validated.

 ### Engineering health — 15

 * The permitted build and tests pass.
 * Deployment compatibility is preserved.
 * Ownership and async work are safe.
 * Files remain focused.
 * Legacy duplicates are removed.
 * No unrelated user changes are overwritten.

 ### Performance — 10

 * Identity and work are stable and bounded.
 * Real-device evidence covers entry, feed scrolling, horizontal interaction, navigation, image loading, memory, and leaks.
 * Every numeric performance claim is supported by measured evidence.

 Release is blocked by:

 * Contract regression.
 * Missing or duplicate runtime ownership.
 * Required build failure.
 * Incompatible deployment API.
 * Blank or broken Home navigation.
 * Trapped essential state.
 * RTL meaning failure.
 * Accessibility blocker.
 * Fabricated build, device, CodeRabbit, accessibility, or performance evidence.
 * A generic template result.
 * A legacy Objective-C Home layout still actively competing with the SwiftUI Home.

 Target a verified `100/100`.

 Do not stop voluntarily at planning, visual parity, compilation, or a subjective claim of “premium.” Continue implementing, testing, inspecting, and correcting until every independently verifiable in-scope point is earned.

 If a genuinely external blocker prevents full verification, complete everything else, mark only the blocked item `UNVERIFIED`, state the exact blocker, and do not claim 100/100.

 ## Final handoff

 Return a concise Fidelity and Architecture Manifest containing:

 1. Final outcome.
 2. Changed files.
 3. Removed or deactivated Objective-C owners.
 4. Remaining compatibility bridge and why it is required.
 5. Symbol and call-site ledger summary.
 6. Preserved behavior and analytics evidence.
 7. Product DNA Card.
 8. Three concept scores.
 9. Selected concept and rejection reasons.
 10. Implemented Home hierarchy.
 11. Signature Pet Pulse behavior.
 12. Creativity and decoration decisions.
 13. Before-and-after state matrix.
 14. Arabic and English results.
 15. Accessibility results.
 16. Build and test commands with real outcomes.
 17. iPhone 13 Pro Max validation evidence.
 18. Performance and leak evidence.
 19. CodeRabbit results or exact `UNVERIFIED` status.
 20. Remaining risks.
 21. Transparent 100-point scorecard.

 Return production code and evidence—not another recommendation list.

 
 
 */
