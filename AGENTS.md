# Pure Pets Codex Agent Routing

This repository uses two mandatory PPAgent skills. Keep `CLAUDE.md` as the repository architecture/build contract; the skills below add task-specific authority and quality gates.

## Mandatory skills

### SwiftyMax NextGen Category-Defining V6
Use `$swiftymax-nextgen-category-defining-v6` for every iOS UI/UX task: create, redesign, refactor, polish, animation, layout, accessibility, RTL, design-system, rendered review, or visual scoring.

### Pure Pets Firebase Mission Control V3
Use `$pure-pets-firebase-mission-control-v3` for every Firebase/backend task: PPOrder, payments/refunds, fulfillment/delivery, Notifications V2, Chats V2, Firestore/Storage rules, Cloud Functions, authorization, App Check, queues, migrations, incidents, reliability, or backend evidence.

## Cross-cutting work
When a task touches both UI and backend behavior, load both skills. Mission Control V3 owns backend truth, lifecycle invariants, authority, and safety. SwiftyMax V6 owns iOS presentation, interaction, accessibility, motion, and visual quality. Do not let a UI redesign change backend semantics unless the user explicitly authorizes that backend change.

## Canonical PPAgent source
The repo-local wrappers under `.agents/skills/` resolve the canonical source from a sibling `PPAgents`/`PPAgent` checkout or from `.agents/vendor/` after running `scripts/install_ppagent_skills.sh`.

Never invent missing skill rules. If the canonical source cannot be resolved, report that source as unavailable rather than silently substituting generic guidance.
