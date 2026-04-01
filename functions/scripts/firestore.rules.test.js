/* eslint-disable no-console */

const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  collectionGroup,
  doc,
  endAt,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  startAt,
  updateDoc,
  where,
} = require("firebase/firestore");

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || "demo-pure-pets";
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.GOOGLE_CLOUD_PROJECT = PROJECT_ID;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: PROJECT_ID });

const functionsExports = require("../index.js");
const admin = require("firebase-admin");
const HOST_PORT = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const [HOST, PORT_STR] = HOST_PORT.split(":");
const PORT = Number(PORT_STR || "8080");

const RULES_PATH = path.join(__dirname, "..", "..", "firestore.rules");
const RULES = fs.readFileSync(RULES_PATH, "utf8");

let testEnv;

function now() {
  return new Date("2026-02-18T00:00:00.000Z");
}

function userProfile(uid, overrides = {}) {
  return {
    ID: uid,
    uid,
    UserName: `User ${uid}`,
    UserEmail: `${uid}@example.com`,
    email: `${uid}@example.com`,
    role: 1,
    isAdmin: false,
    isSuperAdmin: false,
    isAdminAll: false,
    isBlocked: false,
    createdAt: now(),
    updatedAt: now(),
    ...overrides,
  };
}

function publicUserProfile(uid, overrides = {}) {
  return {
    uid,
    displayName: `Public ${uid}`,
    photoURL: `https://example.com/${uid}.jpg`,
    canReceiveMessages: true,
    updatedAt: now(),
    ...overrides,
  };
}

function userPresence(uid, overrides = {}) {
  return {
    uid,
    online: true,
    updatedAt: now(),
    ...overrides,
  };
}

async function seedDoc(pathValue, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), pathValue), data);
  });
}

async function seedUser(uid, overrides = {}) {
  await seedDoc(`UsersCol/${uid}`, userProfile(uid, overrides));
}

async function seedAdminDoc(pathValue, data) {
  await admin.firestore().doc(pathValue).set(data);
}

async function seedPermission(uid, key, allowed, legacy = false) {
  const sub = legacy ? "PermisstionsCol" : "permissions";
  await seedDoc(`UsersCol/${uid}/${sub}/${key}`, {
    allowed: allowed === true,
    updatedAt: now(),
    updatedBy: "test-seed",
  });
}

function authedDb(uid, token = {}) {
  return testEnv.authenticatedContext(uid, token).firestore();
}

function anonDb() {
  return testEnv.unauthenticatedContext().firestore();
}

const tests = [];
function it(name, fn) {
  tests.push({ name, fn });
}

it("normal user can create own profile but not another user's profile", async () => {
  const alice = authedDb("alice");

  await assertSucceeds(
    setDoc(doc(alice, "UsersCol/alice"), userProfile("alice"))
  );
  await assertFails(
    setDoc(doc(alice, "UsersCol/bob"), userProfile("bob"))
  );
});

it("blocked user is denied writes to restricted collections", async () => {
  await seedUser("blocked-user", { isBlocked: true });
  await seedPermission("blocked-user", "PostAds", true);

  const blockedDb = authedDb("blocked-user");
  await assertFails(
    setDoc(doc(blockedDb, "pet_ads/ad_blocked"), {
      ownerID: "blocked-user",
      category: "pets",
      status: 1,
      visibility: 0,
      isApproved: true,
      latitude: 25.2854,
      longitude: 51.531,
      geohash: "thrhm",
      createdAt: now(),
      updatedAt: now(),
    })
  );
});

it("privileged admin can write AdminAuditLogs and non-privileged user cannot", async () => {
  await seedUser("admin-1", { isAdmin: true, role: 5 });
  await seedUser("user-1");

  const adminDb = authedDb("admin-1", { admin: true, roleValue: 5 });
  const userDb = authedDb("user-1");

  const payload = {
    adminUid: "admin-1",
    targetUid: "user-1",
    action: "set_permission",
    before: {},
    after: { permission: "PostAds", allowed: true },
    timestamp: now(),
    reason: "test",
    note: "",
  };

  await assertSucceeds(setDoc(doc(adminDb, "AdminAuditLogs/log_1"), payload));

  await assertFails(
    setDoc(doc(userDb, "AdminAuditLogs/log_2"), {
      ...payload,
      adminUid: "user-1",
    })
  );
});

it("payment manager can write payment audit logs but cannot write non-payment admin audit logs", async () => {
  await seedUser("payments-admin");
  await seedPermission("payments-admin", "ManageStore", true);

  const paymentsDb = authedDb("payments-admin");

  await assertSucceeds(
    setDoc(doc(paymentsDb, "AdminAuditLogs/log_pay_1"), {
      auditId: "log_pay_1",
      area: "payments",
      action: "manual_approve_order",
      entityType: "order",
      entityId: "order_1",
      orderId: "order_1",
      requestId: "",
      adminUid: "payments-admin",
      adminName: "Payments Admin",
      note: "Approved after review",
      before: { status: "pending" },
      after: { status: "paid" },
      createdAt: now(),
    })
  );

  await assertFails(
    setDoc(doc(paymentsDb, "AdminAuditLogs/log_pay_2"), {
      adminUid: "payments-admin",
      targetUid: "user-1",
      action: "set_permission",
      before: {},
      after: { permission: "PostAds", allowed: true },
      timestamp: now(),
      reason: "test",
      note: "",
    })
  );
});

it("store manager role can read orders without an explicit ManageStore permission doc", async () => {
  await seedUser("store-role-user", {
    role: 6,
    roleValue: 6,
    roleName: "storemanager",
  });
  await seedDoc("Orders/order_role_1", {
    orderId: "order_role_1",
    userId: "buyer-role-1",
    uid: "buyer-role-1",
    items: [],
    amount: 25,
    totalAmount: 25,
    currency: "QAR",
    paymentProvider: "QIB",
    status: "pending",
    shippingAddressId: "addr_1",
    shippingAddressSnapshot: {
      userID: "buyer-role-1",
      addressID: "addr_1",
      fullName: "Buyer Role",
      addressLine1: "Doha",
      postalCode: "1000",
      cityID: 1,
      stateID: 1,
    },
    createdAt: now(),
    updatedAt: now(),
  });

  const storeRoleDb = authedDb("store-role-user");
  await assertSucceeds(
    getDocs(query(collection(storeRoleDb, "Orders"), orderBy("updatedAt", "desc")))
  );
});

it("store manager role can read payment audit logs when the query is constrained to payments area", async () => {
  await seedUser("store-role-audit", {
    role: 6,
    roleValue: 6,
    roleName: "storemanager",
  });
  await seedDoc("AdminAuditLogs/audit_payment_1", {
    auditId: "audit_payment_1",
    area: "payments",
    action: "manual_review",
    entityType: "order",
    entityId: "order_role_audit_1",
    orderId: "order_role_audit_1",
    requestId: "",
    adminUid: "admin-1",
    adminName: "Admin One",
    note: "",
    before: { status: "pending" },
    after: { status: "paid" },
    createdAt: now(),
  });

  const storeRoleDb = authedDb("store-role-audit");
  await assertSucceeds(
    getDocs(
      query(
        collection(storeRoleDb, "AdminAuditLogs"),
        where("orderId", "==", "order_role_audit_1"),
        where("area", "==", "payments")
      )
    )
  );
});

it("removed/unknown permission keys do not grant adoption access", async () => {
  await seedUser("legacy-user");
  await seedPermission("legacy-user", "PostAds", false);
  await seedPermission("legacy-user", "ManageUsersDeprecated", true, true);

  const legacyDb = authedDb("legacy-user");
  await assertFails(
    setDoc(doc(legacyDb, "adopt_pets/adopt_1"), {
      ownerID: "legacy-user",
      createdAt: now(),
      updatedAt: now(),
    })
  );
});

it("new permissions grant/deny service management correctly", async () => {
  await seedUser("service-allowed");
  await seedPermission("service-allowed", "ManageServices", true);

  await seedUser("service-denied");
  await seedPermission("service-denied", "PostAds", false);

  const allowedDb = authedDb("service-allowed");
  const deniedDb = authedDb("service-denied");

  await assertSucceeds(
    setDoc(doc(allowedDb, "serviceOffers/service_1"), {
      serviceOwnerID: "service-allowed",
      createdAt: now(),
      updatedAt: now(),
    })
  );

  await assertFails(
    setDoc(doc(deniedDb, "serviceOffers/service_2"), {
      serviceOwnerID: "service-denied",
      createdAt: now(),
      updatedAt: now(),
    })
  );
});

it("chat delivery/read receipts update works for receiver only and blocks content edits", async () => {
  await seedUser("alice");
  await seedUser("bob");

  await seedDoc("Chats/thread_1", {
    members: ["alice", "bob"],
    createdAt: now(),
    updatedAt: now(),
  });

  await seedDoc("Chats/thread_1/Messages/msg_1", {
    ID: "msg_1",
    senderID: "alice",
    receiverID: "bob",
    status: "sent",
    text: "hello",
    deliveredAt: null,
    readAt: null,
    updatedAt: now(),
  });

  const aliceDb = authedDb("alice");
  const bobDb = authedDb("bob");

  await assertSucceeds(
    updateDoc(doc(bobDb, "Chats/thread_1/Messages/msg_1"), {
      status: "delivered",
      deliveredAt: now(),
      updatedAt: now(),
    })
  );

  await assertFails(
    updateDoc(doc(aliceDb, "Chats/thread_1/Messages/msg_1"), {
      status: "read",
      readAt: now(),
      updatedAt: now(),
    })
  );

  await assertFails(
    updateDoc(doc(bobDb, "Chats/thread_1/Messages/msg_1"), {
      text: "edited",
      updatedAt: now(),
    })
  );
});

it("chat list query is UID-safe and collectionGroup receiver query enforces ownership", async () => {
  await seedUser("alice");
  await seedUser("bob");
  await seedUser("eve");

  await seedDoc("Chats/thread_q_1", {
    members: ["alice", "bob"],
    timestamp: now(),
    messagesCount: 1,
    createdAt: now(),
    updatedAt: now(),
  });

  await seedDoc("Chats/thread_q_1/Messages/msg_q_1", {
    ID: "msg_q_1",
    senderID: "alice",
    receiverID: "bob",
    status: "sent",
    text: "hello",
    deliveredAt: null,
    readAt: null,
    timestamp: now(),
    updatedAt: now(),
  });

  const aliceDb = authedDb("alice");
  const bobDb = authedDb("bob");
  const eveDb = authedDb("eve");

  await assertSucceeds(
    getDocs(
      query(
        collection(aliceDb, "Chats"),
        where("members", "array-contains", "alice"),
        orderBy("timestamp")
      )
    )
  );

  await assertFails(
    getDocs(
      query(
        collection(eveDb, "Chats"),
        where("members", "array-contains", "alice"),
        orderBy("timestamp")
      )
    )
  );

  await assertSucceeds(
    getDocs(
      query(
        collectionGroup(bobDb, "Messages"),
        where("receiverID", "==", "bob")
      )
    )
  );

  await assertFails(
    getDocs(
      query(
        collectionGroup(eveDb, "Messages"),
        where("receiverID", "==", "bob")
      )
    )
  );
});

it("anonymous users can read only safe public pet ads", async () => {
  await seedDoc("pet_ads/public_ad_1", {
    ownerID: "seller-1",
    category: "cats",
    status: 1,
    visibility: 0,
    isApproved: true,
    latitude: 25.2854,
    longitude: 51.531,
    geohash: "thrhm",
    createdAt: now(),
    updatedAt: now(),
  });

  await seedDoc("pet_ads/private_ad_1", {
    ownerID: "seller-1",
    category: "cats",
    status: 0,
    visibility: 1,
    isApproved: false,
    latitude: 25.2854,
    longitude: 51.531,
    geohash: "thrhm",
    createdAt: now(),
    updatedAt: now(),
  });

  const anon = anonDb();
  await assertSucceeds(getDoc(doc(anon, "pet_ads/public_ad_1")));
  await assertFails(getDoc(doc(anon, "pet_ads/private_ad_1")));
});

it("guest browse pet ads queries must use the public filter contract, including nearby geohash queries", async () => {
  await seedDoc("pet_ads/public_feed_1", {
    ownerID: "seller-feed-1",
    category: "cats",
    status: 1,
    visibility: 0,
    isApproved: true,
    latitude: 25.2854,
    longitude: 51.531,
    geohash: "thrhm12",
    createdAt: now(),
    updatedAt: now(),
  });
  await seedDoc("pet_ads/public_feed_2", {
    ownerID: "seller-feed-2",
    category: "dogs",
    status: 1,
    visibility: 0,
    isApproved: true,
    latitude: 25.296,
    longitude: 51.52,
    geohash: "thrhm99",
    createdAt: now(),
    updatedAt: now(),
  });
  await seedDoc("pet_ads/blocked_feed_1", {
    ownerID: "seller-feed-3",
    category: "dogs",
    status: 1,
    visibility: 0,
    isApproved: true,
    isBlocked: true,
    latitude: 25.296,
    longitude: 51.52,
    geohash: "thrhm55",
    createdAt: now(),
    updatedAt: now(),
  });

  const anon = anonDb();

  await assertSucceeds(
    getDocs(
      query(
        collection(anon, "pet_ads"),
        where("status", "==", 1),
        where("isApproved", "==", true),
        where("visibility", "==", 0),
        orderBy("createdAt", "desc")
      )
    )
  );

  await assertSucceeds(
    getDocs(
      query(
        collection(anon, "pet_ads"),
        where("status", "==", 1),
        where("isApproved", "==", true),
        where("visibility", "==", 0),
        orderBy("geohash"),
        startAt("thrhm"),
        endAt("thrhm~")
      )
    )
  );

  await assertFails(
    getDocs(
      query(
        collection(anon, "pet_ads"),
        where("status", "==", 1),
        where("visibility", "==", 0),
        orderBy("createdAt", "desc")
      )
    )
  );
});

it("guest users cannot read UsersCol but can read PublicUserProfiles", async () => {
  await seedUser("public-owner", {
    UserName: "Private Owner",
    MobileNo: "+97455555555",
  });
  await seedDoc(
    "PublicUserProfiles/public-owner",
    publicUserProfile("public-owner", { displayName: "Owner Card" })
  );

  const anon = anonDb();

  await assertFails(getDoc(doc(anon, "UsersCol/public-owner")));
  await assertSucceeds(getDoc(doc(anon, "PublicUserProfiles/public-owner")));
});

it("public user profiles keep valid queries working and reject malformed direct reads", async () => {
  await seedDoc(
    "PublicUserProfiles/public-modern",
    publicUserProfile("public-modern", { displayName: "Modern User" })
  );
  await seedDoc(
    "PublicUserProfiles/public-legacy",
    {
      ...publicUserProfile("public-legacy", { displayName: "Legacy User" }),
      UserName: "Legacy Private Name",
      UserImageUrl: "https://example.com/legacy.jpg",
    }
  );

  const anon = anonDb();
  await assertSucceeds(getDocs(collection(anon, "PublicUserProfiles")));
  await assertFails(getDoc(doc(anon, "PublicUserProfiles/public-legacy")));
});

it("owners can access legacy favorite alias subcollections but other users cannot", async () => {
  await seedUser("favorite-owner");

  const ownerDb = authedDb("favorite-owner");
  const otherDb = authedDb("favorite-other");

  await assertSucceeds(
    setDoc(doc(ownerDb, "UsersCol/favorite-owner/favoritesAccess/item_1"), {
      favoritedAt: now(),
    })
  );
  await assertSucceeds(
    setDoc(doc(ownerDb, "UsersCol/favorite-owner/favoriteServices/service_1"), {
      favoritedAt: now(),
    })
  );

  await assertFails(
    getDoc(doc(otherDb, "UsersCol/favorite-owner/favoritesAccess/item_1"))
  );
  await assertFails(
    getDoc(doc(otherDb, "UsersCol/favorite-owner/favoriteServices/service_1"))
  );
});

it("presence is authenticated-read, self-write, and guest-denied", async () => {
  await seedUser("presence-owner");
  await seedDoc("UserPresence/presence-owner", userPresence("presence-owner", { online: false }));

  const anon = anonDb();
  const ownerDb = authedDb("presence-owner");
  const otherDb = authedDb("presence-other");

  await assertFails(getDoc(doc(anon, "UserPresence/presence-owner")));
  await assertSucceeds(getDoc(doc(ownerDb, "UserPresence/presence-owner")));
  await assertSucceeds(
    setDoc(doc(ownerDb, "UserPresence/presence-owner"), {
      uid: "presence-owner",
      online: true,
      lastSeen: now(),
      updatedAt: now(),
    })
  );
  await assertFails(
    setDoc(doc(otherDb, "UserPresence/presence-owner"), {
      uid: "presence-owner",
      online: true,
      updatedAt: now(),
    })
  );
});

it("guest users can browse intended public collections but cannot write them", async () => {
  await seedDoc("MainKindsCollection/kind_1", { name: "Cats", createdAt: now() });
  await seedDoc("MainKindsCollection/kind_1/SubKinds/sub_1", { name: "Persian", createdAt: now() });
  await seedDoc("MainKindsCollection/kind_1/SubKinds/sub_1/SubSubKinds/subsub_1", { name: "Blue", createdAt: now() });
  await seedDoc("MainKindsCollection/kind_1/SubKinds/sub_1/SubSubKinds/subsub_1/Items/item_1", { name: "Toy", createdAt: now() });
  await seedDoc("MainBannersViewsCol/banner_1", { title: "Hero" });
  await seedDoc("MainBannersViewsCol/banner_1/ChildBanners/child_1", { title: "Promo" });
  await seedDoc("HomePromoCarouselCollection/card_1", { title: "Promo Card" });
  await seedDoc("petAccessories/accessory_1", { ownerID: "seller-1", name: "Accessory" });
  await seedDoc("serviceOffers/service_public_1", { serviceOwnerID: "seller-1", name: "Service" });
  await seedDoc("veterinarians/vet_public_1", { userID: "seller-1", name: "Vet", phone: "+97451111111", whatsapp: "+97451111111" });
  await seedDoc("adopt_pets/adopt_public_1", { ownerID: "seller-1", name: "Adopt Me" });
  await seedDoc("stories/story_public_1", { userID: "story_public_1", timestamp: now(), items: [], isSeen: false });
  await seedDoc("Accessories/legacy_accessory_1", { title: "Legacy Accessory" });

  const anon = anonDb();

  await assertSucceeds(getDoc(doc(anon, "MainKindsCollection/kind_1")));
  await assertSucceeds(getDoc(doc(anon, "MainKindsCollection/kind_1/SubKinds/sub_1")));
  await assertSucceeds(getDoc(doc(anon, "MainKindsCollection/kind_1/SubKinds/sub_1/SubSubKinds/subsub_1")));
  await assertSucceeds(getDoc(doc(anon, "MainKindsCollection/kind_1/SubKinds/sub_1/SubSubKinds/subsub_1/Items/item_1")));
  await assertSucceeds(getDoc(doc(anon, "MainBannersViewsCol/banner_1")));
  await assertSucceeds(getDoc(doc(anon, "MainBannersViewsCol/banner_1/ChildBanners/child_1")));
  await assertSucceeds(getDoc(doc(anon, "HomePromoCarouselCollection/card_1")));
  await assertSucceeds(getDoc(doc(anon, "petAccessories/accessory_1")));
  await assertSucceeds(getDoc(doc(anon, "serviceOffers/service_public_1")));
  await assertSucceeds(getDoc(doc(anon, "veterinarians/vet_public_1")));
  await assertSucceeds(getDoc(doc(anon, "adopt_pets/adopt_public_1")));
  await assertSucceeds(getDoc(doc(anon, "stories/story_public_1")));
  await assertSucceeds(getDoc(doc(anon, "Accessories/legacy_accessory_1")));
  await assertFails(setDoc(doc(anon, "petAccessories/accessory_guest_write"), { ownerID: "guest" }));
});

it("admin-only collections and catalog writes are denied to normal users", async () => {
  await seedUser("admin-write", { isAdmin: true, role: 5 });
  await seedUser("normal-write");

  const adminDb = authedDb("admin-write", { admin: true, roleValue: 5 });
  const userDb = authedDb("normal-write");

  await assertSucceeds(
    setDoc(doc(adminDb, "admin/notifications/items/item_1"), {
      title: "Admin Notice",
      body: "Only admins can write this.",
      createdAt: now(),
    })
  );
  await assertFails(
    setDoc(doc(userDb, "admin/notifications/items/item_2"), {
      title: "User Notice",
      createdAt: now(),
    })
  );

  await assertSucceeds(
    setDoc(doc(adminDb, "MainKindsCollection/admin_kind"), {
      name: "Admin Kind",
      createdAt: now(),
    })
  );
  await assertFails(
    setDoc(doc(userDb, "MainKindsCollection/user_kind"), {
      name: "User Kind",
      createdAt: now(),
    })
  );
});

it("bird-card legacy collections are private or authenticated-only as intended", async () => {
  await seedUser("bird-owner");
  await seedUser("bird-other");
  await seedDoc("CardsCol/card_1", {
    UserID: "bird-owner",
    createdAt: now(),
    updatedAt: now(),
  });
  await seedDoc("CagesCol/cage_1", {
    UserID: "bird-owner",
    createdAt: now(),
    updatedAt: now(),
  });
  await seedDoc("CagesCol/cage_1/ChildsCol/child_1", {
    UserID: "bird-owner",
    CageID: "cage_1",
    createdAt: now(),
    updatedAt: now(),
  });
  await seedDoc("ArchiveCol/archive_1", {
    archiveOwnerID: "bird-owner",
    createdAt: now(),
    updatedAt: now(),
  });
  await seedDoc("ArchiveCol/archive_1/ArchiveDetailsCol/detail_1", {
    UserID: "bird-owner",
    masterArchiveID: "archive_1",
    createdAt: now(),
    updatedAt: now(),
  });
  await seedDoc("TrashCol/trash_1", {
    ownerID: "bird-owner",
    createdAt: now(),
    updatedAt: now(),
  });
  await seedDoc("BuyersCollection/buyer_1", {
    UserID: "bird-owner",
    createdAt: now(),
    updatedAt: now(),
  });
  await seedDoc("trGCol/trigger_1", {
    ownerID: "bird-owner",
    createdAt: now(),
    updatedAt: now(),
  });

  const anon = anonDb();
  const ownerDb = authedDb("bird-owner");
  const otherDb = authedDb("bird-other");

  await assertFails(getDoc(doc(anon, "CardsCol/card_1")));
  await assertFails(getDoc(doc(anon, "CagesCol/cage_1")));
  await assertSucceeds(getDoc(doc(ownerDb, "CardsCol/card_1")));
  await assertSucceeds(getDoc(doc(ownerDb, "CagesCol/cage_1")));
  await assertSucceeds(getDoc(doc(ownerDb, "CagesCol/cage_1/ChildsCol/child_1")));
  await assertFails(getDoc(doc(otherDb, "CagesCol/cage_1/ChildsCol/child_1")));
  await assertSucceeds(getDoc(doc(ownerDb, "ArchiveCol/archive_1/ArchiveDetailsCol/detail_1")));
  await assertFails(getDoc(doc(otherDb, "ArchiveCol/archive_1/ArchiveDetailsCol/detail_1")));
  await assertSucceeds(getDoc(doc(ownerDb, "TrashCol/trash_1")));
  await assertFails(getDoc(doc(otherDb, "TrashCol/trash_1")));
  await assertSucceeds(getDoc(doc(ownerDb, "BuyersCollection/buyer_1")));
  await assertSucceeds(getDoc(doc(ownerDb, "trGCol/trigger_1")));
  await assertFails(getDoc(doc(anon, "trGCol/trigger_1")));
});

it("clients cannot directly create Orders documents", async () => {
  await seedUser("order-client");
  const buyerDb = authedDb("order-client");

  await assertFails(
    setDoc(doc(buyerDb, "Orders/direct_create_1"), {
      orderId: "direct_create_1",
      userId: "order-client",
      uid: "order-client",
      status: "pending",
      amount: 999,
      totalAmount: 999,
      currency: "QAR",
      items: [],
      shippingAddressId: "addr_1",
      shippingAddressSnapshot: {
        addressID: "addr_1",
        userID: "order-client",
        fullName: "Direct Buyer",
        addressLine1: "Street 1",
        postalCode: "12345",
        cityID: 1,
        stateID: 1,
      },
      createdAt: now(),
      updatedAt: now(),
    })
  );
});

it("owner can update session/token fields on existing profile but cannot token-create missing profile", async () => {
  await seedDoc("UsersCol/token-user", {
    ID: "token-user",
    role: 0,
    isAdmin: false,
    isSuperAdmin: false,
    isAdminAll: false,
    isBlocked: false,
    createdAt: now(),
    updatedAt: now(),
  });

  const tokenDb = authedDb("token-user");
  await assertSucceeds(
    setDoc(
      doc(tokenDb, "UsersCol/token-user"),
      {
        ID: "token-user",
        PPUserTokenID: "token_abc",
        loginSource: 1,
        updatedAt: now(),
      },
      { merge: true }
    )
  );

  const missingDb = authedDb("missing-user");
  await assertFails(
    setDoc(
      doc(missingDb, "UsersCol/missing-user"),
      {
        ID: "missing-user",
        PPUserTokenID: "token_xyz",
        loginSource: 1,
        updatedAt: now(),
      },
      { merge: true }
    )
  );
});

it("story owner can write own story doc without userID but cannot modify another user's story", async () => {
  await seedUser("story-alice");
  await seedUser("story-bob");
  await seedDoc("stories/story-bob", {
    userID: "story-bob",
    timestamp: now(),
    items: [],
    isSeen: false,
  });

  const aliceDb = authedDb("story-alice");

  await assertSucceeds(
    setDoc(doc(aliceDb, "stories/story-alice"), {
      userName: "Alice",
      isSeen: false,
      updatedAt: now(),
      items: [
        {
          mediaUrl: "https://example.com/story.jpg",
          mediaType: "image",
          duration: 5,
        },
      ],
    })
  );

  await assertFails(
    setDoc(
      doc(aliceDb, "stories/story-bob"),
      {
        isSeen: true,
      },
      { merge: true }
    )
  );
});

it("legacy roleName admin can read another user's legacy permissions subcollection", async () => {
  await seedUser("legacy-admin", {
    role: 1,
    roleName: "admin",
    isAdmin: false,
    isSuperAdmin: false,
    isAdminAll: false,
  });
  await seedUser("target-user");
  await seedPermission("target-user", "PostAds", true, true);

  const legacyAdminDb = authedDb("legacy-admin");
  await assertSucceeds(
    getDocs(collection(legacyAdminDb, "UsersCol", "target-user", "PermisstionsCol"))
  );
});

it("order owner can read support requests and timeline events, while another user cannot", async () => {
  await seedUser("buyer-1");
  await seedUser("buyer-2");

  await seedDoc("Orders/order_support_1", {
    orderId: "order_support_1",
    userId: "buyer-1",
    amount: 25,
    totalAmount: 25,
    currency: "QAR",
    paymentProvider: "QIB",
    items: [],
    shippingAddressId: "addr_1",
    shippingAddressSnapshot: {
      addressID: "addr_1",
      userID: "buyer-1",
      displayName: "Home",
    },
    status: "delivered",
    createdAt: now(),
    updatedAt: now(),
  });

  await seedDoc("Orders/order_support_1/events/evt_1", {
    eventId: "evt_1",
    type: "payment_verified",
    status: "paid",
    actorType: "system",
    metadata: {},
    createdAt: now(),
    updatedAt: now(),
  });

  await seedDoc("Orders/order_support_1/requests/req_1", {
    requestId: "req_1",
    orderId: "order_support_1",
    userId: "buyer-1",
    type: "return",
    status: "pending_review",
    finalResolution: "pending_review",
    createdAt: now(),
    updatedAt: now(),
  });

  await seedDoc("Orders/order_support_1/requests/req_1/events/evt_req_1", {
    eventId: "evt_req_1",
    type: "request_submitted",
    status: "pending_review",
    actorType: "customer",
    metadata: {},
    createdAt: now(),
    updatedAt: now(),
  });

  const ownerDb = authedDb("buyer-1");
  const otherDb = authedDb("buyer-2");

  await assertSucceeds(getDocs(collection(ownerDb, "Orders", "order_support_1", "events")));
  await assertSucceeds(getDocs(collection(ownerDb, "Orders", "order_support_1", "requests")));
  await assertSucceeds(
    getDocs(collection(ownerDb, "Orders", "order_support_1", "requests", "req_1", "events"))
  );

  await assertFails(getDocs(collection(otherDb, "Orders", "order_support_1", "events")));
  await assertFails(getDocs(collection(otherDb, "Orders", "order_support_1", "requests")));
});

it("payment manager can move orders through the approved lifecycle but not immutable order totals", async () => {
  await seedUser("payments-manager");
  await seedPermission("payments-manager", "ManageStore", true);
  await seedDoc("Orders/order_manage_1", {
    orderId: "order_manage_1",
    userId: "buyer-1",
    amount: 40,
    totalAmount: 40,
    currency: "QAR",
    paymentMethodId: "qib",
    paymentStatus: "pending",
    paymentProvider: "QIB",
    items: [{ id: "item_1", qty: 1, price: 40 }],
    shippingAddressId: "addr_1",
    shippingAddressSnapshot: {
      addressID: "addr_1",
      userID: "buyer-1",
      fullName: "Buyer One",
      addressLine1: "Street 1",
      postalCode: "12345",
      cityID: 1,
      stateID: 1,
    },
    status: "pending",
    verificationStatus: "pending",
    createdAt: now(),
    updatedAt: now(),
  });

  const paymentsDb = authedDb("payments-manager");
  const managedOrderRef = doc(paymentsDb, "Orders/order_manage_1");

  await assertSucceeds(
    updateDoc(managedOrderRef, {
      status: "paid",
      paymentMethodId: "qib",
      paymentStatus: "paid",
      verificationStatus: "verified",
      paymentProvider: "QIB",
      updatedAt: now(),
      statusUpdatedAt: now(),
      manualApprovalAt: now(),
      manualApprovalBy: { uid: "payments-manager", name: "Payments Manager" },
      paidAt: now(),
      inventoryDeducted: true,
      inventoryDeductedAt: now(),
      inventoryRestocked: false,
    })
  );

  await assertSucceeds(
    updateDoc(managedOrderRef, {
      status: "processing",
      updatedAt: now(),
      statusUpdatedAt: now(),
      processedAt: now(),
    })
  );

  await assertSucceeds(
    updateDoc(managedOrderRef, {
      status: "shipped",
      updatedAt: now(),
      statusUpdatedAt: now(),
      shippedAt: now(),
    })
  );

  await assertSucceeds(
    updateDoc(managedOrderRef, {
      status: "delivered",
      updatedAt: now(),
      statusUpdatedAt: now(),
      deliveredAt: now(),
    })
  );

  await assertFails(
    updateDoc(managedOrderRef, {
      amount: 999,
      updatedAt: now(),
    })
  );
});

it("payment manager cannot skip directly from paid to shipped", async () => {
  await seedUser("payments-manager");
  await seedPermission("payments-manager", "ManageStore", true);
  await seedDoc("Orders/order_skip_1", {
    orderId: "order_skip_1",
    userId: "buyer-skip-1",
    amount: 40,
    totalAmount: 40,
    currency: "QAR",
    paymentMethodId: "qib",
    paymentStatus: "paid",
    paymentProvider: "QIB",
    verificationStatus: "verified",
    items: [{ id: "item_1", qty: 1, price: 40 }],
    shippingAddressId: "addr_1",
    shippingAddressSnapshot: {
      addressID: "addr_1",
      userID: "buyer-skip-1",
      fullName: "Buyer Skip",
      addressLine1: "Street 1",
      postalCode: "12345",
      cityID: 1,
      stateID: 1,
    },
    status: "paid",
    paidAt: now(),
    inventoryDeducted: true,
    inventoryDeductedAt: now(),
    inventoryRestocked: false,
    createdAt: now(),
    updatedAt: now(),
    statusUpdatedAt: now(),
  });

  const paymentsDb = authedDb("payments-manager");
  const managedOrderRef = doc(paymentsDb, "Orders/order_skip_1");

  await assertFails(
    updateDoc(managedOrderRef, {
      status: "shipped",
      updatedAt: now(),
      statusUpdatedAt: now(),
      shippedAt: now(),
    })
  );
});

it("payment manager can move COD orders through fulfillment and collect payment after delivery", async () => {
  await seedUser("payments-manager");
  await seedPermission("payments-manager", "ManageStore", true);
  await seedDoc("Orders/order_cod_manage_1", {
    orderId: "order_cod_manage_1",
    userId: "buyer-cod-1",
    amount: 55,
    totalAmount: 55,
    currency: "QAR",
    paymentMethodId: "cash",
    paymentStatus: "pending_collection",
    paymentProvider: "CASH",
    verificationStatus: "not_applicable",
    items: [{ id: "item_1", qty: 1, price: 55 }],
    shippingAddressId: "addr_1",
    shippingAddressSnapshot: {
      addressID: "addr_1",
      userID: "buyer-cod-1",
      fullName: "Buyer COD",
      addressLine1: "Street 9",
      postalCode: "12345",
      cityID: 1,
      stateID: 1,
    },
    status: "pending",
    inventoryDeducted: false,
    inventoryRestocked: false,
    createdAt: now(),
    updatedAt: now(),
    statusUpdatedAt: now(),
  });

  const paymentsDb = authedDb("payments-manager");
  const managedOrderRef = doc(paymentsDb, "Orders/order_cod_manage_1");

  await assertSucceeds(
    updateDoc(managedOrderRef, {
      status: "processing",
      paymentMethodId: "cash",
      paymentStatus: "pending_collection",
      paymentProvider: "CASH",
      verificationStatus: "not_applicable",
      updatedAt: now(),
      statusUpdatedAt: now(),
      processedAt: now(),
      inventoryDeducted: true,
      inventoryDeductedAt: now(),
      inventoryRestocked: false,
    })
  );

  await assertSucceeds(
    updateDoc(managedOrderRef, {
      status: "shipped",
      updatedAt: now(),
      statusUpdatedAt: now(),
      shippedAt: now(),
    })
  );

  await assertSucceeds(
    updateDoc(managedOrderRef, {
      status: "delivered",
      updatedAt: now(),
      statusUpdatedAt: now(),
      deliveredAt: now(),
    })
  );

  await assertSucceeds(
    updateDoc(managedOrderRef, {
      paymentMethodId: "cash",
      paymentProvider: "CASH",
      paymentStatus: "paid",
      verificationStatus: "not_applicable",
      paymentCollectedAt: now(),
      paymentCollectedBy: { uid: "payments-manager", name: "Payments Manager" },
      paidAt: now(),
      updatedAt: now(),
    })
  );
});

it("order owner can update shipping details but cannot tamper with protected status fields", async () => {
  await seedUser("buyer-4");
  await seedDoc("Orders/order_owner_1", {
    orderId: "order_owner_1",
    userId: "buyer-4",
    amount: 10,
    totalAmount: 10,
    currency: "QAR",
    paymentProvider: "QIB",
    items: [],
    shippingAddressId: "addr_1",
    shippingAddressSnapshot: {
      addressID: "addr_1",
      userID: "buyer-4",
      displayName: "Home",
      addressLine1: "Street 1",
      postalCode: "12345",
      cityID: 1,
      stateID: 1,
    },
    status: "pending",
    createdAt: now(),
    updatedAt: now(),
    statusUpdatedAt: now(),
  });

  const buyerDb = authedDb("buyer-4");
  const buyerOrderRef = doc(buyerDb, "Orders/order_owner_1");

  await assertSucceeds(
    updateDoc(buyerOrderRef, {
      shippingAddressId: "addr_2",
      shippingAddressSnapshot: {
        addressID: "addr_2",
        userID: "buyer-4",
        fullName: "Buyer Four",
        displayName: "Office",
        addressLine1: "Street 2",
        postalCode: "54321",
        cityID: 2,
        stateID: 2,
      },
      updatedAt: now(),
    })
  );

  await assertFails(
    updateDoc(buyerOrderRef, {
      status: "paid",
      verificationStatus: "verified",
      updatedAt: now(),
    })
  );
});

it("payment manager can update request-driven summary fields without changing order status", async () => {
  await seedUser("payments-manager");
  await seedPermission("payments-manager", "ManageStore", true);
  await seedDoc("Orders/order_request_patch_1", {
    orderId: "order_request_patch_1",
    userId: "buyer-r1",
    amount: 60,
    totalAmount: 60,
    currency: "QAR",
    paymentProvider: "QIB",
    verificationStatus: "verified",
    items: [{ id: "item_1", qty: 1, price: 60 }],
    shippingAddressId: "addr_1",
    shippingAddressSnapshot: {
      addressID: "addr_1",
      userID: "buyer-r1",
      fullName: "Buyer Return",
      addressLine1: "Street 1",
      postalCode: "12345",
      cityID: 1,
      stateID: 1,
    },
    status: "delivered",
    paidAt: now(),
    processedAt: now(),
    shippedAt: now(),
    deliveredAt: now(),
    inventoryDeducted: true,
    inventoryDeductedAt: now(),
    inventoryRestocked: false,
    createdAt: now(),
    updatedAt: now(),
    statusUpdatedAt: now(),
  });

  const paymentsDb = authedDb("payments-manager");
  const managedOrderRef = doc(paymentsDb, "Orders/order_request_patch_1");

  await assertSucceeds(
    updateDoc(managedOrderRef, {
      latestRequestType: "refund",
      latestRequestStatus: "refunded",
      refundStatus: "refunded",
      refundAmount: 60,
      refundedAt: now(),
      updatedAt: now(),
    })
  );

  await assertSucceeds(
    updateDoc(managedOrderRef, {
      latestRequestType: "return",
      latestRequestStatus: "completed",
      returnStatus: "completed",
      inventoryRestocked: true,
      inventoryRestockedAt: now(),
      inventoryRestockedBy: { uid: "payments-manager", name: "Payments Manager" },
      updatedAt: now(),
    })
  );
});

it("clients cannot directly create or update order support requests", async () => {
  await seedUser("buyer-3");
  await seedDoc("Orders/order_support_2", {
    orderId: "order_support_2",
    userId: "buyer-3",
    amount: 10,
    totalAmount: 10,
    currency: "QAR",
    paymentProvider: "QIB",
    items: [],
    shippingAddressId: "addr_1",
    shippingAddressSnapshot: {
      addressID: "addr_1",
      userID: "buyer-3",
      displayName: "Home",
    },
    status: "paid",
    createdAt: now(),
    updatedAt: now(),
  });

  const buyerDb = authedDb("buyer-3");

  await assertFails(
    setDoc(doc(buyerDb, "Orders/order_support_2/requests/req_direct"), {
      requestId: "req_direct",
      orderId: "order_support_2",
      userId: "buyer-3",
      type: "refund",
      status: "pending_review",
      finalResolution: "pending_review",
      createdAt: now(),
      updatedAt: now(),
    })
  );
});

it("createPendingOrder callable creates a canonical pending order and ignores client-supplied totals", async () => {
  await seedAdminDoc("UsersCol/callable-buyer", userProfile("callable-buyer"));
  await seedAdminDoc("CommerceConfig/payments", {
    configId: "payments",
    deliveryFee: 3,
    cashOnDeliveryEnabled: true,
    onlinePaymentEnabled: true,
    updatedAt: now(),
    updatedBy: "admin-1",
  });
  await seedAdminDoc("UsersCol/callable-buyer/Addresses/addr_ok", {
    addressID: "addr_ok",
    userID: "callable-buyer",
    fullName: "Callable Buyer",
    displayName: "Home",
    addressLine1: "Street 1",
    addressLine2: "Unit 5",
    postalCode: "12345",
    cityID: 1,
    stateID: 1,
    isDefault: true,
    createdAt: now(),
    updatedAt: now(),
  });
  await seedAdminDoc("petAccessories/accessory_callable_1", {
    ownerID: "seller-1",
    name: "Harness",
    quantity: 5,
    finalPrice: 15,
    imageURLsArray: ["https://example.com/harness.jpg"],
    createdAt: now(),
    updatedAt: now(),
  });

  const response = await functionsExports.createPendingOrder.run({
    auth: { uid: "callable-buyer", token: {} },
    data: {
      shippingAddressId: "addr_ok",
      amount: 9999,
      totalAmount: 9999,
      shippingFee: 99,
      items: [
        { itemId: "accessory_callable_1", quantity: 2 },
      ],
    },
  });

  if (!response || !response.orderId) {
    throw new Error("createPendingOrder did not return an order id");
  }
  if (response.order.amount !== 30 || response.order.totalAmount !== 33) {
    throw new Error(`Unexpected computed totals: ${JSON.stringify(response.order)}`);
  }
  if (response.order.shippingFee !== 3) {
    throw new Error(`Expected backend delivery fee 3, received ${JSON.stringify(response.order)}`);
  }

  const ownerDb = authedDb("callable-buyer");
  await assertSucceeds(getDoc(doc(ownerDb, `Orders/${response.orderId}`)));
  await assertSucceeds(getDocs(collection(ownerDb, "Orders", response.orderId, "events")));
});

it("checkout payment settings doc is readable but not writable by regular users", async () => {
  await seedAdminDoc("CommerceConfig/payments", {
    configId: "payments",
    deliveryFee: 22,
    cashOnDeliveryEnabled: true,
    onlinePaymentEnabled: true,
    updatedAt: now(),
    updatedBy: "admin-1",
  });

  const buyerDb = authedDb("buyer-settings");
  await assertSucceeds(getDoc(doc(buyerDb, "CommerceConfig", "payments")));
  await assertFails(setDoc(doc(buyerDb, "CommerceConfig", "payments"), {
    configId: "payments",
    deliveryFee: 0,
  }, { merge: true }));
});

it("createPendingOrder callable rejects address ownership mismatches", async () => {
  await seedAdminDoc("UsersCol/callable-owner", userProfile("callable-owner"));
  await seedAdminDoc("UsersCol/callable-other", userProfile("callable-other"));
  await seedAdminDoc("UsersCol/callable-other/Addresses/addr_other", {
    addressID: "addr_other",
    userID: "callable-other",
    fullName: "Other User",
    addressLine1: "Street 2",
    postalCode: "54321",
    cityID: 2,
    stateID: 2,
    isDefault: true,
    createdAt: now(),
    updatedAt: now(),
  });
  await seedAdminDoc("petAccessories/accessory_callable_2", {
    ownerID: "seller-2",
    name: "Carrier",
    quantity: 2,
    finalPrice: 20,
    createdAt: now(),
    updatedAt: now(),
  });

  let failed = false;
  try {
    await functionsExports.createPendingOrder.run({
      auth: { uid: "callable-owner", token: {} },
      data: {
        shippingAddressId: "addr_other",
        items: [{ itemId: "accessory_callable_2", quantity: 1 }],
      },
    });
  } catch (error) {
    failed = true;
  }
  if (!failed) {
    throw new Error("Expected createPendingOrder to reject mismatched address ownership");
  }
});

it("createPendingOrder callable rejects invalid inventory requests", async () => {
  await seedAdminDoc("UsersCol/callable-stock", userProfile("callable-stock"));
  await seedAdminDoc("UsersCol/callable-stock/Addresses/addr_stock", {
    addressID: "addr_stock",
    userID: "callable-stock",
    fullName: "Stock Buyer",
    addressLine1: "Street 3",
    postalCode: "99999",
    cityID: 3,
    stateID: 3,
    isDefault: true,
    createdAt: now(),
    updatedAt: now(),
  });
  await seedAdminDoc("petAccessories/accessory_callable_3", {
    ownerID: "seller-3",
    name: "Crate",
    quantity: 1,
    finalPrice: 50,
    createdAt: now(),
    updatedAt: now(),
  });

  let failed = false;
  try {
    await functionsExports.createPendingOrder.run({
      auth: { uid: "callable-stock", token: {} },
      data: {
        shippingAddressId: "addr_stock",
        items: [{ itemId: "accessory_callable_3", quantity: 5 }],
      },
    });
  } catch (error) {
    failed = true;
  }
  if (!failed) {
    throw new Error("Expected createPendingOrder to reject unavailable inventory");
  }
});

async function run() {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: HOST,
      port: PORT,
      rules: RULES,
    },
  });

  let failed = 0;
  for (const t of tests) {
    await testEnv.clearFirestore();
    try {
      await t.fn();
      console.log(`PASS: ${t.name}`);
    } catch (error) {
      failed += 1;
      console.error(`FAIL: ${t.name}`);
      console.error(error);
    }
  }

  await testEnv.cleanup();

  if (failed > 0) {
    throw new Error(`${failed} firestore rules tests failed`);
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
