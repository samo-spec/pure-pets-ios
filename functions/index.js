const crypto = require("node:crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const functionsV1 = require("firebase-functions");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const fieldValue = admin.firestore.FieldValue;

const SUCCESS_STATUS_TOKENS = [
  "paid",
  "success",
  "succeeded",
  "captured",
  "authorized",
  "approved",
  "completed",
];

const FAILED_STATUS_TOKENS = [
  "failed",
  "rejected",
  "declined",
  "cancelled",
  "canceled",
  "expired",
  "error",
  "voided",
];

const SENSITIVE_KEY_TOKENS = [
  "card",
  "pan",
  "cvv",
  "cvc",
  "security",
  "secret",
  "token",
  "expiry",
  "exp_month",
  "exp_year",
];

const PAYMENT_INSTRUMENT_DISALLOWED_KEYS = [
  "cardNumber",
  "pan",
  "cvv",
  "cvc",
  "otp",
  "oneTimePassword",
  "qnbOtp",
  "securityCode",
];

const ORDER_STATUS_PENDING = "pending";
const ORDER_STATUS_FAILED = "failed";
const ORDER_STATUS_PAID = "paid";
const ORDER_STATUS_PROCESSING = "processing";
const ORDER_STATUS_SHIPPED = "shipped";
const ORDER_STATUS_DELIVERED = "delivered";
const ORDER_STATUS_CANCELLED = "cancelled";
const ORDER_STATUS_VERIFICATION_PENDING = "verification_pending";
const ORDER_PAYMENT_METHOD_QIB = "qib";
const ORDER_PAYMENT_METHOD_CASH = "cash";
const ORDER_PAYMENT_STATUS_PENDING = "pending";
const ORDER_PAYMENT_STATUS_PENDING_COLLECTION = "pending_collection";
const ORDER_PAYMENT_STATUS_PAID = "paid";
const ORDER_PAYMENT_STATUS_FAILED = "failed";
const ORDER_PAYMENT_STATUS_CANCELLED = "cancelled";
const ORDER_VERIFICATION_PENDING = "pending";
const ORDER_VERIFICATION_VERIFIED = "verified";
const ORDER_VERIFICATION_FAILED = "failed";
const ORDER_VERIFICATION_NOT_APPLICABLE = "not_applicable";
const PUBLIC_ORDER_NUMBER_PREFIX = "PP";
const PUBLIC_ORDER_NUMBER_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
const PUBLIC_ORDER_NUMBER_HASH_LENGTH = 6;
const LEGACY_PUBLIC_ORDER_NUMBER_SUFFIX_LENGTH = 12;
const COMMERCE_CONFIG_COLLECTION = "CommerceConfig";
const COMMERCE_PAYMENT_SETTINGS_DOC = "payments";
const DEFAULT_DELIVERY_FEE = 22;
const QIB_CLIENT_RESPONSE_GRACE_MS = 30 * 60 * 1000;
const ORDER_EVENTS_COLLECTION = "events";
const ORDER_REQUESTS_COLLECTION = "requests";
const REQUEST_EVENTS_SUBCOLLECTION = "events";
const ORDER_REQUEST_TYPE_CANCEL = "cancel";
const ORDER_REQUEST_TYPE_RETURN = "return";
const ORDER_REQUEST_TYPE_REFUND = "refund";
const ORDER_REQUEST_TYPE_REPLACEMENT = "replacement";
const ORDER_REQUEST_TYPE_COMPLAINT = "complaint";
const ORDER_REQUEST_TYPE_SUPPORT = "support";
const ORDER_REQUEST_PENDING_REVIEW = "pending_review";
const ORDER_REQUEST_APPROVED = "approved";
const ORDER_REQUEST_REJECTED = "rejected";
const ORDER_REQUEST_COMPLETED = "completed";
const ORDER_REQUEST_REFUNDED = "refunded";
const ORDER_REQUEST_PARTIALLY_REFUNDED = "partially_refunded";
const ORDER_REQUEST_CANCELLED = "cancelled";
const ORDER_REQUEST_CLOSED = "closed";

const ENFORCE_APPCHECK = optionalString(process.env.QIB_ENFORCE_APP_CHECK, 16).toLowerCase() === "true";
const LEGACY_CLIENT_BOOTSTRAP_ENABLED = (() => {
  const raw = optionalString(process.env.QIB_ALLOW_LEGACY_CLIENT_BOOTSTRAP, 16).toLowerCase();
  if (!raw) {
    // Keep existing mobile SDK flow working unless explicitly disabled.
    return true;
  }
  return ["1", "true", "yes", "on"].includes(raw);
})();
const CLIENT_ONLY_VERIFICATION_FALLBACK_ENABLED = (() => {
  const raw = optionalString(process.env.QIB_ALLOW_CLIENT_ONLY_VERIFICATION, 16).toLowerCase();
  if (!raw) {
    // Production-safe default: require server-side verification unless an explicit fallback is enabled.
    return false;
  }
  return ["1", "true", "yes", "on"].includes(raw);
})();
const ENABLE_DEBUG_PAYMENT_SIMULATION = (() => {
  const raw = optionalString(process.env.QIB_ALLOW_DEBUG_PAYMENT_SIMULATION, 32).toLowerCase();
  if (!raw) {
    return false;
  }
  return ["1", "true", "yes", "on", "enabled"].includes(raw);
})();
const USERS_COLLECTION = "UsersCol";
const PUBLIC_USER_PROFILES_COLLECTION = "PublicUserProfiles";
const USER_PRESENCE_COLLECTION = "UserPresence";
const USER_ADDRESSES_SUBCOLLECTION = "Addresses";
const PERMISSIONS_COLLECTION_CANONICAL = "permissions";
const PERMISSIONS_COLLECTION_LEGACY = "PermisstionsCol";
const PERMISSIONS_COLLECTION_LEGACY_ALT = "PermissionsCol";
const PERMISSIONS_COLLECTION_LEGACY_ALL = Object.freeze([
  PERMISSIONS_COLLECTION_LEGACY,
  PERMISSIONS_COLLECTION_LEGACY_ALT,
]);
const ADMIN_AUDIT_COLLECTION = "AdminAuditLogs";
const USER_PUSH_TOKEN_FIELD = "PPUserTokenID";
const ADMIN_PUSH_TOKEN_FIELD = "PPAdminTokenID";
const USER_INBOX_SUBCOLLECTION = "inbox";
const ACCESSORIES_COLLECTION = "petAccessories";
const ADMIN_NOTIFICATION_ROUTE_PAYMENTS_ORDER = "payments_order";

const ROLE_VALUE_TO_NAME = Object.freeze({
  1: "user",
  2: "owner",
  3: "vet",
  4: "moderator",
  5: "admin",
  6: "storemanager",
  7: "foodmanager",
  8: "superadmin",
});

const ROLE_NAME_TO_VALUE = Object.freeze({
  user: 1,
  owner: 2,
  vet: 3,
  moderator: 4,
  admin: 5,
  storemanager: 6,
  foodmanager: 7,
  superadmin: 8,
  support: 4,
});

const CANONICAL_PERMISSION_KEYS = Object.freeze([
  "AdminAll",
  "PostAds",
  "SellNew",
  "SellUsed",
  "Adoption",
  "ManageStore",
  "Moderation",
  "ManageFood",
  "ManageServices",
  "production",
]);

const CANONICAL_PERMISSION_BY_LOWER = Object.freeze(
  CANONICAL_PERMISSION_KEYS.reduce((acc, key) => {
    acc[key.toLowerCase()] = key;
    return acc;
  }, {})
);

const LEGACY_PERMISSION_TO_CANONICAL = Object.freeze({
  manageusers: "Adoption",
  managenotificatiuons: "Moderation",
  managenotifications: "Moderation",
  managebanners: "PostAds",
  prodection: "production",
});

const CANONICAL_PERMISSION_TO_LEGACY = Object.freeze({
  Adoption: "ManageUsers",
  Moderation: "ManageNotificatiuons",
  PostAds: "ManageBanners",
  production: "Prodection",
});

function trimmedString(value) {
  if (typeof value !== "string") return "";
  return value.trim();
}

function optionalString(value, maxLen = 128) {
  const str = trimmedString(value);
  if (!str) return "";
  return str.slice(0, maxLen);
}

function requiredString(value, fieldName, maxLen = 128) {
  const str = optionalString(value, maxLen);
  if (!str) {
    throw new HttpsError("invalid-argument", `${fieldName} is required.`);
  }
  return str;
}

function positiveAmount(value, fieldName) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", `${fieldName} must be a positive number.`);
  }
  return Math.round(amount * 100) / 100;
}

function normalizedStatus(value) {
  let status = trimmedString(value).toLowerCase();
  if (!status) return "";
  status = status.replace(/[\s-]+/g, "_");
  status = status.replace(/_+/g, "_");
  return status;
}

function statusContainsToken(status, token) {
  if (!status || !token) return false;
  return `_${status}_`.includes(`_${token}_`);
}

function classifyStatus(status) {
  if (SUCCESS_STATUS_TOKENS.some((token) => statusContainsToken(status, token))) {
    return "paid";
  }
  if (FAILED_STATUS_TOKENS.some((token) => statusContainsToken(status, token))) {
    return "failed";
  }
  return "unknown";
}

function safeObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function extractFirstString(obj, keys) {
  const source = safeObject(obj);
  for (const key of keys) {
    const candidate = optionalString(source[key], 256);
    if (candidate) return candidate;
  }
  return "";
}

function looksSensitiveKey(key) {
  const lowerKey = String(key || "").toLowerCase();
  return SENSITIVE_KEY_TOKENS.some((token) => lowerKey.includes(token));
}

function redactSensitive(value) {
  if (Array.isArray(value)) {
    return value.map((entry) => redactSensitive(entry));
  }
  if (value && typeof value === "object") {
    const redacted = {};
    for (const [key, child] of Object.entries(value)) {
      redacted[key] = looksSensitiveKey(key) ? "[REDACTED]" : redactSensitive(child);
    }
    return redacted;
  }
  return value;
}

function firstStringFromArray(value, maxLen = 2048) {
  if (!Array.isArray(value)) {
    return "";
  }
  for (const entry of value) {
    if (typeof entry === "string") {
      const candidate = optionalString(entry, maxLen);
      if (candidate) return candidate;
      continue;
    }
    const nested = optionalString(safeObject(entry).url, maxLen);
    if (nested) return nested;
  }
  return "";
}

function nonNegativeAmount(value, fieldName) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount < 0) {
    throw new HttpsError("invalid-argument", `${fieldName} must be a non-negative number.`);
  }
  return Math.round(amount * 100) / 100;
}

function requireAuthUID(request) {
  const uid = optionalString(request?.auth?.uid, 128);
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return uid;
}

function hasPrivilegedTokenClaim(request) {
  const token = safeObject(request?.auth?.token);
  const roleValue = Number(token.roleValue);
  const hasPrivilegedRole = Number.isInteger(roleValue) && (roleValue === 5 || roleValue === 8);
  const roleName = optionalString(token.role, 64).toLowerCase();

  return (
    token.admin === true ||
    token.superAdmin === true ||
    token.isAdmin === true ||
    token.isSuperAdmin === true ||
    token.isAdminAll === true ||
    roleName === "admin" ||
    roleName === "superadmin" ||
    hasPrivilegedRole
  );
}

function hasPrivilegedRoleValue(value) {
  const roleValue = Number(value);
  return Number.isInteger(roleValue) && (roleValue === 5 || roleValue === 8);
}

async function userHasAdminAllPermission(uid) {
  const canonicalRef = db.collection(USERS_COLLECTION).doc(uid).collection(PERMISSIONS_COLLECTION_CANONICAL).doc("AdminAll");
  const legacyRefs = PERMISSIONS_COLLECTION_LEGACY_ALL.map((collectionName) =>
    db.collection(USERS_COLLECTION).doc(uid).collection(collectionName).doc("AdminAll")
  );
  const [canonicalSnap, ...legacySnaps] = await Promise.all([
    canonicalRef.get(),
    ...legacyRefs.map((ref) => ref.get()),
  ]);

  const canonicalAllowed = canonicalSnap.exists && safeObject(canonicalSnap.data()).allowed === true;
  const legacyAllowed = legacySnaps.some((legacySnap) => (
    legacySnap.exists && safeObject(legacySnap.data()).allowed === true
  ));

  return canonicalAllowed || legacyAllowed;
}

async function requirePrivilegedUID(request) {
  const uid = requireAuthUID(request);
  if (hasPrivilegedTokenClaim(request)) {
    return uid;
  }

  const snapshot = await db.collection(USERS_COLLECTION).doc(uid).get();
  const userData = safeObject(snapshot.data());
  const hasAdminAllPermission = await userHasAdminAllPermission(uid);
  const isPrivileged =
    userData.isAdmin === true ||
    userData.isSuperAdmin === true ||
    userData.isAdminAll === true ||
    hasPrivilegedRoleValue(userData.role) ||
    hasAdminAllPermission;
  if (!isPrivileged) {
    throw new HttpsError("permission-denied", "Admin privileges are required.");
  }
  return uid;
}

function hasPaymentManagerTokenClaim(request) {
  if (hasPrivilegedTokenClaim(request)) {
    return true;
  }

  const token = safeObject(request?.auth?.token);
  const roleValue = Number(token.roleValue);
  const roleName = optionalString(token.roleName || token.role, 64).toLowerCase();
  return (
    [5, 6, 7, 8].includes(roleValue) ||
    ["admin", "storemanager", "foodmanager", "superadmin"].includes(roleName)
  );
}

async function userHasNamedPermission(uid, permissionID) {
  const canonicalKey = canonicalPermissionKey(permissionID);
  if (!canonicalKey) {
    return false;
  }

  const userRef = db.collection(USERS_COLLECTION).doc(uid);
  const canonicalRef = userRef.collection(PERMISSIONS_COLLECTION_CANONICAL).doc(canonicalKey);
  const legacyKeys = [...new Set(legacyMirrorPermissionKeys(canonicalKey))];
  const legacyRefs = [];
  for (const collectionName of PERMISSIONS_COLLECTION_LEGACY_ALL) {
    for (const legacyKey of legacyKeys) {
      legacyRefs.push(userRef.collection(collectionName).doc(legacyKey));
    }
  }

  const [canonicalSnap, ...legacySnaps] = await Promise.all([
    canonicalRef.get(),
    ...legacyRefs.map((ref) => ref.get()),
  ]);
  if (canonicalSnap.exists && safeObject(canonicalSnap.data()).allowed === true) {
    return true;
  }

  return legacySnaps.some((snapshot) => snapshot.exists && safeObject(snapshot.data()).allowed === true);
}

async function requirePaymentManagerUID(request) {
  const uid = requireAuthUID(request);
  if (hasPaymentManagerTokenClaim(request)) {
    return uid;
  }

  const snapshot = await db.collection(USERS_COLLECTION).doc(uid).get();
  const userData = safeObject(snapshot.data());
  const roleValue = normalizeRoleValue(userData.roleValue ?? userData.role, 0);
  const roleName = optionalString(userData.roleName || userData.role, 64).toLowerCase();
  const hasManageStorePermission = await userHasNamedPermission(uid, "ManageStore");
  const hasAdminAllPermission = await userHasNamedPermission(uid, "AdminAll");
  const hasPaymentRole =
    userData.isAdmin === true ||
    userData.isSuperAdmin === true ||
    userData.isAdminAll === true ||
    [5, 6, 7, 8].includes(roleValue) ||
    ["admin", "storemanager", "foodmanager", "superadmin"].includes(roleName);

  if (!(hasPaymentRole || hasManageStorePermission || hasAdminAllPermission)) {
    throw new HttpsError("permission-denied", "Payment management privileges are required.");
  }

  return uid;
}

function boolOrDefault(value, fallback = false) {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const normalized = optionalString(value, 16).toLowerCase();
    if (!normalized) return fallback;
    if (["1", "true", "yes", "on"].includes(normalized)) return true;
    if (["0", "false", "no", "off"].includes(normalized)) return false;
  }
  return fallback;
}

function normalizeRoleValue(rawRole, fallbackRoleValue = 1) {
  const numericRole = Number(rawRole);
  if (Number.isInteger(numericRole) && numericRole >= 1 && numericRole <= 8) {
    return numericRole;
  }

  const roleName = optionalString(rawRole, 64).toLowerCase();
  if (roleName && roleName in ROLE_NAME_TO_VALUE) {
    return ROLE_NAME_TO_VALUE[roleName];
  }

  return fallbackRoleValue;
}

function roleNameForValue(roleValue) {
  const normalized = Number(roleValue);
  return ROLE_VALUE_TO_NAME[normalized] || "user";
}

function canonicalPermissionKey(rawKey) {
  const clean = optionalString(rawKey, 64);
  if (!clean) return "";

  const lower = clean.toLowerCase();
  if (lower in CANONICAL_PERMISSION_BY_LOWER) {
    return CANONICAL_PERMISSION_BY_LOWER[lower];
  }

  if (lower in LEGACY_PERMISSION_TO_CANONICAL) {
    return LEGACY_PERMISSION_TO_CANONICAL[lower];
  }

  return "";
}

function legacyMirrorPermissionKeys(canonicalKey) {
  if (!canonicalKey) return [];
  const primary = CANONICAL_PERMISSION_TO_LEGACY[canonicalKey] || canonicalKey;
  if (canonicalKey === "Moderation") {
    return [primary, "ManageNotifications"];
  }
  return [primary];
}

function normalizePermissionPatch(rawPermissions) {
  const source = safeObject(rawPermissions);
  const normalized = {};

  for (const [rawKey, rawValue] of Object.entries(source)) {
    const canonicalKey = canonicalPermissionKey(rawKey);
    if (!canonicalKey) continue;
    normalized[canonicalKey] = boolOrDefault(rawValue, false);
  }

  return normalized;
}

function permissionMapFromQuerySnapshot(snapshot) {
  const result = {};
  if (!snapshot) return result;
  for (const doc of snapshot.docs || []) {
    const canonicalKey = canonicalPermissionKey(doc.id);
    if (!canonicalKey) continue;
    result[canonicalKey] = boolOrDefault(safeObject(doc.data()).allowed, false);
  }
  return result;
}

function mergePermissionMaps(canonicalMap, legacyMap) {
  return {
    ...legacyMap,
    ...canonicalMap,
  };
}

async function readPermissionState(uid) {
  const userRef = db.collection(USERS_COLLECTION).doc(uid);
  const canonicalRef = userRef.collection(PERMISSIONS_COLLECTION_CANONICAL);
  const legacyRefs = PERMISSIONS_COLLECTION_LEGACY_ALL.map((collectionName) =>
    userRef.collection(collectionName)
  );

  const [canonicalSnap, ...legacySnaps] = await Promise.all([
    canonicalRef.get(),
    ...legacyRefs.map((ref) => ref.get()),
  ]);
  const canonical = permissionMapFromQuerySnapshot(canonicalSnap);
  const legacy = {};
  for (const snapshot of legacySnaps) {
    Object.assign(legacy, permissionMapFromQuerySnapshot(snapshot));
  }
  const merged = mergePermissionMaps(canonical, legacy);

  return { canonical, legacy, merged };
}

async function writePermissionPatch(uid, patch, actorUID, source = "admin_callable") {
  const keys = Object.keys(patch || {});
  if (keys.length === 0) {
    return;
  }

  const userRef = db.collection(USERS_COLLECTION).doc(uid);
  const canonicalCol = userRef.collection(PERMISSIONS_COLLECTION_CANONICAL);
  const legacyCols = PERMISSIONS_COLLECTION_LEGACY_ALL.map((collectionName) =>
    userRef.collection(collectionName)
  );

  const batch = db.batch();
  for (const key of keys) {
    const canonicalKey = canonicalPermissionKey(key);
    if (!canonicalKey) continue;

    const payload = {
      allowed: patch[canonicalKey] === true,
      updatedAt: fieldValue.serverTimestamp(),
      updatedBy: optionalString(actorUID, 128),
      source: optionalString(source, 64) || "admin_callable",
    };

    batch.set(canonicalCol.doc(canonicalKey), payload, { merge: true });
    const legacyKeys = [...new Set(legacyMirrorPermissionKeys(canonicalKey))];
    for (const legacyCol of legacyCols) {
      for (const legacyKey of legacyKeys) {
        batch.set(legacyCol.doc(legacyKey), payload, { merge: true });
      }
    }
  }

  await batch.commit();
}

function sanitizeClaimsPatch(rawClaims) {
  const source = safeObject(rawClaims);
  const patch = {};

  for (const [key, value] of Object.entries(source)) {
    const safeKey = optionalString(key, 64);
    if (!safeKey || !/^[A-Za-z][A-Za-z0-9_]{0,63}$/.test(safeKey)) continue;

    if (value === null) {
      patch[safeKey] = null;
      continue;
    }

    if (typeof value === "boolean" || typeof value === "number" || typeof value === "string") {
      patch[safeKey] = value;
    }
  }

  return patch;
}

function mergeClaims(existingClaims, patch) {
  const merged = {
    ...safeObject(existingClaims),
  };

  for (const [key, value] of Object.entries(patch || {})) {
    if (value === null) {
      delete merged[key];
    } else {
      merged[key] = value;
    }
  }

  return merged;
}

function buildRoleClaims({ roleValue, roleName, isAdmin, isSuperAdmin, isAdminAll, isBlocked }) {
  return {
    roleValue: Number(roleValue),
    role: optionalString(roleName, 64) || roleNameForValue(roleValue),
    admin: isAdmin === true,
    isAdmin: isAdmin === true,
    superAdmin: isSuperAdmin === true,
    superadmin: isSuperAdmin === true,
    isSuperAdmin: isSuperAdmin === true,
    isAdminAll: isAdminAll === true,
    blocked: isBlocked === true,
    isBlocked: isBlocked === true,
  };
}

async function resolveTargetUID(data, fallbackUID = "") {
  const source = safeObject(data);
  const directUID = optionalString(source.uid, 128);
  if (directUID) {
    return directUID;
  }

  const email = optionalString(source.email, 254).toLowerCase();
  if (email) {
    const userRecord = await admin.auth().getUserByEmail(email);
    return userRecord.uid;
  }

  if (fallbackUID) {
    return fallbackUID;
  }

  throw new HttpsError("invalid-argument", "Either uid or email is required.");
}

async function writeAdminAuditLog({
  actorUID,
  targetUID,
  action,
  before = {},
  after = {},
  reason = "",
  note = "",
}) {
  await db.collection(ADMIN_AUDIT_COLLECTION).add({
    adminUid: optionalString(actorUID, 128),
    targetUid: optionalString(targetUID, 128),
    action: optionalString(action, 128),
    before: redactSensitive(safeObject(before)),
    after: redactSensitive(safeObject(after)),
    reason: optionalString(reason, 500),
    note: optionalString(note, 500),
    timestamp: fieldValue.serverTimestamp(),
  });
}

function hasDisallowedPaymentKey(dataMap) {
  const source = safeObject(dataMap);
  return PAYMENT_INSTRUMENT_DISALLOWED_KEYS.some((key) => key in source);
}

function scrubPaymentMap(dataMap) {
  const source = safeObject(dataMap);
  const sanitized = { ...source };
  const removedKeys = [];

  for (const key of PAYMENT_INSTRUMENT_DISALLOWED_KEYS) {
    if (key in sanitized) {
      removedKeys.push(key);
      delete sanitized[key];
    }
  }

  return {
    sanitized,
    removedKeys,
  };
}

function toTimestampFromNow(milliseconds) {
  const date = new Date(Date.now() + milliseconds);
  return admin.firestore.Timestamp.fromDate(date);
}

function computeRetryDelayMillis(retryCount) {
  const baseSecondsRaw = Number(process.env.QIB_VERIFY_RETRY_BASE_SECONDS || 120);
  const maxSecondsRaw = Number(process.env.QIB_VERIFY_RETRY_MAX_SECONDS || 3600);
  const baseSeconds = Number.isFinite(baseSecondsRaw) && baseSecondsRaw > 0 ? baseSecondsRaw : 120;
  const maxSeconds = Number.isFinite(maxSecondsRaw) && maxSecondsRaw > 0 ? maxSecondsRaw : 3600;
  const exponent = Math.max(0, Math.min(6, retryCount - 1));
  const computed = baseSeconds * (2 ** exponent);
  return Math.min(computed, maxSeconds) * 1000;
}

function shouldRetryProviderVerification(error, statusCode) {
  const code = optionalString(error?.code, 64).toLowerCase();
  if (code === "unavailable" || code === "deadline-exceeded") {
    return true;
  }
  if (statusCode === 429) {
    return true;
  }
  return Number.isInteger(statusCode) && statusCode >= 500;
}

function isTransientGatewayStatus(status) {
  const normalized = normalizedStatus(status);
  if (!normalized) return false;
  const transientTokens = [
    "pending",
    "in_progress",
    "processing",
    "gatewayerror",
    "gateway_error",
    "network",
    "timeout",
    "timed_out",
    "unavailable",
    "temporary",
    "unknown",
  ];
  return transientTokens.some((token) => statusContainsToken(normalized, token));
}

function hasValidShippingSnapshot(snapshot, uid, shippingAddressId) {
  const safeSnapshot = safeObject(snapshot);
  return (
    isNonEmptyString(safeSnapshot.userID) &&
    safeSnapshot.userID === uid &&
    isNonEmptyString(safeSnapshot.addressID) &&
    safeSnapshot.addressID === shippingAddressId &&
    isNonEmptyString(safeSnapshot.fullName) &&
    isNonEmptyString(safeSnapshot.addressLine1) &&
    isNonEmptyString(safeSnapshot.postalCode) &&
    Number.isInteger(Number(safeSnapshot.cityID)) &&
    Number(safeSnapshot.cityID) > 0 &&
    Number.isInteger(Number(safeSnapshot.stateID)) &&
    Number(safeSnapshot.stateID) > 0
  );
}

function buildPublicUserProfile(uid, data = {}) {
  const source = safeObject(data);
  const firstName = optionalString(source.FirstName, 128);
  const lastName = optionalString(source.LastName, 128);
  const fallbackFullName = [firstName, lastName].filter(Boolean).join(" ");
  const displayName =
    extractFirstString(source, ["displayName", "UserName", "fullName", "name", "UserEmail"]) ||
    fallbackFullName ||
    "Pure Pets User";

  return {
    uid: optionalString(uid, 128),
    displayName,
    photoURL:
      extractFirstString(source, ["photoURL", "UserImageUrl", "avatar", "UserImage"]) || "",
    canReceiveMessages: boolOrDefault(
      source.canReceiveMessages ?? source.isChatEnabled,
      true
    ),
    updatedAt: fieldValue.serverTimestamp(),
  };
}

function normalizeOrderPaymentProvider(data = {}) {
  const source = safeObject(data);
  const methodId = normalizeOrderPaymentMethodId(source);
  const explicitProvider = optionalString(source.paymentProvider, 64).toLowerCase();
  if (methodId === ORDER_PAYMENT_METHOD_CASH || explicitProvider === ORDER_PAYMENT_METHOD_CASH) {
    return "CASH";
  }
  return "QIB";
}

function normalizedPublicOrderNumber(value) {
  const raw = optionalString(value, 64).toUpperCase();
  if (!raw) return "";
  return raw.replace(/[^A-Z0-9-]/g, "");
}

function uppercaseAlphaNumericToken(value, maxLength = 128) {
  const raw = optionalString(value, maxLength).toUpperCase();
  if (!raw) return "";
  return raw.replace(/[^A-Z0-9]/g, "");
}

function groupedPublicOrderSuffix(rawValue) {
  const normalized = uppercaseAlphaNumericToken(rawValue, 64);
  if (!normalized) return "";

  const groups = [];
  for (let index = 0; index < normalized.length; index += 4) {
    groups.push(normalized.slice(index, index + 4));
  }
  return groups.join("-");
}

function deriveLegacyPublicOrderNumber(orderId) {
  const normalized = uppercaseAlphaNumericToken(orderId, 128);
  if (!normalized) return "";

  const tail =
    normalized.length > LEGACY_PUBLIC_ORDER_NUMBER_SUFFIX_LENGTH
      ? normalized.slice(-LEGACY_PUBLIC_ORDER_NUMBER_SUFFIX_LENGTH)
      : normalized;
  const groupedTail = groupedPublicOrderSuffix(tail);
  return groupedTail ? `${PUBLIC_ORDER_NUMBER_PREFIX}-${groupedTail}` : "";
}

function buildPublicOrderNumber(orderId, createdAt = new Date()) {
  const cleanOrderId = optionalString(orderId, 128);
  const digest = crypto.createHash("sha256").update(cleanOrderId).digest();
  let suffix = "";
  for (let index = 0; index < PUBLIC_ORDER_NUMBER_HASH_LENGTH; index += 1) {
    suffix += PUBLIC_ORDER_NUMBER_ALPHABET[digest[index] % PUBLIC_ORDER_NUMBER_ALPHABET.length];
  }

  const year = String(createdAt.getUTCFullYear()).slice(-2);
  const month = String(createdAt.getUTCMonth() + 1).padStart(2, "0");
  const day = String(createdAt.getUTCDate()).padStart(2, "0");
  return `${PUBLIC_ORDER_NUMBER_PREFIX}-${year}${month}${day}-${suffix}`;
}

function storedOrderNumber(orderData = {}, fallbackOrderId = "") {
  const source = safeObject(orderData);
  const explicit = normalizedPublicOrderNumber(
    source.orderNumber || source.displayOrderNumber
  );
  if (explicit) {
    return explicit;
  }

  const fallbackId = optionalString(source.orderId, 128) || optionalString(fallbackOrderId, 128);
  return deriveLegacyPublicOrderNumber(fallbackId);
}

function commercePaymentSettingsRef() {
  return db.collection(COMMERCE_CONFIG_COLLECTION).doc(COMMERCE_PAYMENT_SETTINGS_DOC);
}

function normalizeDeliveryFeeValue(rawValue, fallbackValue = DEFAULT_DELIVERY_FEE) {
  const numericValue = Number(rawValue);
  if (Number.isFinite(numericValue) && numericValue >= 0) {
    return Math.round(numericValue * 100) / 100;
  }

  const fallback = Number(fallbackValue);
  if (Number.isFinite(fallback) && fallback >= 0) {
    return Math.round(fallback * 100) / 100;
  }
  return DEFAULT_DELIVERY_FEE;
}

function buildDefaultCommercePaymentSettings() {
  return {
    configId: COMMERCE_PAYMENT_SETTINGS_DOC,
    deliveryFee: DEFAULT_DELIVERY_FEE,
    cashOnDeliveryEnabled: true,
    onlinePaymentEnabled: true,
  };
}

function normalizedCommercePaymentSettings(data = {}, existingData = {}) {
  const defaults = buildDefaultCommercePaymentSettings();
  const source = safeObject(data);
  const existing = safeObject(existingData);

  const deliveryFee = normalizeDeliveryFeeValue(
    source.deliveryFee,
    existing.deliveryFee ?? defaults.deliveryFee
  );
  const cashOnDeliveryEnabled = boolOrDefault(
    source.cashOnDeliveryEnabled,
    existing.cashOnDeliveryEnabled ?? defaults.cashOnDeliveryEnabled
  );
  const onlinePaymentEnabled = boolOrDefault(
    source.onlinePaymentEnabled,
    existing.onlinePaymentEnabled ?? defaults.onlinePaymentEnabled
  );

  return {
    configId: COMMERCE_PAYMENT_SETTINGS_DOC,
    deliveryFee,
    cashOnDeliveryEnabled,
    onlinePaymentEnabled,
  };
}

function buildCommercePaymentSettingsResponse(data = {}) {
  const source = safeObject(data);
  const normalized = normalizedCommercePaymentSettings(source);
  return {
    ...normalized,
    updatedBy: optionalString(source.updatedBy, 128),
    updatedAtMillis: epochMillisFromTimestamp(source.updatedAt),
  };
}

async function readCommercePaymentSettings() {
  const snapshot = await commercePaymentSettingsRef().get();
  const rawData = safeObject(snapshot.data());
  const normalized = normalizedCommercePaymentSettings(rawData);
  return {
    exists: snapshot.exists,
    ref: commercePaymentSettingsRef(),
    snapshot,
    rawData,
    data: {
      ...normalized,
      updatedBy: optionalString(rawData.updatedBy, 128),
      updatedAt: rawData.updatedAt,
      createdAt: rawData.createdAt,
    },
  };
}

function assertAllowedCheckoutPaymentMethod(methodId, settings) {
  const normalizedMethod = normalizeOrderPaymentMethodId({ paymentMethodId: methodId });
  const safeSettings = safeObject(settings);
  const cashOnDeliveryEnabled = boolOrDefault(
    safeSettings.cashOnDeliveryEnabled,
    buildDefaultCommercePaymentSettings().cashOnDeliveryEnabled
  );
  const onlinePaymentEnabled = boolOrDefault(
    safeSettings.onlinePaymentEnabled,
    buildDefaultCommercePaymentSettings().onlinePaymentEnabled
  );

  if (normalizedMethod === ORDER_PAYMENT_METHOD_CASH && !cashOnDeliveryEnabled) {
    throw new HttpsError("failed-precondition", "Cash on delivery is currently unavailable.");
  }
  if (normalizedMethod !== ORDER_PAYMENT_METHOD_CASH && !onlinePaymentEnabled) {
    throw new HttpsError("failed-precondition", "Online payment is currently unavailable.");
  }
}

function normalizeOrderPaymentMethodId(data = {}) {
  const source = safeObject(data);
  const rawMethodId = optionalString(
    source.paymentMethodId ||
      safeObject(source.paymentMethod).methodId ||
      source.paymentType ||
      source.paymentProvider,
    64
  ).toLowerCase();

  if (["cash", "cod", "cash_on_delivery"].includes(rawMethodId)) {
    return ORDER_PAYMENT_METHOD_CASH;
  }
  if (!rawMethodId || ["qib", "card", "online"].includes(rawMethodId)) {
    return ORDER_PAYMENT_METHOD_QIB;
  }
  return ORDER_PAYMENT_METHOD_QIB;
}

function storedOrderPaymentMethodId(orderData = {}) {
  const source = safeObject(orderData);
  return normalizeOrderPaymentMethodId({
    paymentMethodId: source.paymentMethodId,
    paymentProvider: source.paymentProvider,
    paymentType: source.paymentType,
  });
}

function normalizeOrderPaymentStatus(data = {}) {
  const source = safeObject(data);
  const rawStatus = optionalString(source.paymentStatus, 64).toLowerCase();
  if (
    [
      ORDER_PAYMENT_STATUS_PENDING,
      ORDER_PAYMENT_STATUS_PENDING_COLLECTION,
      ORDER_PAYMENT_STATUS_PAID,
      ORDER_PAYMENT_STATUS_FAILED,
      ORDER_PAYMENT_STATUS_CANCELLED,
    ].includes(rawStatus)
  ) {
    return rawStatus;
  }

  const methodId = normalizeOrderPaymentMethodId(source);
  if (methodId === ORDER_PAYMENT_METHOD_CASH) {
    return ORDER_PAYMENT_STATUS_PENDING_COLLECTION;
  }
  return ORDER_PAYMENT_STATUS_PENDING;
}

function legacyOrderHasCapturedPayment(orderData = {}) {
  if (normalizeOrderPaymentMethodId(orderData) === ORDER_PAYMENT_METHOD_CASH) {
    return (
      !!optionalString(orderData?.transactionId, 256) ||
      !!timestampToDate(orderData?.paidAt) ||
      !!timestampToDate(orderData?.paymentCollectedAt)
    );
  }

  const status = normalizedStatus(orderData?.status);
  return (
    !!optionalString(orderData?.transactionId, 256) ||
    !!timestampToDate(orderData?.paidAt) ||
    statusHasAny(status, [
      "paid",
      "success",
      "approved",
      "verified",
      "processing",
      "preparing",
      "packed",
      "shipped",
      "delivered",
      "fulfilled",
    ])
  );
}

function storedOrderPaymentStatus(orderData = {}) {
  const source = safeObject(orderData);
  const explicitStatus = normalizeOrderPaymentStatus(source);
  if (source.paymentStatus !== undefined) {
    return explicitStatus;
  }

  if (source.status !== undefined || source.transactionId !== undefined || source.paidAt !== undefined) {
    const methodId = normalizeOrderPaymentMethodId(source);
    if (methodId === ORDER_PAYMENT_METHOD_CASH) {
      return legacyOrderHasCapturedPayment(source)
        ? ORDER_PAYMENT_STATUS_PAID
        : isFailureLikePaymentOrderStatus(source.status)
          ? ORDER_PAYMENT_STATUS_FAILED
          : isCancelledLikePaymentOrderStatus(source.status)
            ? ORDER_PAYMENT_STATUS_CANCELLED
            : ORDER_PAYMENT_STATUS_PENDING_COLLECTION;
    }

    return legacyOrderHasCapturedPayment(source)
      ? ORDER_PAYMENT_STATUS_PAID
      : isFailureLikePaymentOrderStatus(source.status)
        ? ORDER_PAYMENT_STATUS_FAILED
        : isCancelledLikePaymentOrderStatus(source.status)
          ? ORDER_PAYMENT_STATUS_CANCELLED
          : normalizeOrderPaymentMethodId(source) === ORDER_PAYMENT_METHOD_CASH
            ? ORDER_PAYMENT_STATUS_PENDING_COLLECTION
            : ORDER_PAYMENT_STATUS_PENDING;
  }

  return explicitStatus;
}

function isCashOnDeliveryOrder(orderData = {}) {
  return storedOrderPaymentMethodId(orderData) === ORDER_PAYMENT_METHOD_CASH;
}

function isCollectedPaymentStatus(status) {
  return normalizedStatus(status) === ORDER_PAYMENT_STATUS_PAID;
}

function normalizeRequestedOrderItems(rawItems) {
  if (!Array.isArray(rawItems) || rawItems.length === 0) {
    throw new HttpsError("invalid-argument", "items are required.");
  }

  const aggregated = new Map();
  for (const rawItem of rawItems) {
    const item = safeObject(rawItem);
    const itemId = optionalString(item.itemId || item.itemID || item.id, 128);
    const quantity = Math.floor(Number(item.quantity ?? item.qty ?? 0));
    if (!itemId) {
      throw new HttpsError("invalid-argument", "Each order item must include an item id.");
    }
    if (!Number.isFinite(quantity) || quantity <= 0) {
      throw new HttpsError("invalid-argument", `Invalid quantity for item ${itemId}.`);
    }
    aggregated.set(itemId, (aggregated.get(itemId) || 0) + quantity);
  }

  return Array.from(aggregated.entries()).map(([itemId, quantity]) => ({
    itemId,
    quantity,
  }));
}

function buildShippingSnapshotFromAddress(uid, shippingAddressId, rawAddress) {
  const address = safeObject(rawAddress);
  const snapshot = {
    addressID: shippingAddressId,
    userID: uid,
    fullName:
      extractFirstString(address, ["fullName", "displayName", "name", "UserName"]) || "",
    phoneNumber: extractFirstString(address, ["phoneNumber", "MobileNo", "phone"]) || "",
    phone: extractFirstString(address, ["phoneNumber", "MobileNo", "phone"]) || "",
    addressLine1: extractFirstString(address, ["addressLine1", "address", "address1"]) || "",
    addressLine2: extractFirstString(address, ["addressLine2", "address2"]) || "",
    postalCode: extractFirstString(address, ["postalCode", "zipCode", "postal_code"]) || "",
    cityID: Number(address.cityID ?? address.cityId ?? 0),
    stateID: Number(address.stateID ?? address.stateId ?? 0),
    displayName: extractFirstString(address, ["displayName", "fullName", "locationName"]) || "",
  };

  const locationName =
    extractFirstString(address, ["locatioName", "locationName", "displayName", "area", "city"]) ||
    snapshot.displayName;
  if (locationName) {
    snapshot.locatioName = locationName;
    snapshot.locationName = locationName;
  }

  const city = extractFirstString(address, ["city"], 256);
  if (city) snapshot.city = city;
  const area = extractFirstString(address, ["area"], 256);
  if (area) snapshot.area = area;
  const locationPoints = optionalString(address.locationPoints, 2048);
  if (locationPoints) snapshot.locationPoints = locationPoints;

  if (!hasValidShippingSnapshot(snapshot, uid, shippingAddressId)) {
    throw new HttpsError("failed-precondition", "Selected shipping address is incomplete.");
  }

  return snapshot;
}

function buildOrderLineItem(itemId, quantity, accessoryData) {
  const data = safeObject(accessoryData);
  const stockQuantity = Math.floor(Number(data.quantity ?? 0));
  if (!Number.isFinite(stockQuantity) || stockQuantity <= 0) {
    throw new HttpsError("failed-precondition", `Item ${itemId} is out of stock.`);
  }
  if (quantity > stockQuantity) {
    throw new HttpsError(
      "failed-precondition",
      `Requested quantity for item ${itemId} exceeds available stock.`
    );
  }

  const unitPrice = positiveAmount(data.finalPrice ?? data.price, `price for item ${itemId}`);
  const imageURL =
    firstStringFromArray(data.imageURLsArray) ||
    firstStringFromArray(data.imageURLs) ||
    firstStringFromArray(data.imagesURLs) ||
    firstStringFromArray(data.imageItems) ||
    optionalString(data.imageURL || data.imageUrl, 2048);

  return {
    id: itemId,
    itemID: itemId,
    itemId,
    name: optionalString(data.name, 256) || itemId,
    price: unitPrice,
    qty: quantity,
    quantity,
    imageURL,
  };
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function normalizeQibMode(value) {
  const mode = optionalString(value, 32).toLowerCase();
  if (!mode) return "";
  if (["live", "prod", "production"].includes(mode)) return "live";
  if (["test", "demo", "sandbox", "uat", "staging"].includes(mode)) return "test";
  return "";
}

function shortFingerprint(value) {
  const source = optionalString(value, 2048);
  if (!source) return "";
  return crypto.createHash("sha256").update(source).digest("hex").slice(0, 12);
}

function parsePositiveAmountOrZero(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) return 0;
  return Math.round(amount * 100) / 100;
}

function resolveVerificationAmount(orderData, paymentResponse) {
  const data = safeObject(orderData);
  const payment = safeObject(paymentResponse);
  const paymentData = safeObject(payment.data);
  const storedPaymentResponse = safeObject(data.paymentResponse);
  const storedPaymentData = safeObject(storedPaymentResponse.data);
  const candidates = [
    data.totalAmount,
    data.amount,
    payment.amount,
    paymentData.amount,
    storedPaymentResponse.amount,
    storedPaymentData.amount,
  ];
  for (const candidate of candidates) {
    const parsed = parsePositiveAmountOrZero(candidate);
    if (parsed > 0) return parsed;
  }
  return 0;
}

function buildQibStatusSignaturePayload(gatewayId, amount, fieldName, fieldValue) {
  return `gatewayId=${gatewayId},amount=${amount},${fieldName}=${fieldValue}`;
}

function qibModeValue(mode) {
  return normalizeQibMode(mode) === "live" ? "LIVE" : "TEST";
}

function tryParseJSON(rawPayload) {
  const source = optionalString(rawPayload, 200000);
  if (!source) return {};
  try {
    return safeObject(JSON.parse(source));
  } catch (error) {
    return {};
  }
}

async function getOwnedOrder(orderId, uid) {
  const orderRef = db.collection("Orders").doc(orderId);
  const snapshot = await orderRef.get();
  if (!snapshot.exists) {
    logger.warn("Owned order lookup failed because the document does not exist", {
      orderId,
      uid,
    });
    throw new HttpsError("not-found", "Order not found.");
  }
  const orderData = safeObject(snapshot.data());
  const orderUserId = optionalString(orderData.userId, 128);
  if (!orderUserId || orderUserId !== uid) {
    logger.warn("Owned order lookup denied because the order belongs to another user", {
      orderId,
      uid,
      orderUserId,
    });
    throw new HttpsError("permission-denied", "You are not allowed to modify this order.");
  }
  return { orderRef, orderData };
}

function timestampToDate(value) {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value?.toDate === "function") return value.toDate();
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function statusHasAny(status, tokens) {
  const normalized = normalizedStatus(status);
  return (tokens || []).some((token) => statusContainsToken(normalized, normalizedStatus(token)));
}

function orderHasCapturedPayment(orderData) {
  const paymentStatus = storedOrderPaymentStatus(orderData);
  if (paymentStatus === ORDER_PAYMENT_STATUS_PAID) {
    return true;
  }
  if ([ORDER_PAYMENT_STATUS_FAILED, ORDER_PAYMENT_STATUS_CANCELLED].includes(paymentStatus)) {
    return false;
  }
  return legacyOrderHasCapturedPayment(orderData);
}

function qibAttemptAnchorMillis(orderData = {}) {
  const source = safeObject(orderData);
  return (
    epochMillisFromTimestamp(source.qibSessionCreatedAt) ||
    epochMillisFromTimestamp(source.updatedAt) ||
    epochMillisFromTimestamp(source.createdAt)
  );
}

function orderHasActiveQibAttempt(orderData = {}) {
  const source = safeObject(orderData);
  return (
    storedOrderPaymentMethodId(source) === ORDER_PAYMENT_METHOD_QIB &&
    (
      optionalString(source.paymentAttemptId, 128).length > 0 ||
      optionalString(source.qibSessionId, 128).length > 0 ||
      epochMillisFromTimestamp(source.qibSessionCreatedAt) > 0
    )
  );
}

function resolveUserDisplayNameFromData(data) {
  return (
    extractFirstString(data, ["fullName", "displayName", "UserName", "FirstName", "name"]) ||
    "Admin"
  );
}

function buildAdminActorSummary(uid, userData = {}) {
  return {
    uid: optionalString(uid, 128),
    name: resolveUserDisplayNameFromData(userData),
  };
}

function epochMillisFromTimestamp(value) {
  const dateValue = timestampToDate(value);
  return dateValue ? dateValue.getTime() : 0;
}

function isFailureLikePaymentOrderStatus(status) {
  return statusHasAny(status, ["failed", "rejected", "declined", "expired", "voided", "error"]);
}

function isCancelledLikePaymentOrderStatus(status) {
  return statusHasAny(status, ["cancelled", "canceled"]);
}

function isProcessingLikePaymentOrderStatus(status) {
  return statusHasAny(status, ["processing", "preparing", "packed", "confirmed"]);
}

function isShippedLikePaymentOrderStatus(status) {
  return statusHasAny(status, ["shipped", "shipping", "in_transit", "out_for_delivery"]);
}

function isDeliveredLikePaymentOrderStatus(status) {
  return statusHasAny(status, ["delivered", "fulfilled", "completed"]);
}

function canApprovePaymentOrderStatus(status) {
  const normalized = normalizedStatus(status);
  return normalized === ORDER_STATUS_PENDING || normalized === ORDER_STATUS_VERIFICATION_PENDING;
}

function canMarkProcessingPaymentOrder(orderData) {
  const status = normalizedStatus(orderData?.status);
  const methodId = storedOrderPaymentMethodId(orderData);
  if (!status) {
    return false;
  }
  if (
    isCancelledLikePaymentOrderStatus(status) ||
    isFailureLikePaymentOrderStatus(status) ||
    isProcessingLikePaymentOrderStatus(status) ||
    isShippedLikePaymentOrderStatus(status) ||
    isDeliveredLikePaymentOrderStatus(status)
  ) {
    return false;
  }
  if (methodId === ORDER_PAYMENT_METHOD_CASH) {
    return status === ORDER_STATUS_PENDING;
  }
  return orderHasCapturedPayment(orderData);
}

function canMarkShippedPaymentOrderStatus(status) {
  return isProcessingLikePaymentOrderStatus(status);
}

function canMarkDeliveredPaymentOrderStatus(status) {
  return isShippedLikePaymentOrderStatus(status);
}

function canCancelPaymentOrderStatus(status) {
  const normalized = normalizedStatus(status);
  if (!normalized) {
    return true;
  }
  if (isCancelledLikePaymentOrderStatus(normalized)) return false;
  if (isFailureLikePaymentOrderStatus(normalized)) return false;
  if (isDeliveredLikePaymentOrderStatus(normalized)) return false;
  if (isShippedLikePaymentOrderStatus(normalized)) return false;
  return true;
}

function canCollectCashPayment(orderData) {
  if (!isCashOnDeliveryOrder(orderData)) {
    return false;
  }

  const status = normalizedStatus(orderData?.status);
  if (!isDeliveredLikePaymentOrderStatus(status) || isCancelledLikePaymentOrderStatus(status)) {
    return false;
  }

  const paymentStatus = storedOrderPaymentStatus(orderData);
  return (
    paymentStatus === ORDER_PAYMENT_STATUS_PENDING_COLLECTION ||
    paymentStatus === ORDER_PAYMENT_STATUS_PENDING
  );
}

function buildOrderAuditState(orderData) {
  const source = safeObject(orderData);
  return {
    orderNumber: storedOrderNumber(source),
    status: normalizedStatus(source.status),
    workflowStatus: normalizedStatus(source.status),
    paymentMethodId: storedOrderPaymentMethodId(source),
    paymentStatus: storedOrderPaymentStatus(source),
    paymentProvider: optionalString(source.paymentProvider, 128),
    verificationStatus: normalizedStatus(source.verificationStatus),
    transactionId: optionalString(source.transactionId, 256),
    refundStatus: normalizedStatus(source.refundStatus),
    returnStatus: normalizedStatus(source.returnStatus),
    inventoryDeducted: boolOrDefault(source.inventoryDeducted, false),
    inventoryRestocked: boolOrDefault(source.inventoryRestocked, false),
    paidAt: epochMillisFromTimestamp(source.paidAt),
    processedAt: epochMillisFromTimestamp(source.processedAt),
    shippedAt: epochMillisFromTimestamp(source.shippedAt),
    deliveredAt: epochMillisFromTimestamp(source.deliveredAt),
    paymentCollectedAt: epochMillisFromTimestamp(source.paymentCollectedAt),
    updatedAt: epochMillisFromTimestamp(source.updatedAt),
  };
}

async function applyInventoryRestockInTransaction(transaction, orderData, adminSummary) {
  if (!boolOrDefault(orderData?.inventoryDeducted, false) || boolOrDefault(orderData?.inventoryRestocked, false)) {
    return {};
  }

  const aggregatedItems = aggregateOrderLineItems(orderData);
  if (aggregatedItems.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Order has no valid items for inventory restock."
    );
  }

  const pendingUpdates = [];
  for (const item of aggregatedItems) {
    const itemRef = db.collection("petAccessories").doc(item.itemId);
    const itemSnapshot = await transaction.get(itemRef);
    if (!itemSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        `Inventory item '${item.name || item.itemId}' no longer exists.`
      );
    }

    const currentQty = Math.max(0, Number(itemSnapshot.get("quantity") || 0));
    pendingUpdates.push({
      ref: itemRef,
      quantity: Math.max(0, currentQty + item.quantity),
    });
  }

  for (const update of pendingUpdates) {
    transaction.update(update.ref, {
      quantity: update.quantity,
      updatedAt: fieldValue.serverTimestamp(),
    });
  }

  return {
    inventoryRestocked: true,
    inventoryRestockedAt: fieldValue.serverTimestamp(),
    inventoryRestockedBy: safeObject(adminSummary),
  };
}

function buildOrderStatusNotificationContent(orderId, orderData, status) {
  const reference = `#${storedOrderNumber(orderData, orderId) || "Order"}`;
  switch (normalizedStatus(status)) {
    case ORDER_STATUS_PAID:
      return {
        title: "Payment Confirmed | تم تأكيد الدفع",
        body: `${reference} is confirmed and paid. تم تأكيد دفع طلبك.`,
      };
    case ORDER_STATUS_PROCESSING:
      return {
        title: "Order Processing | جاري تجهيز الطلب",
        body: `${reference} is now being prepared. جاري تجهيز طلبك الآن.`,
      };
    case ORDER_STATUS_SHIPPED:
      return {
        title: "Order Shipped | تم شحن الطلب",
        body: `${reference} is on the way. طلبك أصبح في الطريق.`,
      };
    case ORDER_STATUS_DELIVERED:
      return {
        title: "Order Delivered | تم تسليم الطلب",
        body: `${reference} has been delivered. تم تسليم طلبك.`,
      };
    case ORDER_STATUS_CANCELLED:
      return {
        title: "Order Cancelled | تم إلغاء الطلب",
        body: `${reference} was cancelled. تم إلغاء طلبك.`,
      };
    case ORDER_STATUS_FAILED:
      return {
        title: "Payment Failed | فشل الدفع",
        body: `${reference} could not be completed. تعذر إكمال عملية الدفع.`,
      };
    default:
      return null;
  }
}

function buildOrderPaymentStatusNotificationContent(orderId, orderData, paymentStatus) {
  const reference = `#${storedOrderNumber(orderData, orderId) || "Order"}`;
  const methodId = storedOrderPaymentMethodId(orderData);
  if (methodId === ORDER_PAYMENT_METHOD_CASH && normalizedStatus(paymentStatus) === ORDER_PAYMENT_STATUS_PAID) {
    return {
      title: "Cash Payment Collected | تم تحصيل الدفع",
      body: `${reference} cash payment was collected successfully. تم تحصيل قيمة الطلب بنجاح.`,
    };
  }
  return null;
}

function userHasPaymentManagementRole(userData) {
  const safeUserData = safeObject(userData);
  const roleValue = normalizeRoleValue(safeUserData.roleValue ?? safeUserData.role, 0);
  const roleName = optionalString(safeUserData.roleName || safeUserData.role, 64).toLowerCase();
  return (
    safeUserData.isAdmin === true ||
    safeUserData.isSuperAdmin === true ||
    safeUserData.isAdminAll === true ||
    [2, 5, 6, 7, 8].includes(roleValue) ||
    ["owner", "admin", "storemanager", "foodmanager", "superadmin"].includes(roleName)
  );
}

async function userCanReceivePaymentManagementNotifications(uid, userData) {
  if (userHasPaymentManagementRole(userData)) {
    return true;
  }

  const [hasManageStorePermission, hasAdminAllPermission] = await Promise.all([
    userHasNamedPermission(uid, "ManageStore"),
    userHasNamedPermission(uid, "AdminAll"),
  ]);
  return hasManageStorePermission || hasAdminAllPermission;
}

function adminInboxRef(uid) {
  return db.collection(USERS_COLLECTION).doc(uid).collection(USER_INBOX_SUBCOLLECTION);
}

function adminNotificationOrderReference(orderId, orderData) {
  return `#${storedOrderNumber(orderData, orderId) || orderId || "Order"}`;
}

function adminPaymentNotificationIdentifier(orderId, definition) {
  const eventKey = optionalString(definition?.eventKey, 64) || "admin_payment";
  const safeOrderId = optionalString(orderId, 128) || "order";
  return `${eventKey}__${safeOrderId}`.replace(/[\/\s]+/g, "_");
}

function chunkItems(items, chunkSize) {
  const safeItems = Array.isArray(items) ? items : [];
  const safeChunkSize = Math.max(1, Number(chunkSize) || 1);
  const chunks = [];
  for (let index = 0; index < safeItems.length; index += safeChunkSize) {
    chunks.push(safeItems.slice(index, index + safeChunkSize));
  }
  return chunks;
}

function isAlreadyExistsFirestoreError(error) {
  const code = error?.code;
  if (code === 6 || code === "already-exists" || code === "ALREADY_EXISTS") {
    return true;
  }
  const message = optionalString(error?.message, 256).toLowerCase();
  return message.includes("already exists");
}

function buildAdminNewOrderNotificationDefinition(orderId, orderData) {
  const orderReference = adminNotificationOrderReference(orderId, orderData);
  return {
    eventKey: "admin_order_created",
    orderReference,
    titleLocKey: "PaymentMgmt_Notification_NewOrder_Title",
    bodyLocKey: "PaymentMgmt_Notification_NewOrder_Body_Format",
    plainTitle: "New order",
    plainBody: `Open ${orderReference} in Payments Management.`,
  };
}

function buildAdminPaymentStatusNotificationDefinition(orderId, orderData, paymentStatus) {
  const normalizedPaymentStatus = normalizedStatus(paymentStatus);
  const orderReference = adminNotificationOrderReference(orderId, orderData);
  const paymentMethodId = storedOrderPaymentMethodId(orderData);

  switch (normalizedPaymentStatus) {
    case ORDER_PAYMENT_STATUS_PAID:
      if (paymentMethodId === ORDER_PAYMENT_METHOD_CASH) {
        return {
          eventKey: "admin_cash_collected",
          orderReference,
          titleLocKey: "PaymentMgmt_Notification_CashCollected_Title",
          bodyLocKey: "PaymentMgmt_Notification_CashCollected_Body_Format",
          plainTitle: "Cash collected",
          plainBody: `Cash collection was confirmed for ${orderReference}.`,
        };
      }
      return {
        eventKey: "admin_payment_paid",
        orderReference,
        titleLocKey: "PaymentMgmt_Notification_PaymentPaid_Title",
        bodyLocKey: "PaymentMgmt_Notification_PaymentPaid_Body_Format",
        plainTitle: "Payment confirmed",
        plainBody: `Payment was confirmed for ${orderReference}.`,
      };
    case ORDER_PAYMENT_STATUS_FAILED:
      return {
        eventKey: "admin_payment_failed",
        orderReference,
        titleLocKey: "PaymentMgmt_Notification_PaymentFailed_Title",
        bodyLocKey: "PaymentMgmt_Notification_PaymentFailed_Body_Format",
        plainTitle: "Payment failed",
        plainBody: `Payment failed for ${orderReference}.`,
      };
    case ORDER_PAYMENT_STATUS_CANCELLED:
      return {
        eventKey: "admin_payment_cancelled",
        orderReference,
        titleLocKey: "PaymentMgmt_Notification_PaymentCancelled_Title",
        bodyLocKey: "PaymentMgmt_Notification_PaymentCancelled_Body_Format",
        plainTitle: "Payment cancelled",
        plainBody: `Payment was cancelled for ${orderReference}.`,
      };
    default:
      return null;
  }
}

function adminNotificationPushTarget(userData) {
  const safeUserData = safeObject(userData);
  const adminToken = optionalString(safeUserData[ADMIN_PUSH_TOKEN_FIELD], 4096);
  if (adminToken) {
    return {
      token: adminToken,
      tokenField: ADMIN_PUSH_TOKEN_FIELD,
    };
  }

  const userToken = optionalString(safeUserData[USER_PUSH_TOKEN_FIELD], 4096);
  if (userToken) {
    return {
      token: userToken,
      tokenField: USER_PUSH_TOKEN_FIELD,
    };
  }

  return {
    token: "",
    tokenField: "",
  };
}

async function fetchUserSnapshotsByUIDs(uids) {
  const safeUIDs = [...new Set((Array.isArray(uids) ? uids : []).map((uid) => optionalString(uid, 128)).filter(Boolean))];
  if (safeUIDs.length === 0) {
    return [];
  }

  const refs = safeUIDs.map((uid) => db.collection(USERS_COLLECTION).doc(uid));
  const snapshots = [];
  for (const refBatch of chunkItems(refs, 50)) {
    const batchSnapshots = await db.getAll(...refBatch);
    snapshots.push(...(batchSnapshots || []).filter((snapshot) => snapshot?.exists));
  }
  return snapshots;
}

async function fetchPaymentAdminPermissionCandidateUIDs() {
  const permissionIDs = ["AdminAll", "ManageStore"];
  const queryTasks = [PERMISSIONS_COLLECTION_CANONICAL, ...PERMISSIONS_COLLECTION_LEGACY_ALL].map((collectionName) =>
    db
      .collectionGroup(collectionName)
      .where(admin.firestore.FieldPath.documentId(), "in", permissionIDs)
      .where("allowed", "==", true)
      .get()
  );

  const snapshots = await Promise.all(queryTasks);
  const uids = new Set();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs || []) {
      const uid = optionalString(doc.ref?.parent?.parent?.id, 128);
      if (uid) {
        uids.add(uid);
      }
    }
  }
  return [...uids];
}

async function fetchPaymentAdminCandidateSnapshots() {
  try {
    const roleQueries = [
      db.collection(USERS_COLLECTION).where("isAdmin", "==", true),
      db.collection(USERS_COLLECTION).where("isSuperAdmin", "==", true),
      db.collection(USERS_COLLECTION).where("isAdminAll", "==", true),
      db.collection(USERS_COLLECTION).where("roleValue", "in", [2, 5, 6, 7, 8]),
      db.collection(USERS_COLLECTION).where("role", "in", [2, 5, 6, 7, 8]),
      db.collection(USERS_COLLECTION).where("roleName", "in", ["owner", "admin", "storemanager", "foodmanager", "superadmin"]),
      db.collection(USERS_COLLECTION).where("role", "in", ["owner", "admin", "storemanager", "foodmanager", "superadmin"]),
    ];
    const [roleSnapshots, permissionSnapshots] = await Promise.all([
      Promise.all(roleQueries.map((queryRef) => queryRef.get())),
      fetchPaymentAdminPermissionCandidateUIDs().then((uids) => fetchUserSnapshotsByUIDs(uids)),
    ]);

    const candidateSnapshots = new Map();
    for (const snapshot of [...roleSnapshots, permissionSnapshots]) {
      const docs = Array.isArray(snapshot) ? snapshot : snapshot?.docs || [];
      for (const doc of docs) {
        const uid = optionalString(doc?.id, 128);
        if (!uid) continue;
        candidateSnapshots.set(uid, doc);
      }
    }

    return [...candidateSnapshots.values()];
  } catch (error) {
    logger.error("SECURITY: Admin notification recipient lookup failed. Refusing to fall back to full-users scan. No notifications will be sent for this event.", {
      error: error?.message || String(error),
      stack: error?.stack || "",
    });
    return [];
  }
}

const ADMIN_NOTIFICATION_RECIPIENT_CAP = 200;

function isUserDisabledOrDeactivated(userData) {
  const safeData = safeObject(userData);
  return safeData.disabled === true || safeData.deactivated === true || safeData.banned === true;
}

async function fetchPaymentAdminNotificationRecipients() {
  const candidateSnapshots = await fetchPaymentAdminCandidateSnapshots();
  const inboxRecipients = [];
  const pushRecipients = [];
  const seenTokens = new Set();
  let eligibleRecipientCount = 0;
  let missingPushTokenCount = 0;
  let fallbackPushRecipientCount = 0;
  let skippedDisabledCount = 0;
  for (const doc of candidateSnapshots) {
    const uid = optionalString(doc.id, 128);
    const userData = safeObject(doc.data());
    if (!uid) {
      continue;
    }

    if (isUserDisabledOrDeactivated(userData)) {
      skippedDisabledCount += 1;
      continue;
    }

    const eligible = userHasPaymentManagementRole(userData)
      ? true
      : await userCanReceivePaymentManagementNotifications(uid, userData);
    if (!eligible) {
      continue;
    }

    eligibleRecipientCount += 1;
    inboxRecipients.push({ uid });

    const pushTarget = adminNotificationPushTarget(userData);
    const token = pushTarget.token;
    if (!token) {
      missingPushTokenCount += 1;
      continue;
    }

    if (seenTokens.has(token)) {
      continue;
    }

    seenTokens.add(token);
    if (pushTarget.tokenField === USER_PUSH_TOKEN_FIELD) {
      fallbackPushRecipientCount += 1;
    }
    pushRecipients.push({ uid, token, tokenField: pushTarget.tokenField });
  }

  if (eligibleRecipientCount > ADMIN_NOTIFICATION_RECIPIENT_CAP) {
    logger.error("SECURITY: Admin notification recipient count exceeds safety cap. Blocking notification to prevent potential broadcast leak.", {
      eligibleRecipientCount,
      recipientCap: ADMIN_NOTIFICATION_RECIPIENT_CAP,
      candidateCount: candidateSnapshots.length,
      skippedDisabledCount,
    });
    return {
      inboxRecipients: [],
      pushRecipients: [],
      eligibleRecipientCount,
      missingPushTokenCount,
      fallbackPushRecipientCount,
      skippedDisabledCount,
      blocked: true,
      blockedReason: "recipient_cap_exceeded",
    };
  }

  if (skippedDisabledCount > 0) {
    logger.info("Admin notification recipient resolution skipped disabled/deactivated users", {
      skippedDisabledCount,
      eligibleRecipientCount,
    });
  }

  return {
    inboxRecipients,
    pushRecipients,
    eligibleRecipientCount,
    missingPushTokenCount,
    fallbackPushRecipientCount,
    skippedDisabledCount,
    blocked: false,
  };
}

async function writeAdminPaymentNotificationInboxEntries(recipients, orderId, orderData, definition, notificationId) {
  if (!Array.isArray(recipients) || recipients.length === 0) {
    return;
  }

  const safeDefinition = safeObject(definition);
  const safeNotificationId = optionalString(notificationId, 256) || adminPaymentNotificationIdentifier(orderId, safeDefinition);
  const meta = {
    notificationId: safeNotificationId,
    route: ADMIN_NOTIFICATION_ROUTE_PAYMENTS_ORDER,
    orderId: optionalString(orderId, 128),
    orderNumber: storedOrderNumber(orderData, orderId),
    orderReference: optionalString(safeDefinition.orderReference, 128),
    notificationEvent: optionalString(safeDefinition.eventKey, 64),
    paymentStatus: storedOrderPaymentStatus(orderData),
    paymentMethodId: storedOrderPaymentMethodId(orderData),
    titleLocalizationKey: optionalString(safeDefinition.titleLocKey, 128),
    bodyLocalizationKey: optionalString(safeDefinition.bodyLocKey, 128),
  };

  await Promise.all(
    recipients.map(async ({ uid }) => {
      try {
        await adminInboxRef(uid).doc(safeNotificationId).create({
          title: optionalString(safeDefinition.plainTitle, 200),
          body: optionalString(safeDefinition.plainBody, 500),
          targetUserID: optionalString(uid, 128),
          type: 1,
          isRead: false,
          meta,
          createdAt: fieldValue.serverTimestamp(),
        });
      } catch (error) {
        if (isAlreadyExistsFirestoreError(error)) {
          return;
        }
        throw error;
      }
    })
  );
}

async function removeInvalidAdminNotificationTokens(recipients, responses, definition, orderId, orderData) {
  const removals = [];
  for (let index = 0; index < responses.length; index += 1) {
    const result = responses[index];
    if (result?.success) {
      continue;
    }

    const recipient = recipients[index];
    const errorCode = optionalString(result?.error?.code, 128).toLowerCase();
    if (
      errorCode === "messaging/registration-token-not-registered" ||
      errorCode === "messaging/invalid-registration-token"
    ) {
      const tokenField = optionalString(recipient?.tokenField, 128) || ADMIN_PUSH_TOKEN_FIELD;
      removals.push(
        db.collection(USERS_COLLECTION).doc(recipient.uid).set(
          {
            [tokenField]: fieldValue.delete(),
            updatedAt: fieldValue.serverTimestamp(),
          },
          { merge: true }
        )
      );
      logger.warn("Removed invalid admin payment notification token", {
        orderId,
        adminUID: recipient.uid,
        eventKey: optionalString(definition?.eventKey, 64),
        paymentStatus: storedOrderPaymentStatus(orderData),
        errorCode,
        tokenField,
      });
    } else {
      logger.error("Failed to send admin payment notification", {
        orderId,
        adminUID: recipient?.uid || "",
        eventKey: optionalString(definition?.eventKey, 64),
        paymentStatus: storedOrderPaymentStatus(orderData),
        error: result?.error?.message || "",
        errorCode,
      });
    }
  }

  if (removals.length > 0) {
    await Promise.all(removals);
  }
}

async function sendAdminPaymentNotification(orderId, orderData, definition) {
  const safeDefinition = safeObject(definition);
  const titleLocKey = optionalString(safeDefinition.titleLocKey, 128);
  const bodyLocKey = optionalString(safeDefinition.bodyLocKey, 128);
  if (!titleLocKey || !bodyLocKey) {
    return { sent: false, reason: "notification_not_notifiable" };
  }

  const {
    inboxRecipients,
    pushRecipients,
    eligibleRecipientCount,
    missingPushTokenCount,
    fallbackPushRecipientCount,
    skippedDisabledCount,
    blocked,
    blockedReason,
  } = await fetchPaymentAdminNotificationRecipients();
  logger.info("Admin payment notification recipients resolved", {
    orderId,
    eventKey: optionalString(safeDefinition.eventKey, 64),
    paymentStatus: storedOrderPaymentStatus(orderData),
    eligibleRecipientCount,
    inboxRecipientCount: inboxRecipients.length,
    pushRecipientCount: pushRecipients.length,
    missingPushTokenCount,
    fallbackPushRecipientCount,
    skippedDisabledCount: skippedDisabledCount || 0,
    blocked: !!blocked,
  });

  if (blocked) {
    return {
      sent: false,
      reason: blockedReason || "blocked_by_safety_check",
      eligibleRecipientCount,
      missingPushTokenCount,
      fallbackPushRecipientCount,
    };
  }

  if (inboxRecipients.length === 0) {
    return {
      sent: false,
      reason: "missing_admin_recipients",
      eligibleRecipientCount,
      missingPushTokenCount,
      fallbackPushRecipientCount,
    };
  }

  const notificationId = adminPaymentNotificationIdentifier(orderId, safeDefinition);
  await writeAdminPaymentNotificationInboxEntries(inboxRecipients, orderId, orderData, safeDefinition, notificationId);

  const orderReference = optionalString(safeDefinition.orderReference, 128);
  if (pushRecipients.length === 0) {
    logger.info("Admin payment notification processed without push tokens", {
      orderId,
      eventKey: optionalString(safeDefinition.eventKey, 64),
      paymentStatus: storedOrderPaymentStatus(orderData),
      eligibleRecipientCount,
      inboxRecipientCount: inboxRecipients.length,
      pushRecipientCount: 0,
      missingPushTokenCount,
      fallbackPushRecipientCount,
    });

    return {
      sent: true,
      reason: "inbox_only",
      eligibleRecipientCount,
      inboxRecipientCount: inboxRecipients.length,
      pushRecipientCount: 0,
      missingPushTokenCount,
      fallbackPushRecipientCount,
      batchCount: 0,
      successCount: 0,
      failureCount: 0,
    };
  }

  const recipientBatches = chunkItems(pushRecipients, 500);
  let successCount = 0;
  let failureCount = 0;
  for (const recipientBatch of recipientBatches) {
    const message = {
      tokens: recipientBatch.map((recipient) => recipient.token),
      notification: {
        title: optionalString(safeDefinition.plainTitle, 200) || "",
        body: optionalString(safeDefinition.plainBody, 500) || "",
      },
      data: {
        route: ADMIN_NOTIFICATION_ROUTE_PAYMENTS_ORDER,
        notificationId,
        notificationType: optionalString(safeDefinition.eventKey, 64),
        orderId: optionalString(orderId, 128),
        orderNumber: storedOrderNumber(orderData, orderId),
        orderReference,
        paymentStatus: storedOrderPaymentStatus(orderData),
        paymentMethodId: storedOrderPaymentMethodId(orderData),
      },
      android: {
        priority: "high",
        notification: {
          channelId: "pp_orders",
          sound: "default",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
          "apns-collapse-id": notificationId,
        },
        payload: {
          aps: {
            sound: "default",
            alert: {
              "title-loc-key": titleLocKey,
              "loc-key": bodyLocKey,
              "loc-args": orderReference ? [orderReference] : [],
            },
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    successCount += Number(response.successCount) || 0;
    failureCount += Number(response.failureCount) || 0;
    await removeInvalidAdminNotificationTokens(
      recipientBatch,
      response.responses || [],
      safeDefinition,
      orderId,
      orderData
    );
  }

  logger.info("Admin payment notification processed", {
    orderId,
    eventKey: optionalString(safeDefinition.eventKey, 64),
    paymentStatus: storedOrderPaymentStatus(orderData),
    eligibleRecipientCount,
    inboxRecipientCount: inboxRecipients.length,
    pushRecipientCount: pushRecipients.length,
    missingPushTokenCount,
    fallbackPushRecipientCount,
    batchCount: recipientBatches.length,
    successCount,
    failureCount,
  });

  return {
    sent: true,
    eligibleRecipientCount,
    inboxRecipientCount: inboxRecipients.length,
    pushRecipientCount: pushRecipients.length,
    missingPushTokenCount,
    fallbackPushRecipientCount,
    batchCount: recipientBatches.length,
    successCount,
    failureCount,
  };
}

async function sendOrderNotification(orderId, orderData, payload = {}) {
  const content = safeObject(payload).content;
  if (!content) {
    return { sent: false, reason: "notification_not_notifiable" };
  }

  const userId = optionalString(orderData?.userId, 128);
  if (!userId) {
    return { sent: false, reason: "missing_user" };
  }

  const userRef = db.collection(USERS_COLLECTION).doc(userId);
  const userSnapshot = await userRef.get();
  if (!userSnapshot.exists) {
    logger.warn("Order notification target user does not exist", { orderId, userId });
    return { sent: false, reason: "user_not_found" };
  }
  const userData = safeObject(userSnapshot.data());

  // Cross-check: the Firestore user document UID must match the order's userId.
  // Prevents notification delivery if the userId field was corrupted or points to a
  // different document than expected.
  if (optionalString(userSnapshot.id, 128) !== userId) {
    logger.error("SECURITY: Order notification blocked — user document ID does not match order userId.", {
      orderId,
      orderUserId: userId,
      userDocId: optionalString(userSnapshot.id, 128),
    });
    return { sent: false, reason: "user_id_mismatch" };
  }

  if (isUserDisabledOrDeactivated(userData)) {
    logger.warn("Order notification blocked — target user is disabled/deactivated", { orderId, userId });
    return { sent: false, reason: "user_disabled" };
  }

  const token = optionalString(userData[USER_PUSH_TOKEN_FIELD], 4096);
  if (!token) {
    return { sent: false, reason: "missing_token" };
  }

  const message = {
    token,
    notification: {
      title: content.title,
      body: content.body,
    },
    data: {
      type: optionalString(payload.type, 64) || "order_status",
      notificationType: optionalString(payload.type, 64) || "order_status",
      route: "orders",
      orderId: optionalString(orderId, 128),
      orderNumber: storedOrderNumber(orderData, orderId),
      status: normalizedStatus(payload.status),
      paymentStatus: normalizedStatus(payload.paymentStatus),
    },
    android: {
      priority: "high",
      notification: {
        channelId: "pp_orders",
        sound: "default",
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  try {
    const messageId = await admin.messaging().send(message);
    logger.info("Order notification sent", {
      orderId,
      userId,
      type: optionalString(payload.type, 64) || "order_status",
      status: normalizedStatus(payload.status),
      paymentStatus: normalizedStatus(payload.paymentStatus),
      messageId,
    });
    return { sent: true, messageId };
  } catch (error) {
    const errorCode = optionalString(error?.code, 128).toLowerCase();
    if (
      errorCode === "messaging/registration-token-not-registered" ||
      errorCode === "messaging/invalid-registration-token"
    ) {
      await userRef.set(
        {
          [USER_PUSH_TOKEN_FIELD]: fieldValue.delete(),
          updatedAt: fieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      logger.warn("Removed invalid order notification token", {
        orderId,
        userId,
        type: optionalString(payload.type, 64) || "order_status",
        status: normalizedStatus(payload.status),
        paymentStatus: normalizedStatus(payload.paymentStatus),
        errorCode,
      });
    } else {
      logger.error("Failed to send order notification", {
        orderId,
        userId,
        type: optionalString(payload.type, 64) || "order_status",
        status: normalizedStatus(payload.status),
        paymentStatus: normalizedStatus(payload.paymentStatus),
        error: error?.message || String(error),
        errorCode,
      });
    }

    return {
      sent: false,
      reason: errorCode || "send_failed",
    };
  }
}

async function sendOrderStatusNotification(orderId, orderData, status) {
  return sendOrderNotification(orderId, orderData, {
    type: "order_status",
    status,
    content: buildOrderStatusNotificationContent(orderId, orderData, status),
  });
}

async function sendOrderPaymentStatusNotification(orderId, orderData, paymentStatus) {
  return sendOrderNotification(orderId, orderData, {
    type: "order_payment_status",
    paymentStatus,
    status: normalizedStatus(orderData?.status),
    content: buildOrderPaymentStatusNotificationContent(orderId, orderData, paymentStatus),
  });
}

function daysSince(dateValue, now = new Date()) {
  const anchor = timestampToDate(dateValue);
  if (!anchor) return Number.MAX_SAFE_INTEGER;
  const diff = Math.max(0, now.getTime() - anchor.getTime());
  return Math.floor(diff / (1000 * 60 * 60 * 24));
}

function normalizeRequestType(value) {
  const normalized = normalizedStatus(value);
  const allowed = new Set([
    ORDER_REQUEST_TYPE_CANCEL,
    ORDER_REQUEST_TYPE_RETURN,
    ORDER_REQUEST_TYPE_REFUND,
    ORDER_REQUEST_TYPE_REPLACEMENT,
    ORDER_REQUEST_TYPE_COMPLAINT,
    ORDER_REQUEST_TYPE_SUPPORT,
  ]);
  return allowed.has(normalized) ? normalized : ORDER_REQUEST_TYPE_SUPPORT;
}

function openRequestStatuses() {
  return [
    ORDER_REQUEST_PENDING_REVIEW,
    ORDER_REQUEST_APPROVED,
    "in_progress",
    "pending_customer",
  ];
}

function sanitizeAttachments(value) {
  if (!Array.isArray(value)) return [];
  return value
    .slice(0, 4)
    .map((entry) => safeObject(entry))
    .map((entry) => ({
      url: optionalString(entry.url, 2048),
      storagePath: optionalString(entry.storagePath, 1024),
      mimeType: optionalString(entry.mimeType, 128) || "image/jpeg",
      fileName: optionalString(entry.fileName, 256) || "evidence.jpg",
      sizeBytes: Number.isFinite(Number(entry.sizeBytes)) ? Number(entry.sizeBytes) : 0,
    }))
    .filter((entry) => entry.url);
}

function extractOrderLineItems(orderData) {
  const items = Array.isArray(orderData?.items) ? orderData.items : [];
  return items
    .map((raw) => {
      if (typeof raw === "string") {
        return {
          itemId: optionalString(raw, 256),
          name: optionalString(raw, 256),
          quantity: 1,
        };
      }
      if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
      const itemId = optionalString(raw.id || raw.itemID, 256);
      if (!itemId) return null;
      return {
        itemId,
        name: optionalString(raw.name || raw.title, 256) || itemId,
        quantity: Math.max(1, Number(raw.qty || raw.quantity || 1) || 1),
        price: Number(raw.price || raw.unitPrice || raw.finalPrice || 0) || 0,
        imageURL: optionalString(raw.imageURL || raw.image || raw.photo, 2048),
      };
    })
    .filter(Boolean);
}

function aggregateOrderLineItems(orderData) {
  const aggregated = new Map();

  for (const item of extractOrderLineItems(orderData)) {
    const itemId = optionalString(item?.itemId, 256);
    const quantity = Math.max(1, Number(item?.quantity || 1) || 1);
    if (!itemId || quantity <= 0) continue;

    const existing = aggregated.get(itemId) || {
      itemId,
      name: optionalString(item?.name, 256) || itemId,
      quantity: 0,
    };
    existing.quantity += quantity;
    aggregated.set(itemId, existing);
  }

  return Array.from(aggregated.values());
}

function buildSelectedItemSnapshots(orderData, selectedItemIDs, requestType, reasonCode) {
  const lineItems = extractOrderLineItems(orderData);
  const selected = Array.isArray(selectedItemIDs)
    ? selectedItemIDs.map((value) => optionalString(value, 256)).filter(Boolean)
    : [];

  const requiresItems =
    requestType === ORDER_REQUEST_TYPE_RETURN ||
    requestType === ORDER_REQUEST_TYPE_REPLACEMENT ||
    (requestType === ORDER_REQUEST_TYPE_COMPLAINT &&
      ["damaged_item", "wrong_item", "missing_item"].includes(reasonCode)) ||
    (requestType === ORDER_REQUEST_TYPE_REFUND && reasonCode === "missing_item");

  if (requiresItems && selected.length === 0) {
    throw new HttpsError("invalid-argument", "At least one affected item must be selected.");
  }

  const effectiveIDs =
    selected.length > 0
      ? selected
      : requestType === ORDER_REQUEST_TYPE_CANCEL
        ? lineItems.map((item) => item.itemId)
        : [];

  return lineItems
    .filter((item) => effectiveIDs.includes(item.itemId))
    .map((item) => ({
      itemId: item.itemId,
      name: item.name,
      quantity: item.quantity,
      price: item.price || 0,
      imageURL: item.imageURL || "",
    }));
}

function makeSupportRequestDedupeKey(requestType, reasonCode, itemSnapshots) {
  const stableItems = (itemSnapshots || [])
    .map((item) => `${optionalString(item.itemId, 256)}:${Math.max(1, Number(item.quantity || 1) || 1)}`)
    .sort()
    .join("|");
  return crypto
    .createHash("sha256")
    .update(`${requestType}|${reasonCode}|${stableItems}`)
    .digest("hex")
    .slice(0, 32);
}

function evaluateSupportEligibility(orderData, requestType, now = new Date()) {
  const status = normalizedStatus(orderData?.status);
  const paymentStatus = storedOrderPaymentStatus(orderData);
  const hasCapturedPayment = orderHasCapturedPayment(orderData);
  const hasPlacedOrder =
    !!optionalString(orderData?.orderId, 128) ||
    !!timestampToDate(orderData?.createdAt) ||
    status.length > 0;
  const deliveredLike = statusHasAny(status, ["delivered", "completed", "fulfilled"]);
  const shippedLike = statusHasAny(status, ["shipped", "shipping", "in_transit", "out_for_delivery"]);
  const cancelledLike = statusHasAny(status, ["cancelled", "canceled"]);
  const failedLike = statusHasAny(status, ["failed", "rejected", "expired", "voided"]);
  const paymentAnchor =
    timestampToDate(orderData?.paymentCollectedAt) ||
    timestampToDate(orderData?.paidAt) ||
    timestampToDate(orderData?.verifiedAt) ||
    timestampToDate(orderData?.statusUpdatedAt) ||
    timestampToDate(orderData?.updatedAt) ||
    timestampToDate(orderData?.createdAt);
  const deliveryAnchor =
    timestampToDate(orderData?.deliveredAt) ||
    timestampToDate(orderData?.statusUpdatedAt) ||
    timestampToDate(orderData?.updatedAt) ||
    timestampToDate(orderData?.createdAt);

  switch (requestType) {
    case ORDER_REQUEST_TYPE_CANCEL:
      if (cancelledLike || failedLike) {
        return { eligible: false, message: "This order is already closed." };
      }
      if (shippedLike || deliveredLike || statusHasAny(status, ["packed"])) {
        return { eligible: false, message: "Cancellation is only available before packing or shipping begins." };
      }
      return { eligible: true, message: "Cancellation is currently available." };

    case ORDER_REQUEST_TYPE_RETURN:
      if (!deliveredLike) {
        return { eligible: false, message: "Returns become available after delivery." };
      }
      if (daysSince(deliveryAnchor, now) > 7) {
        return { eligible: false, message: "The return window has expired." };
      }
      return { eligible: true, message: "Return request is eligible." };

    case ORDER_REQUEST_TYPE_REPLACEMENT:
      if (!deliveredLike) {
        return { eligible: false, message: "Replacement requests become available after delivery." };
      }
      if (daysSince(deliveryAnchor, now) > 7) {
        return { eligible: false, message: "The replacement window has expired." };
      }
      return { eligible: true, message: "Replacement request is eligible." };

    case ORDER_REQUEST_TYPE_REFUND:
      if (!hasCapturedPayment && !cancelledLike) {
        return { eligible: false, message: "Refund requests are available only after payment is captured." };
      }
      if (daysSince(paymentAnchor, now) > 14) {
        return { eligible: false, message: "The refund request window has expired." };
      }
      return { eligible: true, message: "Refund request is eligible." };

    case ORDER_REQUEST_TYPE_COMPLAINT:
      if (!hasPlacedOrder && !cancelledLike && !failedLike && paymentStatus !== ORDER_PAYMENT_STATUS_PENDING_COLLECTION) {
        return { eligible: false, message: "Issue reporting becomes available after the order is placed." };
      }
      if (daysSince(paymentAnchor, now) > 30) {
        return { eligible: false, message: "The issue reporting window has expired." };
      }
      return { eligible: true, message: "Issue reporting is eligible." };

    case ORDER_REQUEST_TYPE_SUPPORT:
    default:
      return { eligible: true, message: "Support is always available for your order." };
  }
}

function appendOrderEvent(orderRef, type, status, actorType, metadataOrSummary = {}, maybeMetadata = {}) {
  const summary =
    typeof metadataOrSummary === "string" ? optionalString(metadataOrSummary, 500) : "";
  const metadata =
    typeof metadataOrSummary === "string"
      ? safeObject(maybeMetadata)
      : safeObject(metadataOrSummary);
  const eventRef = orderRef.collection(ORDER_EVENTS_COLLECTION).doc();
  const payload = {
    eventId: eventRef.id,
    type,
    status,
    actorType,
    metadata,
    createdAt: fieldValue.serverTimestamp(),
    updatedAt: fieldValue.serverTimestamp(),
  };
  if (summary) {
    payload.summary = summary;
  }
  return eventRef.set(payload);
}

function appendOrderEventInTransaction(
  transaction,
  orderRef,
  type,
  status,
  actorType,
  metadataOrSummary = {},
  maybeMetadata = {}
) {
  const summary =
    typeof metadataOrSummary === "string" ? optionalString(metadataOrSummary, 500) : "";
  const metadata =
    typeof metadataOrSummary === "string"
      ? safeObject(maybeMetadata)
      : safeObject(metadataOrSummary);
  const eventRef = orderRef.collection(ORDER_EVENTS_COLLECTION).doc();
  const payload = {
    eventId: eventRef.id,
    type,
    status,
    actorType,
    metadata,
    createdAt: fieldValue.serverTimestamp(),
    updatedAt: fieldValue.serverTimestamp(),
  };
  if (summary) {
    payload.summary = summary;
  }
  transaction.set(eventRef, payload);
}

function appendRequestEventInTransaction(transaction, requestRef, type, status, actorType, metadata = {}) {
  const eventRef = requestRef.collection(REQUEST_EVENTS_SUBCOLLECTION).doc();
  transaction.set(eventRef, {
    eventId: eventRef.id,
    type,
    status,
    actorType,
    metadata: safeObject(metadata),
    createdAt: fieldValue.serverTimestamp(),
    updatedAt: fieldValue.serverTimestamp(),
  });
}

function appendPaymentAuditLogInTransaction(transaction, orderRef, actorSummary, action, note, before, after) {
  const auditRef = db.collection(ADMIN_AUDIT_COLLECTION).doc();
  transaction.set(auditRef, {
    auditId: auditRef.id,
    area: "payments",
    action: optionalString(action, 128) || "payment_update",
    entityType: "order",
    entityId: optionalString(orderRef.id, 128),
    orderId: optionalString(orderRef.id, 128),
    requestId: "",
    adminUid: optionalString(actorSummary?.uid, 128),
    adminName: optionalString(actorSummary?.name, 256) || "Admin",
    note: optionalString(note, 500),
    before: redactSensitive(safeObject(before)),
    after: redactSensitive(safeObject(after)),
    createdAt: fieldValue.serverTimestamp(),
  });
}

async function applyInventoryDeductionInTransaction(transaction, orderData) {
  if (boolOrDefault(orderData?.inventoryDeducted, false)) {
    return {
      inventoryDeducted: true,
    };
  }

  const aggregatedItems = aggregateOrderLineItems(orderData);
  if (aggregatedItems.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Order has no valid items for inventory deduction."
    );
  }

  const pendingUpdates = [];
  const lowStockItemIDs = [];
  const lowStockThreshold = 3;

  for (const item of aggregatedItems) {
    const itemRef = db.collection("petAccessories").doc(item.itemId);
    const itemSnapshot = await transaction.get(itemRef);
    if (!itemSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        `Inventory item '${item.name || item.itemId}' no longer exists.`
      );
    }

    const currentQty = Math.max(0, Number(itemSnapshot.get("quantity") || 0));
    if (currentQty < item.quantity) {
      throw new HttpsError(
        "failed-precondition",
        `Insufficient stock for '${item.name || item.itemId}'.`
      );
    }

    const newQty = Math.max(0, currentQty - item.quantity);
    pendingUpdates.push({
      ref: itemRef,
      quantity: newQty,
    });
    if (newQty <= lowStockThreshold) {
      lowStockItemIDs.push(item.itemId);
    }
  }

  for (const update of pendingUpdates) {
    transaction.update(update.ref, {
      quantity: update.quantity,
      updatedAt: fieldValue.serverTimestamp(),
    });
  }

  return {
    inventoryDeducted: true,
    inventoryDeductedAt: fieldValue.serverTimestamp(),
    inventoryRestocked: false,
    inventoryLowStockItemIDs: lowStockItemIDs,
  };
}

function mustHaveGatewayConfig() {
  const configuredModeRaw = optionalString(process.env.QIB_MODE, 32);
  const normalizedMode = normalizeQibMode(configuredModeRaw);

  if (!configuredModeRaw || !normalizedMode) {
    throw new HttpsError(
      "failed-precondition",
      "QIB_MODE is required and must be 'test' or 'live'."
    );
  }

  const testGatewayId = optionalString(process.env.QIB_GATEWAY_ID_TEST, 256);
  const testSecretKey = optionalString(process.env.QIB_SECRET_KEY_TEST, 512);
  const liveGatewayId = optionalString(process.env.QIB_GATEWAY_ID_LIVE, 256);
  const liveSecretKey = optionalString(process.env.QIB_SECRET_KEY_LIVE, 512);

  const mode = normalizedMode;
  const gatewayId = mode === "test" ? testGatewayId : liveGatewayId;
  const secretKey = mode === "test" ? testSecretKey : liveSecretKey;
  const configSource = mode === "test" ? "test_pair" : "live_pair";

  if (!gatewayId || !secretKey) {
    throw new HttpsError(
      "failed-precondition",
      `Missing QIB credentials for mode '${mode}'. Set QIB_GATEWAY_ID_${mode.toUpperCase()} and QIB_SECRET_KEY_${mode.toUpperCase()}.`
    );
  }

  return {
    gatewayId,
    secretKey,
    mode,
    configSource,
    gatewayIdSuffix: gatewayId.slice(-4),
    secretFingerprint: shortFingerprint(secretKey),
  };
}

function extractPaymentStatus(response) {
  const payload = safeObject(response);
  const nested = safeObject(payload.data);
  return normalizedStatus(
    extractFirstString(payload, ["status", "paymentStatus", "result", "transactionStatus"]) ||
      extractFirstString(nested, ["status", "paymentStatus", "result", "transactionStatus"])
  );
}

function extractTransactionID(response, providerResponse) {
  const keys = ["transactionId", "transaction_id", "paymentId", "payment_id", "referenceId", "reference_id", "id"];
  return (
    extractFirstString(providerResponse, keys) ||
    extractFirstString(safeObject(providerResponse).data, keys) ||
    extractFirstString(response, keys) ||
    extractFirstString(safeObject(response).data, keys)
  );
}

async function verifyWithProviderIfConfigured(orderId, orderData, paymentResponse) {
  const verifyURL = optionalString(process.env.QIB_VERIFY_URL, 2048);
  if (!verifyURL) {
    if (!CLIENT_ONLY_VERIFICATION_FALLBACK_ENABLED) {
      throw new HttpsError(
        "failed-precondition",
        "QIB_VERIFY_URL is required for secure payment verification."
      );
    }

    const localStatus = extractPaymentStatus(paymentResponse) || "unknown";
    logger.warn("QIB verify endpoint missing; using client-only payment status fallback", {
      orderId,
      localStatus,
    });
    return {
      providerPayload: {
        source: "client_payload_fallback",
        status: localStatus,
      },
      providerStatus: localStatus,
    };
  }

  const verifyAPIKey = optionalString(process.env.QIB_VERIFY_API_KEY, 512);
  const headers = {
    "content-type": "application/x-www-form-urlencoded;charset=UTF-8",
  };
  if (verifyAPIKey) {
    headers.authorization = `Bearer ${verifyAPIKey}`;
  }

  const { gatewayId, secretKey, mode } = mustHaveGatewayConfig();
  const amount = resolveVerificationAmount(orderData, paymentResponse);
  if (!amount) {
    throw new HttpsError("failed-precondition", "Order amount is invalid for payment verification.");
  }
  const amountValue = amount.toFixed(2);
  const transactionId = optionalString(extractTransactionID(paymentResponse, paymentResponse), 256);
  const attempts = [];
  if (transactionId) {
    attempts.push({
      signatureFields: "gatewayId,amount,transactionId",
      signatureInput: buildQibStatusSignaturePayload(gatewayId, amountValue, "transactionId", transactionId),
      formFieldName: "transactionId",
      formFieldValue: transactionId,
      source: "transaction_id",
    });
  }
  attempts.push({
    signatureFields: "gatewayId,amount,referenceId",
    signatureInput: buildQibStatusSignaturePayload(gatewayId, amountValue, "referenceId", orderId),
    formFieldName: "referenceId",
    formFieldValue: orderId,
    source: "reference_id",
  });

  let lastError = null;
  for (const attempt of attempts) {
    const signature = crypto
      .createHmac("sha256", secretKey)
      .update(attempt.signatureInput)
      .digest("base64");

    const requestForm = new URLSearchParams();
    requestForm.set("action", "status");
    requestForm.set("gatewayId", gatewayId);
    requestForm.set("signatureFields", attempt.signatureFields);
    requestForm.set("signature", signature);
    requestForm.set("referenceId", orderId);
    requestForm.set("amount", amountValue);
    requestForm.set("mode", qibModeValue(mode));
    requestForm.set(attempt.formFieldName, attempt.formFieldValue);

    let response;
    try {
      response = await fetch(verifyURL, {
        method: "POST",
        headers,
        body: requestForm.toString(),
      });
    } catch (error) {
      lastError = new HttpsError(
        "unavailable",
        `Provider verification request failed: ${optionalString(error?.message, 256) || "network error"}`
      );
      continue;
    }

    const rawProviderBody = await response.text();
    const providerPayload = tryParseJSON(rawProviderBody);
    const providerStatus = normalizedStatus(
      extractFirstString(providerPayload, ["status", "paymentStatus", "result", "transactionStatus"]) ||
        extractFirstString(safeObject(providerPayload.data), ["status", "paymentStatus", "result", "transactionStatus"])
    );
    if (response.ok && providerStatus) {
      return {
        providerPayload: {
          ...providerPayload,
          verificationSource: "qib_gateway_status_api",
          verificationAttempt: attempt.source,
          referenceId: orderId,
        },
        providerStatus,
      };
    }

    const providerErrorMessage = optionalString(
      extractFirstString(providerPayload, ["message", "error", "reason", "statusDescription"]),
      256
    ) || optionalString(rawProviderBody, 256);
    if (response.ok && !providerStatus) {
      const rawLower = optionalString(rawProviderBody, 1024).toLowerCase();
      const looksTransientBody =
        rawLower.includes("error fetching status") ||
        rawLower.includes("could not connect") ||
        rawLower.includes("timeout") ||
        rawLower.includes("temporar");
      lastError = new HttpsError(
        looksTransientBody ? "unavailable" : "failed-precondition",
        providerErrorMessage
          ? `Provider verification response did not contain a payment status: ${providerErrorMessage}`
          : "Provider verification response did not contain a payment status."
      );
      continue;
    }

    const failureMessage = providerErrorMessage
      ? `Provider verification failed with HTTP ${response.status}: ${providerErrorMessage}`
      : `Provider verification failed with HTTP ${response.status}.`;
    lastError = shouldRetryProviderVerification(null, response.status)
      ? new HttpsError("unavailable", failureMessage)
      : new HttpsError("failed-precondition", failureMessage);
  }

  if (lastError) {
    throw lastError;
  }
  throw new HttpsError("internal", "Provider verification attempt failed before receiving a valid response.");
}

function extractStoredClientPaymentResponse(orderData) {
  const paymentResponse = safeObject(orderData?.paymentResponse);
  const clientPayload = safeObject(paymentResponse.client);
  if (Object.keys(clientPayload).length > 0) {
    return clientPayload;
  }
  return paymentResponse;
}

function validateQibAttemptBinding(orderData, paymentAttemptId, qibSessionId) {
  const storedAttemptId = optionalString(orderData?.paymentAttemptId, 128);
  const storedSessionId = optionalString(orderData?.qibSessionId, 128);

  if (!storedAttemptId) {
    throw new HttpsError("failed-precondition", "Order is missing a server-issued payment attempt identifier.");
  }
  if (!storedSessionId) {
    throw new HttpsError("failed-precondition", "Order is missing an active QIB session identifier.");
  }
  if (!paymentAttemptId) {
    throw new HttpsError("invalid-argument", "paymentAttemptId is required.");
  }
  if (!qibSessionId) {
    throw new HttpsError("invalid-argument", "qibSessionId is required.");
  }
  if (paymentAttemptId !== storedAttemptId) {
    throw new HttpsError("failed-precondition", "Payment attempt does not match the active order session.");
  }
  if (qibSessionId !== storedSessionId) {
    throw new HttpsError("failed-precondition", "QIB session does not match the active order session.");
  }
}

function resolveVerificationResult(paymentResponse, providerResult) {
  const localStatus = extractPaymentStatus(paymentResponse);
  const providerStatus = normalizedStatus(providerResult?.providerStatus);
  const classifiedStatus = classifyStatus(providerStatus);
  const finalStatus = classifiedStatus === ORDER_STATUS_PAID ? ORDER_STATUS_PAID : ORDER_STATUS_FAILED;
  const transactionId = extractTransactionID(paymentResponse, providerResult?.providerPayload);

  const failureReason =
    finalStatus === ORDER_STATUS_FAILED
      ? optionalString(
          extractFirstString(providerResult?.providerPayload, [
            "failureReason",
            "message",
            "error",
            "reason",
            "statusReason",
            "statusDescription",
          ]) ||
            extractFirstString(safeObject(providerResult?.providerPayload?.data), [
              "failureReason",
              "message",
              "error",
              "reason",
              "statusReason",
              "statusDescription",
            ]) ||
            extractFirstString(paymentResponse, [
              "failureReason",
              "message",
              "error",
              "reason",
              "statusReason",
              "statusDescription",
            ]) ||
            extractFirstString(safeObject(paymentResponse.data), [
              "failureReason",
              "message",
              "error",
              "reason",
              "statusReason",
              "statusDescription",
            ]),
          500
        ) ||
        (providerStatus === "gatewayerror"
          ? "Could not connect to QIB gateway."
          : "Payment verification failed.")
      : "";

  return {
    localStatus,
    providerStatus,
    finalStatus,
    transactionId,
    failureReason,
  };
}

function buildFinalVerificationUpdate(paymentResponse, providerResult, result) {
  const updatePayload = {
    status: result.finalStatus,
    paymentMethodId: ORDER_PAYMENT_METHOD_QIB,
    paymentProvider: "QIB",
    paymentStatus:
      result.finalStatus === ORDER_STATUS_PAID
        ? ORDER_PAYMENT_STATUS_PAID
        : ORDER_PAYMENT_STATUS_FAILED,
    paymentResponse: {
      client: redactSensitive(paymentResponse),
      provider: providerResult?.providerPayload ? redactSensitive(providerResult.providerPayload) : null,
    },
    verificationStatus:
      result.finalStatus === ORDER_STATUS_PAID
        ? ORDER_VERIFICATION_VERIFIED
        : ORDER_VERIFICATION_FAILED,
    verifiedAt: fieldValue.serverTimestamp(),
    verificationLastError: fieldValue.delete(),
    verificationNextRetryAt: fieldValue.delete(),
    verificationRetryCount: fieldValue.delete(),
    qibSessionId: fieldValue.delete(),
    paymentAttemptId: fieldValue.delete(),
    statusUpdatedAt: fieldValue.serverTimestamp(),
    updatedAt: fieldValue.serverTimestamp(),
  };

  if (result.transactionId) {
    updatePayload.transactionId = result.transactionId;
  } else {
    updatePayload.transactionId = fieldValue.delete();
  }

  if (result.failureReason) {
    updatePayload.failureReason = result.failureReason;
  } else {
    updatePayload.failureReason = fieldValue.delete();
  }

  if (result.finalStatus === ORDER_STATUS_PAID) {
    updatePayload.paidAt = fieldValue.serverTimestamp();
  }

  return updatePayload;
}

function buildPaidVerificationRepairUpdate(orderData, paymentResponse, providerResult, result) {
  const updatePayload = {
    paymentMethodId: ORDER_PAYMENT_METHOD_QIB,
    verificationStatus: ORDER_VERIFICATION_VERIFIED,
    paymentProvider: "QIB",
    paymentStatus: ORDER_PAYMENT_STATUS_PAID,
    paymentResponse: {
      client: redactSensitive(paymentResponse),
      provider: providerResult?.providerPayload ? redactSensitive(providerResult.providerPayload) : null,
    },
    verifiedAt: fieldValue.serverTimestamp(),
    verificationLastError: fieldValue.delete(),
    verificationNextRetryAt: fieldValue.delete(),
    verificationRetryCount: fieldValue.delete(),
    qibSessionId: fieldValue.delete(),
    paymentAttemptId: fieldValue.delete(),
    updatedAt: fieldValue.serverTimestamp(),
  };

  if (!orderData?.paidAt) {
    updatePayload.paidAt = fieldValue.serverTimestamp();
  }

  if (result.transactionId && !optionalString(orderData?.transactionId, 256)) {
    updatePayload.transactionId = result.transactionId;
  }

  if (optionalString(orderData?.failureReason, 500)) {
    updatePayload.failureReason = fieldValue.delete();
  }

  return updatePayload;
}

async function finalizeOrderVerification(orderRef, paymentResponse, providerResult, verificationResult, actorType = "system", metadata = {}) {
  return db.runTransaction(async (transaction) => {
    const orderSnapshot = await transaction.get(orderRef);
    if (!orderSnapshot.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }

    const orderData = safeObject(orderSnapshot.data());
    const currentStatus = normalizedStatus(orderData.status);
    const verificationStatus = normalizedStatus(orderData.verificationStatus);
    const transactionId =
      verificationResult.transactionId || optionalString(orderData.transactionId, 256);
    const eventMetadata = {
      transactionId,
      providerStatus: verificationResult.providerStatus || "",
      ...safeObject(metadata),
    };

    if (verificationResult.finalStatus === ORDER_STATUS_PAID) {
      const inventoryPatch = await applyInventoryDeductionInTransaction(transaction, orderData);
      const updatePayload =
        currentStatus === ORDER_STATUS_PAID
          ? buildPaidVerificationRepairUpdate(orderData, paymentResponse, providerResult, verificationResult)
          : buildFinalVerificationUpdate(paymentResponse, providerResult, verificationResult);

      transaction.update(orderRef, {
        ...updatePayload,
        ...inventoryPatch,
      });

      if (currentStatus !== ORDER_STATUS_PAID) {
        appendOrderEventInTransaction(
          transaction,
          orderRef,
          "payment_verified",
          ORDER_STATUS_PAID,
          actorType,
          eventMetadata
        );
      }

      return {
        status: ORDER_STATUS_PAID,
        transactionId,
        failureReason: "",
      };
    }

    if (currentStatus === ORDER_STATUS_PAID) {
      return {
        status: ORDER_STATUS_PAID,
        transactionId,
        failureReason: "",
      };
    }

    if (
      currentStatus === verificationResult.finalStatus &&
      verificationStatus === ORDER_VERIFICATION_FAILED
    ) {
      return {
        status: verificationResult.finalStatus,
        transactionId,
        failureReason:
          verificationResult.failureReason || optionalString(orderData.failureReason, 500),
      };
    }

    transaction.update(
      orderRef,
      buildFinalVerificationUpdate(paymentResponse, providerResult, verificationResult)
    );
    appendOrderEventInTransaction(
      transaction,
      orderRef,
      "payment_failed",
      verificationResult.finalStatus,
      actorType,
      eventMetadata
    );

    return {
      status: verificationResult.finalStatus,
      transactionId,
      failureReason:
        verificationResult.failureReason || optionalString(orderData.failureReason, 500),
    };
  });
}

async function markVerificationPending(orderRef, orderData, paymentResponse, error, providerPayload = null) {
  const previousRetries = Number(orderData?.verificationRetryCount || 0);
  const retryCount = Number.isFinite(previousRetries) ? previousRetries + 1 : 1;
  const nextRetryAt = toTimestampFromNow(computeRetryDelayMillis(retryCount));
  const failureReason = optionalString(error?.message, 500) || "Payment verification pending.";

  await orderRef.update({
    status: ORDER_STATUS_PENDING,
    paymentMethodId: ORDER_PAYMENT_METHOD_QIB,
    paymentStatus: ORDER_PAYMENT_STATUS_PENDING,
    paymentProvider: "QIB",
    paymentResponse: {
      client: redactSensitive(paymentResponse),
      provider: providerPayload ? redactSensitive(providerPayload) : null,
    },
    verificationStatus: ORDER_VERIFICATION_PENDING,
    verificationLastError: failureReason,
    verificationRetryCount: retryCount,
    verificationNextRetryAt: nextRetryAt,
    statusUpdatedAt: fieldValue.serverTimestamp(),
    updatedAt: fieldValue.serverTimestamp(),
  });

  return {
    status: "verification_pending",
    failureReason,
  };
}

exports.syncPublicUserProfile = functionsV1
  .region("us-central1")
  .firestore
  .document(`${USERS_COLLECTION}/{uid}`)
  .onWrite(async (change, context) => {
    const uid = optionalString(context.params?.uid, 128);
    if (!uid) {
      return null;
    }

    const publicRef = db.collection(PUBLIC_USER_PROFILES_COLLECTION).doc(uid);
    const presenceRef = db.collection(USER_PRESENCE_COLLECTION).doc(uid);

    if (!change.after.exists) {
      await Promise.all([
        publicRef.delete().catch(() => null),
        presenceRef.delete().catch(() => null),
      ]);
      return null;
    }

    await publicRef.set(buildPublicUserProfile(uid, change.after.data()));
    return null;
  });

exports.createPendingOrder = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 60,
    enforceAppCheck: ENFORCE_APPCHECK,
  },
  async (request) => {
    const uid = requireAuthUID(request);
    const data = safeObject(request.data);
    const shippingAddressId = requiredString(
      data.shippingAddressId || data.addressId,
      "shippingAddressId",
      128
    );
    const requestedItems = normalizeRequestedOrderItems(data.items);
    const paymentMethodId = normalizeOrderPaymentMethodId(data);
    const paymentProvider = normalizeOrderPaymentProvider(data);
    const paymentStatus =
      paymentMethodId === ORDER_PAYMENT_METHOD_CASH
        ? ORDER_PAYMENT_STATUS_PENDING_COLLECTION
        : ORDER_PAYMENT_STATUS_PENDING;
    const verificationStatus =
      paymentMethodId === ORDER_PAYMENT_METHOD_CASH
        ? ORDER_VERIFICATION_NOT_APPLICABLE
        : ORDER_VERIFICATION_PENDING;
    const paymentSettings = await readCommercePaymentSettings();
    assertAllowedCheckoutPaymentMethod(paymentMethodId, paymentSettings.data);
    const shippingFee = normalizeDeliveryFeeValue(paymentSettings.data.deliveryFee);
    const currency = optionalString(data.currency, 3).toUpperCase() || "QAR";

    const addressRef = db
      .collection(USERS_COLLECTION)
      .doc(uid)
      .collection(USER_ADDRESSES_SUBCOLLECTION)
      .doc(shippingAddressId);
    const addressSnap = await addressRef.get();
    if (!addressSnap.exists) {
      throw new HttpsError("failed-precondition", "Shipping address not found.");
    }

    const shippingAddressSnapshot = buildShippingSnapshotFromAddress(
      uid,
      shippingAddressId,
      addressSnap.data()
    );

    const accessorySnapshots = await Promise.all(
      requestedItems.map(({ itemId }) => db.collection(ACCESSORIES_COLLECTION).doc(itemId).get())
    );

    const items = [];
    let amount = 0;
    for (let index = 0; index < requestedItems.length; index += 1) {
      const requestItem = requestedItems[index];
      const accessorySnap = accessorySnapshots[index];
      if (!accessorySnap.exists) {
        throw new HttpsError("failed-precondition", `Item ${requestItem.itemId} is unavailable.`);
      }

      const orderItem = buildOrderLineItem(
        requestItem.itemId,
        requestItem.quantity,
        accessorySnap.data()
      );
      items.push(orderItem);
      amount += orderItem.price * orderItem.quantity;
    }

    amount = Math.round(amount * 100) / 100;
    const totalAmount = Math.round((amount + shippingFee) * 100) / 100;
    const orderRef = db.collection("Orders").doc();
    const orderId = orderRef.id;
    const orderNumber = buildPublicOrderNumber(orderId);

    await db.runTransaction(async (transaction) => {
      transaction.set(orderRef, {
        orderId,
        orderNumber,
        userId: uid,
        uid,
        status: ORDER_STATUS_PENDING,
        amount,
        shippingFee,
        totalAmount,
        currency,
        paymentMethodId,
        paymentStatus,
        paymentProvider,
        items,
        shippingAddressId,
        shippingAddressSnapshot,
        verificationStatus,
        inventoryDeducted: false,
        inventoryRestocked: false,
        inventoryLowStockItemIDs: [],
        createdAt: fieldValue.serverTimestamp(),
        updatedAt: fieldValue.serverTimestamp(),
        statusUpdatedAt: fieldValue.serverTimestamp(),
      });

      appendOrderEventInTransaction(
        transaction,
        orderRef,
        "order_created",
        ORDER_STATUS_PENDING,
        "customer",
        {
          orderNumber,
          paymentMethodId,
          paymentStatus,
          paymentProvider,
          itemsCount: items.length,
          shippingAddressId,
          shippingFee,
          totalAmount,
        }
      );
    });

    logger.info("Pending order created", {
      orderId,
      orderNumber,
      uid,
      itemsCount: items.length,
      shippingFee,
      totalAmount,
      paymentMethodId,
      paymentStatus,
      paymentProvider,
    });

    const createdAtMillis = Date.now();
    return {
      orderId,
      orderNumber,
      order: {
        orderId,
        orderNumber,
        userId: uid,
        status: ORDER_STATUS_PENDING,
        amount,
        shippingFee,
        totalAmount,
        currency,
        paymentMethodId,
        paymentStatus,
        paymentProvider,
        items,
        shippingAddressId,
        shippingAddressSnapshot,
        verificationStatus,
        createdAtMillis,
        updatedAtMillis: createdAtMillis,
      },
    };
  }
);

exports.createQibSession = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 30,
    enforceAppCheck: ENFORCE_APPCHECK,
  },
  async (request) => {
    const uid = requireAuthUID(request);
    const data = safeObject(request.data);

    const orderId = requiredString(data.orderId, "orderId", 128);
    const amount = positiveAmount(data.amount, "amount");
    const currency = requiredString(data.currency, "currency", 3).toUpperCase();
    const phone = optionalString(data.phone, 32);
    const paymentAttemptId = optionalString(data.paymentAttemptId, 128) || crypto.randomUUID();
    const sessionID = crypto.randomUUID();

    const { orderRef, orderData } = await getOwnedOrder(orderId, uid);
    const paymentSettings = await readCommercePaymentSettings();
    if (isCashOnDeliveryOrder(orderData)) {
      logger.warn("QIB session rejected for a cash on delivery order", {
        orderId,
        uid,
      });
      throw new HttpsError("failed-precondition", "Cash on delivery orders do not require an online payment session.");
    }
    assertAllowedCheckoutPaymentMethod(ORDER_PAYMENT_METHOD_QIB, paymentSettings.data);
    const currentStatus = normalizedStatus(orderData.status);
    if (currentStatus !== "pending") {
      logger.warn("QIB session rejected because the order is no longer pending", {
        orderId,
        uid,
        currentStatus,
      });
      throw new HttpsError("failed-precondition", "Order is no longer pending.");
    }

    const storedAmount = Number(orderData.totalAmount ?? orderData.amount ?? 0);
    if (!Number.isFinite(storedAmount) || storedAmount <= 0) {
      logger.error("QIB session rejected because the stored order total is invalid", {
        orderId,
        uid,
        storedAmount,
      });
      throw new HttpsError("failed-precondition", "Order total is invalid.");
    }
    if (Math.abs(storedAmount - amount) > 0.01) {
      logger.warn("QIB session rejected because the requested amount does not match the stored total", {
        orderId,
        uid,
        requestedAmount: amount,
        storedAmount,
        currency,
      });
      throw new HttpsError("invalid-argument", "Requested amount does not match the order total.");
    }

    const { mode, configSource, gatewayId, secretKey, gatewayIdSuffix, secretFingerprint } = mustHaveGatewayConfig();

    await orderRef.update({
      paymentMethodId: ORDER_PAYMENT_METHOD_QIB,
      paymentStatus: ORDER_PAYMENT_STATUS_PENDING,
      paymentProvider: "QIB",
      paymentAttemptId,
      qibSessionId: sessionID,
      qibSessionCurrency: currency,
      qibSessionPhone: phone || fieldValue.delete(),
      qibSessionCreatedAt: fieldValue.serverTimestamp(),
      verificationStatus: ORDER_VERIFICATION_PENDING,
      updatedAt: fieldValue.serverTimestamp(),
    });

    logger.info("QIB session issued", {
      orderId,
      uid,
      paymentAttemptId,
      sessionID,
      mode,
      configSource,
      legacyClientBootstrap: LEGACY_CLIENT_BOOTSTRAP_ENABLED,
      gatewayIdSuffix,
      secretFingerprint,
    });

    if (!LEGACY_CLIENT_BOOTSTRAP_ENABLED) {
      throw new HttpsError(
        "failed-precondition",
        "QIB secure hosted/tokenized session payload is not configured for this SDK integration."
      );
    }

    return {
      session: {
        mode,
        currency,
        orderId,
        amount,
        phone,
        paymentAttemptId,
        sessionId: sessionID,
        gatewayId,
        secretKey,
        sessionToken: "",
        paymentUrl: "",
      },
    };
  }
);

exports.updateCommercePaymentSettings = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 30,
    enforceAppCheck: ENFORCE_APPCHECK,
  },
  async (request) => {
    const actorUID = await requirePaymentManagerUID(request);
    const payload = safeObject(request.data);
    const existing = await readCommercePaymentSettings();
    const before = buildCommercePaymentSettingsResponse(existing.data);
    const normalized = normalizedCommercePaymentSettings(payload, existing.data);

    if (!(normalized.cashOnDeliveryEnabled || normalized.onlinePaymentEnabled)) {
      throw new HttpsError("invalid-argument", "At least one payment method must remain enabled.");
    }

    const updatePayload = {
      configId: COMMERCE_PAYMENT_SETTINGS_DOC,
      deliveryFee: normalized.deliveryFee,
      cashOnDeliveryEnabled: normalized.cashOnDeliveryEnabled,
      onlinePaymentEnabled: normalized.onlinePaymentEnabled,
      updatedBy: actorUID,
      updatedAt: fieldValue.serverTimestamp(),
      createdAt: existing.exists ? (existing.rawData.createdAt || fieldValue.serverTimestamp()) : fieldValue.serverTimestamp(),
    };

    await commercePaymentSettingsRef().set(updatePayload, { merge: true });

    const afterSnapshot = await readCommercePaymentSettings();
    const after = buildCommercePaymentSettingsResponse(afterSnapshot.data);
    await writeAdminAuditLog({
      actorUID,
      targetUID: COMMERCE_PAYMENT_SETTINGS_DOC,
      action: "payment_settings_updated",
      before,
      after,
      note: "Updated commerce payment settings.",
    });

    logger.info("Commerce payment settings updated", {
      actorUID,
      deliveryFee: after.deliveryFee,
      cashOnDeliveryEnabled: after.cashOnDeliveryEnabled,
      onlinePaymentEnabled: after.onlinePaymentEnabled,
    });

    return {
      settings: after,
    };
  }
);

exports.verifyQibPayment = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 60,
    enforceAppCheck: ENFORCE_APPCHECK,
  },
  async (request) => {
    const uid = requireAuthUID(request);
    const data = safeObject(request.data);

    const orderId = requiredString(data.orderId, "orderId", 128);
    const paymentAttemptId = requiredString(data.paymentAttemptId, "paymentAttemptId", 128);
    const qibSessionId = requiredString(data.qibSessionId, "qibSessionId", 128);
    const paymentResponse = safeObject(data.paymentResponse);
    if (Object.keys(paymentResponse).length === 0) {
      throw new HttpsError("invalid-argument", "paymentResponse is required.");
    }

    const { orderRef, orderData } = await getOwnedOrder(orderId, uid);
    if (isCashOnDeliveryOrder(orderData)) {
      throw new HttpsError("failed-precondition", "Cash on delivery orders cannot be verified through QIB.");
    }
    validateQibAttemptBinding(orderData, paymentAttemptId, qibSessionId);
    const currentStatus = normalizedStatus(orderData.status);
    if (currentStatus === ORDER_STATUS_PAID) {
      return {
        orderId,
        status: ORDER_STATUS_PAID,
        transactionId: optionalString(orderData.transactionId, 256),
      };
    }

    let providerResult = null;
    try {
      providerResult = await verifyWithProviderIfConfigured(orderId, orderData, paymentResponse);
    } catch (error) {
      if (shouldRetryProviderVerification(error)) {
        const pendingResult = await markVerificationPending(orderRef, orderData, paymentResponse, error);
        await appendOrderEvent(orderRef, "payment_verification_pending", ORDER_STATUS_PENDING, "system", {
          reason: pendingResult.failureReason,
        });
        logger.warn("QIB verification marked pending", {
          orderId,
          uid,
          reason: pendingResult.failureReason,
        });
        return {
          orderId,
          status: pendingResult.status,
          transactionId: "",
          normalizedStatus: pendingResult.status,
          failureReason: pendingResult.failureReason,
        };
      }
      logger.error("Provider verification failed", { orderId, error: error?.message || String(error) });
      throw error;
    }

    const verificationResult = resolveVerificationResult(paymentResponse, providerResult);

    const transientStatus = verificationResult.providerStatus || verificationResult.localStatus;
    if (
      verificationResult.finalStatus === ORDER_STATUS_FAILED &&
      isTransientGatewayStatus(transientStatus)
    ) {
      const pendingReason = optionalString(
        verificationResult.failureReason ||
          "Payment verification pending due to temporary QIB gateway connectivity issue.",
        500
      );
      const pendingResult = await markVerificationPending(
        orderRef,
        orderData,
        paymentResponse,
        { message: pendingReason },
        providerResult?.providerPayload || null
      );
      await appendOrderEvent(orderRef, "payment_verification_pending", ORDER_STATUS_PENDING, "system", {
        reason: pendingResult.failureReason,
      });
      logger.warn("QIB payment marked pending after transient provider status", {
        orderId,
        uid,
        providerStatus: transientStatus || "",
        reason: pendingReason,
      });
      return {
        orderId,
        status: pendingResult.status,
        transactionId: "",
        normalizedStatus: transientStatus || pendingResult.status,
        failureReason: pendingResult.failureReason,
      };
    }

    if (
      verificationResult.localStatus &&
      verificationResult.providerStatus &&
      verificationResult.localStatus !== verificationResult.providerStatus
    ) {
      logger.warn("QIB status mismatch between client payload and provider verification", {
        orderId,
        uid,
        localStatus: verificationResult.localStatus,
        providerStatus: verificationResult.providerStatus,
      });
    }

    const finalizedResult = await finalizeOrderVerification(
      orderRef,
      paymentResponse,
      providerResult,
      verificationResult,
      "system"
    );

    logger.info("QIB payment verification completed", {
      orderId,
      uid,
      finalStatus: finalizedResult.status,
      normalizedStatus: verificationResult.providerStatus || "unknown",
      localStatus: verificationResult.localStatus || "",
      providerStatus: verificationResult.providerStatus || "",
      failureReason: finalizedResult.failureReason || "",
      transactionId: finalizedResult.transactionId || "",
    });

    return {
      orderId,
      status: finalizedResult.status,
      transactionId: finalizedResult.transactionId || "",
      normalizedStatus: verificationResult.providerStatus || "unknown",
      failureReason: finalizedResult.failureReason || "",
    };
  }
);

exports.adminTransitionOrderStatus = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 60,
    enforceAppCheck: ENFORCE_APPCHECK,
  },
  async (request) => {
    const actorUID = await requirePaymentManagerUID(request);
    const data = safeObject(request.data);
    const orderId = requiredString(data.orderId, "orderId", 128);
    const action = requiredString(data.action, "action", 64);
    const note = optionalString(data.note, 500);

    if (note.length < 3) {
      throw new HttpsError("invalid-argument", "A note with at least 3 characters is required.");
    }

    const adminSnapshot = await db.collection(USERS_COLLECTION).doc(actorUID).get();
    const actorSummary = buildAdminActorSummary(actorUID, adminSnapshot.data());
    const orderRef = db.collection("Orders").doc(orderId);

    const result = await db.runTransaction(async (transaction) => {
      const orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) {
        throw new HttpsError("not-found", "Order not found.");
      }

      const orderData = safeObject(orderSnapshot.data());
      const currentStatus = normalizedStatus(orderData.status);
      const paymentMethodId = storedOrderPaymentMethodId(orderData);
      const paymentStatus = storedOrderPaymentStatus(orderData);
      const before = buildOrderAuditState(orderData);
      const updatePayload = {
        updatedAt: fieldValue.serverTimestamp(),
      };
      let eventType = "";
      let eventStatus = "";
      let eventSummary = "";
      let eventMetadata = {
        note,
        admin: actorSummary,
      };
      let after = {};

      switch (action) {
        case "order_approve": {
          if (paymentMethodId === ORDER_PAYMENT_METHOD_CASH) {
            throw new HttpsError("failed-precondition", "Cash on delivery orders do not require payment approval.");
          }
          if (!canApprovePaymentOrderStatus(currentStatus)) {
            throw new HttpsError("failed-precondition", "Order can only be approved from pending payment states.");
          }

          Object.assign(updatePayload, {
            status: ORDER_STATUS_PAID,
            statusUpdatedAt: fieldValue.serverTimestamp(),
            paymentMethodId: ORDER_PAYMENT_METHOD_QIB,
            paymentStatus: ORDER_PAYMENT_STATUS_PAID,
            verificationStatus: ORDER_VERIFICATION_VERIFIED,
            paymentProvider: optionalString(orderData.paymentProvider, 128) || "QIB",
            manualApprovalAt: fieldValue.serverTimestamp(),
            manualApprovalBy: actorSummary,
          });

          if (!timestampToDate(orderData.paidAt)) {
            updatePayload.paidAt = fieldValue.serverTimestamp();
          }
          if (optionalString(orderData.failureReason, 500)) {
            updatePayload.failureReason = fieldValue.delete();
          }

          Object.assign(updatePayload, await applyInventoryDeductionInTransaction(transaction, orderData));
          eventType = "payment_verified";
          eventStatus = ORDER_STATUS_PAID;
          eventSummary = "Payment approved by admin";
          eventMetadata = {
            ...eventMetadata,
            manualApproval: true,
          };
          after = {
            status: ORDER_STATUS_PAID,
            workflowStatus: ORDER_STATUS_PAID,
            paymentMethodId: ORDER_PAYMENT_METHOD_QIB,
            paymentStatus: ORDER_PAYMENT_STATUS_PAID,
            inventoryDeducted: true,
          };
          break;
        }

        case "order_mark_processing": {
          if (!canMarkProcessingPaymentOrder(orderData)) {
            throw new HttpsError("failed-precondition", "Order cannot move to processing from its current state.");
          }

          Object.assign(updatePayload, {
            status: ORDER_STATUS_PROCESSING,
            statusUpdatedAt: fieldValue.serverTimestamp(),
          });
          if (paymentMethodId === ORDER_PAYMENT_METHOD_CASH) {
            updatePayload.paymentMethodId = ORDER_PAYMENT_METHOD_CASH;
            updatePayload.paymentProvider = "CASH";
            updatePayload.paymentStatus = ORDER_PAYMENT_STATUS_PENDING_COLLECTION;
            updatePayload.verificationStatus = ORDER_VERIFICATION_NOT_APPLICABLE;
          }
          if (!timestampToDate(orderData.processedAt)) {
            updatePayload.processedAt = fieldValue.serverTimestamp();
          }

          Object.assign(updatePayload, await applyInventoryDeductionInTransaction(transaction, orderData));
          eventType = "fulfillment_processing";
          eventStatus = ORDER_STATUS_PROCESSING;
          eventSummary = "Order moved to processing";
          after = {
            status: ORDER_STATUS_PROCESSING,
            workflowStatus: ORDER_STATUS_PROCESSING,
            paymentMethodId,
            paymentStatus:
              paymentMethodId === ORDER_PAYMENT_METHOD_CASH
                ? ORDER_PAYMENT_STATUS_PENDING_COLLECTION
                : paymentStatus,
            inventoryDeducted: true,
          };
          break;
        }

        case "order_mark_shipped": {
          if (!canMarkShippedPaymentOrderStatus(currentStatus)) {
            throw new HttpsError("failed-precondition", "Order must be in processing before it can be shipped.");
          }

          Object.assign(updatePayload, {
            status: ORDER_STATUS_SHIPPED,
            statusUpdatedAt: fieldValue.serverTimestamp(),
          });
          if (!timestampToDate(orderData.shippedAt)) {
            updatePayload.shippedAt = fieldValue.serverTimestamp();
          }

          eventType = "fulfillment_shipped";
          eventStatus = ORDER_STATUS_SHIPPED;
          eventSummary = "Order marked as shipped";
          after = {
            status: ORDER_STATUS_SHIPPED,
            workflowStatus: ORDER_STATUS_SHIPPED,
            paymentMethodId,
            paymentStatus,
          };
          break;
        }

        case "order_mark_delivered": {
          if (!canMarkDeliveredPaymentOrderStatus(currentStatus)) {
            throw new HttpsError("failed-precondition", "Order must be shipped before it can be delivered.");
          }

          Object.assign(updatePayload, {
            status: ORDER_STATUS_DELIVERED,
            statusUpdatedAt: fieldValue.serverTimestamp(),
          });
          if (!timestampToDate(orderData.deliveredAt)) {
            updatePayload.deliveredAt = fieldValue.serverTimestamp();
          }

          eventType = "fulfillment_delivered";
          eventStatus = ORDER_STATUS_DELIVERED;
          eventSummary = "Order marked as delivered";
          after = {
            status: ORDER_STATUS_DELIVERED,
            workflowStatus: ORDER_STATUS_DELIVERED,
            paymentMethodId,
            paymentStatus,
          };
          break;
        }

        case "order_cancel": {
          if (!canCancelPaymentOrderStatus(currentStatus)) {
            throw new HttpsError("failed-precondition", "Order can no longer be cancelled from its current state.");
          }

          Object.assign(updatePayload, {
            status: ORDER_STATUS_CANCELLED,
            statusUpdatedAt: fieldValue.serverTimestamp(),
            failureReason: "cancelled_by_admin",
            cancelledAt: fieldValue.serverTimestamp(),
            manualCancellationBy: actorSummary,
          });
          if (paymentMethodId === ORDER_PAYMENT_METHOD_CASH && !orderHasCapturedPayment(orderData)) {
            updatePayload.paymentStatus = ORDER_PAYMENT_STATUS_CANCELLED;
          }
          Object.assign(
            updatePayload,
            await applyInventoryRestockInTransaction(transaction, orderData, actorSummary)
          );

          eventType = "order_cancelled";
          eventStatus = ORDER_STATUS_CANCELLED;
          eventSummary = "Order cancelled by admin";
          after = {
            status: ORDER_STATUS_CANCELLED,
            workflowStatus: ORDER_STATUS_CANCELLED,
            paymentMethodId,
            paymentStatus:
              paymentMethodId === ORDER_PAYMENT_METHOD_CASH && !orderHasCapturedPayment(orderData)
                ? ORDER_PAYMENT_STATUS_CANCELLED
                : paymentStatus,
            inventoryRestocked: boolOrDefault(orderData.inventoryDeducted, false),
          };
          break;
        }

        case "order_collect_payment": {
          if (!canCollectCashPayment(orderData)) {
            throw new HttpsError("failed-precondition", "Cash payment can only be collected after the order is delivered.");
          }

          Object.assign(updatePayload, {
            paymentMethodId: ORDER_PAYMENT_METHOD_CASH,
            paymentProvider: "CASH",
            paymentStatus: ORDER_PAYMENT_STATUS_PAID,
            verificationStatus: ORDER_VERIFICATION_NOT_APPLICABLE,
            paymentCollectedAt: fieldValue.serverTimestamp(),
            paymentCollectedBy: actorSummary,
          });
          if (!timestampToDate(orderData.paidAt)) {
            updatePayload.paidAt = fieldValue.serverTimestamp();
          }
          if (optionalString(orderData.failureReason, 500)) {
            updatePayload.failureReason = fieldValue.delete();
          }

          eventType = "payment_collected";
          eventStatus = currentStatus || ORDER_STATUS_DELIVERED;
          eventSummary = "Cash payment collected";
          after = {
            status: currentStatus || ORDER_STATUS_DELIVERED,
            workflowStatus: currentStatus || ORDER_STATUS_DELIVERED,
            paymentMethodId: ORDER_PAYMENT_METHOD_CASH,
            paymentStatus: ORDER_PAYMENT_STATUS_PAID,
          };
          break;
        }

        default:
          throw new HttpsError("invalid-argument", "Unsupported order action.");
      }

      transaction.update(orderRef, updatePayload);
      appendOrderEventInTransaction(
        transaction,
        orderRef,
        eventType,
        eventStatus,
        "admin",
        eventSummary,
        eventMetadata
      );
      appendPaymentAuditLogInTransaction(
        transaction,
        orderRef,
        actorSummary,
        action,
        note,
        before,
        after
      );

      return {
        orderId,
        status: eventStatus,
      };
    });

    logger.info("Admin order transition completed", {
      orderId,
      action,
      actorUID,
      status: result.status,
    });

    return result;
  }
);

exports.notifyOrderStatusChanged = functionsV1
  .region("us-central1")
  .firestore
  .document("Orders/{orderId}")
  .onUpdate(async (change, context) => {
    const beforeData = safeObject(change.before.data());
    const afterData = safeObject(change.after.data());
    const beforeStatus = normalizedStatus(beforeData.status);
    const afterStatus = normalizedStatus(afterData.status);
    const beforePaymentStatus = storedOrderPaymentStatus(beforeData);
    const afterPaymentStatus = storedOrderPaymentStatus(afterData);
    const orderId = optionalString(context.params?.orderId, 128);

    if (!orderId) {
      return null;
    }

    const statusChanged = !!afterStatus && beforeStatus !== afterStatus;
    const paymentStatusChanged = beforePaymentStatus !== afterPaymentStatus;
    if (!statusChanged && !paymentStatusChanged) {
      return null;
    }

    const results = [];
    if (statusChanged) {
      results.push({
        kind: "order_status",
        ...safeObject(await sendOrderStatusNotification(orderId, afterData, afterStatus)),
      });
    }
    if (paymentStatusChanged) {
      results.push({
        kind: "payment_status",
        ...safeObject(await sendOrderPaymentStatusNotification(orderId, afterData, afterPaymentStatus)),
      });
      const adminPaymentNotification = buildAdminPaymentStatusNotificationDefinition(
        orderId,
        afterData,
        afterPaymentStatus
      );
      if (adminPaymentNotification) {
        results.push({
          kind: "admin_payment_status",
          ...safeObject(await sendAdminPaymentNotification(orderId, afterData, adminPaymentNotification)),
        });
      }
    }

    logger.info("Order notification evaluation completed", {
      orderId,
      beforeStatus,
      afterStatus,
      beforePaymentStatus,
      afterPaymentStatus,
      results,
    });
    return results;
  });

exports.notifyAdminOrderCreated = functionsV1
  .region("us-central1")
  .firestore
  .document("Orders/{orderId}")
  .onCreate(async (snapshot, context) => {
    const orderData = safeObject(snapshot.data());
    const orderId = optionalString(context.params?.orderId, 128);
    if (!orderId) {
      return null;
    }

    const definition = buildAdminNewOrderNotificationDefinition(orderId, orderData);
    const result = await sendAdminPaymentNotification(orderId, orderData, definition);
    logger.info("Admin new-order notification processed", {
      orderId,
      paymentStatus: storedOrderPaymentStatus(orderData),
      paymentMethodId: storedOrderPaymentMethodId(orderData),
      result,
    });
    return result;
  });

exports.createOrderSupportRequest = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 30,
    enforceAppCheck: ENFORCE_APPCHECK,
  },
  async (request) => {
    const uid = requireAuthUID(request);
    const data = safeObject(request.data);

    const orderId = requiredString(data.orderId, "orderId", 128);
    const requestType = normalizeRequestType(requiredString(data.requestType, "requestType", 64));
    const reasonCode = normalizedStatus(optionalString(data.reasonCode, 128) || "other");
    const reasonTitle = optionalString(data.reasonTitle, 256);
    const issueCategory = normalizedStatus(optionalString(data.issueCategory, 128) || reasonCode || requestType);
    const subject = optionalString(data.subject, 256);
    const notes = optionalString(data.notes, 2000);
    const attachments = sanitizeAttachments(data.attachments);

    const { orderRef, orderData } = await getOwnedOrder(orderId, uid);
    const eligibility = evaluateSupportEligibility(orderData, requestType, new Date());
    if (!eligibility.eligible) {
      throw new HttpsError("failed-precondition", eligibility.message);
    }

    const itemSnapshots = buildSelectedItemSnapshots(orderData, data.itemIDs, requestType, reasonCode);
    const dedupeKey = makeSupportRequestDedupeKey(requestType, reasonCode, itemSnapshots);
    const openQuery = orderRef
      .collection(ORDER_REQUESTS_COLLECTION)
      .where("userId", "==", uid)
      .where("type", "==", requestType)
      .where("status", "in", openRequestStatuses());

    return db.runTransaction(async (transaction) => {
      const openSnapshot = await transaction.get(openQuery);
      for (const doc of openSnapshot.docs) {
        const existing = safeObject(doc.data());
        if (optionalString(existing.dedupeKey, 64) === dedupeKey) {
          return {
            orderId,
            requestId: doc.id,
            status: optionalString(existing.status, 64) || ORDER_REQUEST_PENDING_REVIEW,
            finalResolution:
              optionalString(existing.finalResolution, 64) || ORDER_REQUEST_PENDING_REVIEW,
            deduplicated: true,
          };
        }
      }

      if (!openSnapshot.empty) {
        throw new HttpsError(
          "failed-precondition",
          "An open request of this type already exists for this order."
        );
      }

      const requestRef = orderRef.collection(ORDER_REQUESTS_COLLECTION).doc();
      const requestStatus =
        requestType === ORDER_REQUEST_TYPE_CANCEL
          ? ORDER_REQUEST_COMPLETED
          : ORDER_REQUEST_PENDING_REVIEW;
      const finalResolution =
        requestType === ORDER_REQUEST_TYPE_CANCEL
          ? ORDER_REQUEST_CANCELLED
          : ORDER_REQUEST_PENDING_REVIEW;

      transaction.set(requestRef, {
        requestId: requestRef.id,
        orderId,
        userId: uid,
        type: requestType,
        reasonCode,
        reasonTitle,
        issueCategory,
        subject: subject || requestType,
        notes,
        attachments,
        itemIDs: itemSnapshots.map((item) => item.itemId),
        itemSnapshots,
        status: requestStatus,
        finalResolution,
        dedupeKey,
        adminReview: {},
        resolution: {},
        createdAt: fieldValue.serverTimestamp(),
        updatedAt: fieldValue.serverTimestamp(),
        submittedAt: fieldValue.serverTimestamp(),
      });

      appendRequestEventInTransaction(
        transaction,
        requestRef,
        "request_submitted",
        requestStatus,
        "customer",
        { requestType, reasonCode }
      );

      if (requestType === ORDER_REQUEST_TYPE_CANCEL) {
        transaction.update(orderRef, {
          status: ORDER_REQUEST_CANCELLED,
          failureReason: "cancelled_by_user",
          cancelledAt: fieldValue.serverTimestamp(),
          statusUpdatedAt: fieldValue.serverTimestamp(),
          updatedAt: fieldValue.serverTimestamp(),
        });
        appendOrderEventInTransaction(
          transaction,
          orderRef,
          "order_cancelled",
          ORDER_REQUEST_CANCELLED,
          "customer",
          { requestId: requestRef.id, reasonCode }
        );
        appendRequestEventInTransaction(
          transaction,
          requestRef,
          "request_status_updated",
          ORDER_REQUEST_COMPLETED,
          "system",
          { finalResolution: ORDER_REQUEST_CANCELLED }
        );
      } else {
        appendOrderEventInTransaction(
          transaction,
          orderRef,
          "customer_request_created",
          requestType,
          "customer",
          { requestId: requestRef.id, requestType, reasonCode }
        );
      }

      return {
        orderId,
        requestId: requestRef.id,
        status: requestStatus,
        finalResolution,
        deduplicated: false,
      };
    });
  }
);

exports.prepareOrderForRetry = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 30,
    enforceAppCheck: ENFORCE_APPCHECK,
  },
  async (request) => {
    const uid = requireAuthUID(request);
    const data = safeObject(request.data);

    const orderId = requiredString(data.orderId, "orderId", 128);
    const shippingAddressId = requiredString(data.shippingAddressId, "shippingAddressId", 128);
    const shippingAddressSnapshot = safeObject(data.shippingAddressSnapshot);

    if (!hasValidShippingSnapshot(shippingAddressSnapshot, uid, shippingAddressId)) {
      throw new HttpsError("invalid-argument", "shippingAddressSnapshot is invalid.");
    }

    const { orderRef, orderData } = await getOwnedOrder(orderId, uid);
    if (isCashOnDeliveryOrder(orderData)) {
      throw new HttpsError("failed-precondition", "Cash on delivery orders do not require online payment retry.");
    }
    const currentStatus = normalizedStatus(orderData.status);
    if (currentStatus === ORDER_STATUS_PAID) {
      throw new HttpsError("failed-precondition", "Paid orders cannot be reset.");
    }
    if (![ORDER_STATUS_FAILED, ORDER_STATUS_PENDING].includes(currentStatus)) {
      throw new HttpsError("failed-precondition", "Order is not eligible for retry.");
    }

    const updatePayload = {
      status: ORDER_STATUS_PENDING,
      paymentMethodId: ORDER_PAYMENT_METHOD_QIB,
      paymentStatus: ORDER_PAYMENT_STATUS_PENDING,
      paymentProvider: "QIB",
      shippingAddressId,
      shippingAddressSnapshot,
      failureReason: fieldValue.delete(),
      transactionId: fieldValue.delete(),
      paymentResponse: fieldValue.delete(),
      verifiedAt: fieldValue.delete(),
      verificationStatus: ORDER_VERIFICATION_PENDING,
      verificationLastError: fieldValue.delete(),
      verificationNextRetryAt: fieldValue.delete(),
      verificationRetryCount: fieldValue.delete(),
      qibSessionId: fieldValue.delete(),
      paymentAttemptId: fieldValue.delete(),
      qibSessionCurrency: fieldValue.delete(),
      qibSessionPhone: fieldValue.delete(),
      qibSessionCreatedAt: fieldValue.delete(),
      statusUpdatedAt: fieldValue.serverTimestamp(),
      updatedAt: fieldValue.serverTimestamp(),
    };

    await orderRef.update(updatePayload);
    await appendOrderEvent(orderRef, "payment_retry_prepared", ORDER_STATUS_PENDING, "customer", {});

    logger.info("Order prepared for retry", {
      orderId,
      uid,
      previousStatus: currentStatus,
    });

    return {
      orderId,
      status: ORDER_STATUS_PENDING,
      verificationStatus: ORDER_VERIFICATION_PENDING,
    };
  }
);

// U3: debugSimulateQibPaymentSuccess removed — production security risk

exports.reconcileQibPendingVerifications = onSchedule(
  {
    region: "us-central1",
    schedule: "every 5 minutes",
    timeZone: "UTC",
    timeoutSeconds: 300,
  },
  async () => {
    const nowMillis = Date.now();
    const snapshot = await db
      .collection("Orders")
      .where("verificationStatus", "==", ORDER_VERIFICATION_PENDING)
      .limit(50)
      .get();

    let scanned = 0;
    let retried = 0;
    let finalized = 0;
    let stillPending = 0;

    for (const doc of snapshot.docs) {
      scanned += 1;
      const orderRef = doc.ref;
      const orderData = safeObject(doc.data());
      const orderId = optionalString(orderData.orderId, 128) || doc.id;

      const nextRetryRaw = orderData.verificationNextRetryAt;
      const nextRetryMillis =
        nextRetryRaw && typeof nextRetryRaw.toMillis === "function" ? nextRetryRaw.toMillis() : 0;
      if (nextRetryMillis > nowMillis) {
        continue;
      }

      if (!orderHasActiveQibAttempt(orderData)) {
        stillPending += 1;
        continue;
      }

      const paymentResponse = extractStoredClientPaymentResponse(orderData);
      if (Object.keys(paymentResponse).length === 0) {
        const attemptAgeMillis = nowMillis - qibAttemptAnchorMillis(orderData);
        if (attemptAgeMillis < QIB_CLIENT_RESPONSE_GRACE_MS) {
          stillPending += 1;
          continue;
        }

        await orderRef.update({
          verificationStatus: ORDER_VERIFICATION_FAILED,
          verificationLastError: "Missing client payment response payload.",
          status: ORDER_STATUS_FAILED,
          qibSessionId: fieldValue.delete(),
          paymentAttemptId: fieldValue.delete(),
          qibSessionCurrency: fieldValue.delete(),
          qibSessionPhone: fieldValue.delete(),
          qibSessionCreatedAt: fieldValue.delete(),
          verificationNextRetryAt: fieldValue.delete(),
          verificationRetryCount: fieldValue.delete(),
          statusUpdatedAt: fieldValue.serverTimestamp(),
          updatedAt: fieldValue.serverTimestamp(),
        });
        await appendOrderEvent(orderRef, "payment_failed", ORDER_STATUS_FAILED, "system", {
          reason: "Missing client payment response payload.",
        });
        finalized += 1;
        continue;
      }

      let providerResult = null;
      try {
        providerResult = await verifyWithProviderIfConfigured(orderId, orderData, paymentResponse);
      } catch (error) {
        if (shouldRetryProviderVerification(error)) {
          retried += 1;
          const pendingResult = await markVerificationPending(orderRef, orderData, paymentResponse, error);
          logger.warn("Pending verification retry deferred", {
            orderId,
            reason: pendingResult.failureReason,
          });
          stillPending += 1;
          continue;
        }

        await orderRef.update({
          status: ORDER_STATUS_FAILED,
          verificationStatus: ORDER_VERIFICATION_FAILED,
          verificationLastError: optionalString(error?.message, 500) || "Verification failed.",
          statusUpdatedAt: fieldValue.serverTimestamp(),
          updatedAt: fieldValue.serverTimestamp(),
        });
        await appendOrderEvent(orderRef, "payment_failed", ORDER_STATUS_FAILED, "system", {
          reason: optionalString(error?.message, 500) || "Verification failed.",
        });
        finalized += 1;
        continue;
      }

      const verificationResult = resolveVerificationResult(paymentResponse, providerResult);
      await finalizeOrderVerification(orderRef, paymentResponse, providerResult, verificationResult, "system");
      finalized += 1;
    }

    logger.info("QIB pending verification reconciliation run completed", {
      scanned,
      retried,
      finalized,
      stillPending,
    });
  }
);

exports.runPaymentInstrumentScrub = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 540,
  },
  async (request) => {
    await requirePrivilegedUID(request);

    let scanned = 0;
    let updated = 0;
    let removedFields = 0;
    let lastDoc = null;
    const pageSize = 200;

    while (true) {
      let query = db.collectionGroup("paymentInstruments").orderBy("__name__").limit(pageSize);
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const page = await query.get();
      if (page.empty) break;

      const batch = db.batch();
      let hasBatchWrites = false;

      for (const doc of page.docs) {
        scanned += 1;
        const data = safeObject(doc.data());
        const original = scrubPaymentMap(data.originalData);
        const meta = scrubPaymentMap(data.metaData);

        if (original.removedKeys.length === 0 && meta.removedKeys.length === 0) {
          continue;
        }

        removedFields += original.removedKeys.length + meta.removedKeys.length;
        updated += 1;
        hasBatchWrites = true;
        batch.update(doc.ref, {
          originalData: original.sanitized,
          metaData: meta.sanitized,
          updatedAt: fieldValue.serverTimestamp(),
        });
      }

      if (hasBatchWrites) {
        await batch.commit();
      }

      lastDoc = page.docs[page.docs.length - 1];
      if (page.size < pageSize) break;
    }

    logger.info("Payment instrument scrub completed", {
      scanned,
      updated,
      removedFields,
    });

    return {
      scanned,
      updated,
      removedFields,
    };
  }
);

exports.auditPaymentInstrumentCompliance = onSchedule(
  {
    region: "us-central1",
    schedule: "every day 03:00",
    timeZone: "UTC",
    timeoutSeconds: 300,
  },
  async () => {
    let scanned = 0;
    let nonCompliant = 0;
    let lastDoc = null;
    const pageSize = 250;

    while (true) {
      let query = db.collectionGroup("paymentInstruments").orderBy("__name__").limit(pageSize);
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const page = await query.get();
      if (page.empty) break;

      for (const doc of page.docs) {
        scanned += 1;
        const data = safeObject(doc.data());
        if (hasDisallowedPaymentKey(data.originalData) || hasDisallowedPaymentKey(data.metaData)) {
          nonCompliant += 1;
        }
      }

      lastDoc = page.docs[page.docs.length - 1];
      if (page.size < pageSize) break;
    }

    if (nonCompliant > 0) {
      logger.warn("Payment instrument compliance audit detected non-compliant docs", {
        scanned,
        nonCompliant,
      });
    } else {
      logger.info("Payment instrument compliance audit passed", {
        scanned,
        nonCompliant,
      });
    }
  }
);
