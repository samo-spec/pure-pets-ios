---
name: pure-pets-firebase-mission-control-v3
description: Project-local launcher for the canonical Pure Pets Firebase Mission Control V3 package in PPAgent. Use for PPOrder, payments, refunds, fulfillment, delivery, Notifications V2, Chats V2, Firestore/Storage rules, Cloud Functions, authorization, App Check, migrations, incidents, reliability, or backend evidence.
---

# Pure Pets Firebase Mission Control V3 — Project Launcher

Before backend work, resolve and read the canonical V3 `SKILL.md` in this order:

1. `$PPAGENT_ROOT/pure-pets-firebase-mission-control-v3/skills/pure-pets-firebase-mission-control-v3/SKILL.md` when `PPAGENT_ROOT` is set.
2. `../PPAgents/pure-pets-firebase-mission-control-v3/skills/pure-pets-firebase-mission-control-v3/SKILL.md`.
3. `../PPAgent/pure-pets-firebase-mission-control-v3/skills/pure-pets-firebase-mission-control-v3/SKILL.md`.
4. `.agents/vendor/pure-pets-firebase-mission-control-v3/SKILL.md`, created by `scripts/install_ppagent_skills.sh`.

Treat the canonical package as authoritative and read whatever references it requires for the selected mode. Do not replace its rules with this launcher.

Until the canonical source is loaded, preserve these verified V3 hard gates:

- Firebase project identity must be exactly `pure-pets-49199`.
- `Pure Pets Infra/` is backend authority; clients are command callers/projection consumers.
- Notifications V2 and Chats V2 are the only notification/chat authorities. Never introduce or preserve a legacy fallback, dual writer, direct-FCM fallback, legacy token route, or legacy inbox route.
- Protected commands must validate auth/account state/permission or ownership/App Check where applicable/input/version before business logic, then produce audit/event/outbox evidence as required.
- Treat triggers, queues, schedulers, webhooks, and notification dispatch as at-least-once unless stronger evidence proves otherwise; make business effects idempotent.
- Never weaken rules, disable App Check, expose secrets, deploy, write production data, change claims, replay jobs, or send a production notification without explicit authorization for that exact mutation and target.
- Never convert static inspection, package tests, emulator tests, or an internal score into production certification.

If the canonical V3 source cannot be resolved, stop before making backend mutations and report the missing source.
