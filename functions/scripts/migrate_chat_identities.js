/* eslint-disable no-console */

/**
 * One-time migration utility:
 * - Normalizes chat member/sender/receiver identities to Firebase Auth UID.
 * - Uses UsersCol mapping from legacy ID -> uid.
 *
 * Usage examples:
 *   node scripts/migrate_chat_identities.js --dry-run
 *   node scripts/migrate_chat_identities.js --limit=200
 *   node scripts/migrate_chat_identities.js --thread-id=<threadId>
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function parseArgs(argv) {
  const args = {
    dryRun: false,
    limit: 200,
    threadId: "",
    usersLimit: 5000,
  };

  for (const raw of argv.slice(2)) {
    if (raw === "--dry-run") {
      args.dryRun = true;
      continue;
    }
    if (raw.startsWith("--limit=")) {
      const n = Number(raw.split("=")[1]);
      if (Number.isInteger(n) && n > 0) {
        args.limit = Math.min(n, 2000);
      }
      continue;
    }
    if (raw.startsWith("--users-limit=")) {
      const n = Number(raw.split("=")[1]);
      if (Number.isInteger(n) && n > 0) {
        args.usersLimit = Math.min(n, 50000);
      }
      continue;
    }
    if (raw.startsWith("--thread-id=")) {
      args.threadId = String(raw.split("=")[1] || "").trim();
    }
  }

  return args;
}

function asString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeList(value) {
  if (!Array.isArray(value)) return [];
  return value.map((v) => asString(v)).filter(Boolean);
}

async function buildLegacyToUidMap(usersLimit) {
  const map = new Map();
  const usersSnap = await db.collection("UsersCol").limit(usersLimit).get();

  for (const doc of usersSnap.docs) {
    const uid = doc.id;
    const data = doc.data() || {};
    const idField = asString(data.ID);
    const uidField = asString(data.uid);

    map.set(uid, uid);
    if (idField) map.set(idField, uid);
    if (uidField) map.set(uidField, uid);
  }

  return map;
}

function resolveIdentity(idMap, value) {
  const raw = asString(value);
  if (!raw) return "";
  return idMap.get(raw) || raw;
}

async function migrateThread(idMap, threadDoc, dryRun) {
  const data = threadDoc.data() || {};
  const oldMembers = normalizeList(data.members);
  const newMembers = oldMembers.map((m) => resolveIdentity(idMap, m));

  const membersChanged =
    oldMembers.length === newMembers.length &&
    oldMembers.some((m, i) => m !== newMembers[i]);

  const messageSnap = await threadDoc.ref.collection("Messages").get();
  const messageUpdates = [];

  for (const msg of messageSnap.docs) {
    const msgData = msg.data() || {};
    const oldSender = asString(msgData.senderID);
    const oldReceiver = asString(msgData.receiverID);
    const newSender = resolveIdentity(idMap, oldSender);
    const newReceiver = resolveIdentity(idMap, oldReceiver);

    const payload = {};
    if (oldSender && newSender && oldSender !== newSender) payload.senderID = newSender;
    if (oldReceiver && newReceiver && oldReceiver !== newReceiver) payload.receiverID = newReceiver;

    if (Object.keys(payload).length > 0) {
      messageUpdates.push({
        ref: msg.ref,
        payload,
      });
    }
  }

  if (membersChanged || messageUpdates.length > 0) {
    if (!dryRun) {
      const batch = db.batch();
      if (membersChanged) {
        batch.update(threadDoc.ref, {
          members: newMembers,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      for (const update of messageUpdates) {
        batch.update(update.ref, update.payload);
      }
      await batch.commit();
    }
  }

  return {
    threadId: threadDoc.id,
    membersChanged,
    messagesChanged: messageUpdates.length,
  };
}

async function run() {
  const { dryRun, limit, threadId, usersLimit } = parseArgs(process.argv);

  console.log(
    `[ChatIdentityMigration] start dryRun=${dryRun} limit=${limit} usersLimit=${usersLimit} threadId=${threadId || "ALL"}`
  );

  const idMap = await buildLegacyToUidMap(usersLimit);
  console.log(`[ChatIdentityMigration] identity map size=${idMap.size}`);

  let threadsSnap;
  if (threadId) {
    const doc = await db.collection("Chats").doc(threadId).get();
    threadsSnap = { docs: doc.exists ? [doc] : [] };
  } else {
    threadsSnap = await db.collection("Chats").limit(limit).get();
  }

  let processed = 0;
  let touched = 0;
  let threadsMembersUpdated = 0;
  let messagesUpdated = 0;

  for (const threadDoc of threadsSnap.docs) {
    processed += 1;
    const result = await migrateThread(idMap, threadDoc, dryRun);
    if (result.membersChanged || result.messagesChanged > 0) {
      touched += 1;
      if (result.membersChanged) threadsMembersUpdated += 1;
      messagesUpdated += result.messagesChanged;
    }
    console.log(
      `[ChatIdentityMigration] thread=${result.threadId} membersChanged=${result.membersChanged} messagesChanged=${result.messagesChanged}`
    );
  }

  console.log("[ChatIdentityMigration] done");
  console.log(
    JSON.stringify(
      {
        dryRun,
        processed,
        touched,
        threadsMembersUpdated,
        messagesUpdated,
      },
      null,
      2
    )
  );
}

run().catch((error) => {
  console.error("[ChatIdentityMigration] failed", error);
  process.exit(1);
});
