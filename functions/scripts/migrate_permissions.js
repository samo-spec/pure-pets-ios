#!/usr/bin/env node

/* eslint-disable no-console */

const admin = require("firebase-admin");

const USERS_COLLECTION = "UsersCol";
const CANONICAL_PERMISSIONS_SUBCOLLECTION = "permissions";
const LEGACY_PERMISSIONS_SUBCOLLECTION = "PermisstionsCol";
const LEGACY_PERMISSIONS_SUBCOLLECTION_ALT = "PermissionsCol";
const LEGACY_PERMISSION_SUBCOLLECTIONS = [
  LEGACY_PERMISSIONS_SUBCOLLECTION,
  LEGACY_PERMISSIONS_SUBCOLLECTION_ALT,
];

const LEGACY_PERMISSION_ALIASES = {
  ManageUsers: "Adoption",
  ManageNotificatiuons: "Moderation",
  ManageNotifications: "Moderation",
  ManageBanners: "PostAds",
  Prodection: "production",
};

function parseArgs(argv) {
  const args = {
    uid: "",
    limit: 200,
    dryRun: false,
    removeDeprecated: false,
    actorUid: process.env.MIGRATION_ACTOR_UID || "migration-script",
    projectId: process.env.FIREBASE_PROJECT_ID || "",
  };

  for (const raw of argv.slice(2)) {
    if (raw === "--dry-run") {
      args.dryRun = true;
      continue;
    }
    if (raw === "--remove-deprecated") {
      args.removeDeprecated = true;
      continue;
    }
    if (raw.startsWith("--uid=")) {
      args.uid = raw.slice("--uid=".length).trim();
      continue;
    }
    if (raw.startsWith("--limit=")) {
      const n = Number(raw.slice("--limit=".length));
      if (Number.isInteger(n) && n > 0) {
        args.limit = Math.min(n, 1000);
      }
      continue;
    }
    if (raw.startsWith("--actor-uid=")) {
      args.actorUid = raw.slice("--actor-uid=".length).trim() || args.actorUid;
      continue;
    }
    if (raw.startsWith("--project-id=")) {
      args.projectId = raw.slice("--project-id=".length).trim();
      continue;
    }
  }

  return args;
}

function canonicalPermissionKey(rawKey) {
  const key = String(rawKey || "").trim();
  if (!key) return "";
  return LEGACY_PERMISSION_ALIASES[key] || key;
}

function mapFromSnapshot(snapshot) {
  const out = {};
  for (const doc of snapshot.docs) {
    const canonicalKey = canonicalPermissionKey(doc.id);
    if (!canonicalKey) continue;
    out[canonicalKey] = doc.get("allowed") === true;
  }
  return out;
}

async function resolveUsersToProcess(db, uid, limit) {
  if (uid) return [uid];
  const snap = await db.collection(USERS_COLLECTION).limit(limit).get();
  return snap.docs.map((d) => d.id);
}

async function migrateSingleUser(db, uid, options) {
  const userRef = db.collection(USERS_COLLECTION).doc(uid);
  const canonicalCol = userRef.collection(CANONICAL_PERMISSIONS_SUBCOLLECTION);
  const legacyCols = LEGACY_PERMISSION_SUBCOLLECTIONS.map((name) => userRef.collection(name));

  const [userSnap, canonicalSnap, ...legacySnaps] = await Promise.all([
    userRef.get(),
    canonicalCol.get(),
    ...legacyCols.map((col) => col.get()),
  ]);

  const canonicalMap = mapFromSnapshot(canonicalSnap);
  const legacyMap = {};
  for (const snapshot of legacySnaps) {
    Object.assign(legacyMap, mapFromSnapshot(snapshot));
  }
  const legacyDocs = legacySnaps.flatMap((snapshot) => snapshot.docs || []);

  const merged = { ...legacyMap, ...canonicalMap };
  const patchToCanonical = {};
  for (const [key, allowed] of Object.entries(merged)) {
    if (!(key in canonicalMap)) {
      patchToCanonical[key] = allowed;
    }
  }

  const shouldSyncAdminAll = Object.prototype.hasOwnProperty.call(merged, "AdminAll");
  const adminAll = shouldSyncAdminAll ? merged.AdminAll === true : undefined;

  if (!options.dryRun) {
    const batch = db.batch();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const actorUid = options.actorUid || "migration-script";

    for (const [key, allowed] of Object.entries(patchToCanonical)) {
      batch.set(
        canonicalCol.doc(key),
        {
          allowed,
          updatedAt: now,
          updatedBy: actorUid,
          source: "migration-script",
          migratedFrom: LEGACY_PERMISSIONS_SUBCOLLECTION,
        },
        { merge: true }
      );
    }

    if (shouldSyncAdminAll) {
      const profilePatch = {
        isAdminAll: adminAll,
        updatedAt: now,
      };
      if (adminAll && userSnap.exists && userSnap.get("isAdmin") !== true) {
        profilePatch.isAdmin = true;
      }
      batch.set(userRef, profilePatch, { merge: true });
    }

    if (options.removeDeprecated) {
      for (const legacyDoc of legacyDocs) {
        batch.delete(legacyDoc.ref);
      }
    }

    if (Object.keys(patchToCanonical).length > 0 || options.removeDeprecated || shouldSyncAdminAll) {
      batch.set(
        db.collection("AdminAuditLogs").doc(),
        {
          adminUid: actorUid,
          targetUid: uid,
          action: "migrate_permissions_script",
          before: {
            canonicalCount: canonicalSnap.docs.length,
            legacyCount: legacyDocs.length,
          },
          after: {
            wroteCanonicalKeys: Object.keys(patchToCanonical),
            removeDeprecated: options.removeDeprecated,
            adminAllSynced: shouldSyncAdminAll,
          },
          reason: "permissions model migration",
          note: "",
          timestamp: now,
        },
        { merge: true }
      );
    }

    await batch.commit();
  }

  return {
    uid,
    canonicalCount: canonicalSnap.docs.length,
    legacyCount: legacyDocs.length,
    wroteCanonicalKeys: Object.keys(patchToCanonical),
    removeDeprecated: options.removeDeprecated,
    dryRun: options.dryRun,
  };
}

async function main() {
  const options = parseArgs(process.argv);

  if (!admin.apps.length) {
    const initConfig = options.projectId ? { projectId: options.projectId } : {};
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      ...initConfig,
    });
  }

  const db = admin.firestore();
  const users = await resolveUsersToProcess(db, options.uid, options.limit);

  const summary = {
    dryRun: options.dryRun,
    removeDeprecated: options.removeDeprecated,
    processed: 0,
    migrated: 0,
    users: [],
  };

  for (const uid of users) {
    const result = await migrateSingleUser(db, uid, options);
    summary.processed += 1;
    if (result.wroteCanonicalKeys.length > 0 || result.removeDeprecated) {
      summary.migrated += 1;
    }
    summary.users.push(result);
    console.log(
      `[migrate_permissions] ${uid} canonical=${result.canonicalCount} legacy=${result.legacyCount} wrote=${result.wroteCanonicalKeys.length}`
    );
  }

  console.log("\nMigration summary:");
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error("[migrate_permissions] failed:", error);
  process.exit(1);
});
