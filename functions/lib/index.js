"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.expireStaleArenaRooms = exports.redeemReferralCode = exports.deleteMyAccount = exports.equipOSkin = exports.equipXSkin = exports.equipAvatar = exports.purchaseOSkin = exports.purchaseXSkin = exports.purchaseAvatar = exports.verifyGooglePlayPurchase = exports.verifyAndroidPurchase = exports.grantMatchReward = void 0;
const functions = require("firebase-functions");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const googleapis_1 = require("googleapis");
const crypto = require("crypto");
admin.initializeApp();
const db = admin.firestore();
// ============================================================
// CONSTANTS — server-authoritative, never trust client values
// ============================================================
const EXPECTED_PACKAGE_NAME = "com.xoarena.neonclash";
/**
 * Coins granted per consumable IAP product. Only defined server-side — the
 * client never sends a coin amount. Values include the bonus advertised on
 * the shop card so the UI label and the credit are guaranteed to match.
 *
 * CATALOG_SYNC: 2026-05-24 — XO Arena shop redesign.
 */
const PRODUCT_COINS_MAP = {
    "xo_arena_2000": 2000,
    "xo_arena_4000": 4000,
    "xo_arena_6000": 6000,
    "xo_arena_8000": 8000,
    "xo_arena_10000": 10000,
    "xo_arena_20000": 20000,
    "xo_arena_30000": 30000,
    "xo_arena_50000": 52500,
    "xo_arena_100000": 107500,
    "xo_arena_200000": 220000, // 200,000 + 20,000 bonus
};
/**
 * Non-consumable products. Each entry describes a one-time entitlement that
 * is acknowledged with Google Play but never consumed, so the user's "owned"
 * status persists across reinstalls and restored purchases.
 */
const NON_CONSUMABLE_ENTITLEMENTS = {
    xo_avatar_premium: {
        entitlementId: "premium_avatar_7",
        inventoryAvatarId: "premium_avatar_7",
    },
    xo_avatar_premium1: {
        entitlementId: "premium_avatar_10",
        inventoryAvatarId: "premium_avatar_10",
    },
};
/**
 * Coins rewarded per match result.
 *
 * IMPORTANT: As of the 2026-05 wallet hardening, this map is reference-only.
 * The Cloud Function NO LONGER writes Wallet.coins — the Flutter client is
 * the single source of truth for the coin balance and uses
 * `GameRewardService` to compute per-game rewards locally (which then sync
 * to Firestore via the normal Wallet write path in LocalStore.updateCoins).
 *
 * Kept here so that the audit trail (transaction sub-docs) records the
 * server's view of what the reward "would" have been if the CF were
 * authoritative again. The numbers are no longer added to Wallet.coins.
 */
const MATCH_REWARDS = {
    win: 15,
    loss: 0,
    draw: 5,
};
// ============================================================
// HELPERS
// ============================================================
/** Throws HttpsError if caller is not authenticated. Returns verified uid. */
function requireAuth(context) {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "You must be signed in to perform this action.");
    }
    return context.auth.uid;
}
/**
 * Enforce Firebase App Check. Throws if the request did not include a valid
 * App Check token. Call this at the top of every sensitive callable function.
 *
 * NOTE: In Firebase Functions v1 (firebase-functions ^4.x), App Check is
 * enforced manually via context.app. The v2 `enforceAppCheck: true` option
 * is not available in v1.
 */
function requireAppCheck(context) {
    if (context.app === undefined) {
        throw new functions.https.HttpsError("failed-precondition", "This function must be called from an App Check verified app.");
    }
}
/**
 * Initialize Google Play Developer API client.
 * Reads service account key from Firebase Secret: GOOGLE_SERVICE_ACCOUNT_KEY
 */
function getAndroidPublisher() {
    const serviceAccountKey = process.env.GOOGLE_SERVICE_ACCOUNT_KEY;
    if (!serviceAccountKey) {
        throw new functions.https.HttpsError("internal", "Google Play API not configured. Set GOOGLE_SERVICE_ACCOUNT_KEY secret.");
    }
    const sa = JSON.parse(serviceAccountKey);
    const auth = new googleapis_1.google.auth.JWT(sa.client_email, undefined, sa.private_key, ["https://www.googleapis.com/auth/androidpublisher"]);
    return googleapis_1.google.androidpublisher({ version: "v3", auth });
}
/** Write an audit log entry. Best-effort — errors are swallowed. */
async function writeAuditLog(uid, action, details, severity = "info") {
    try {
        await db.collection("audit_logs").add({
            uid,
            action,
            details,
            severity,
            source: "cloud_function",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (e) {
        console.warn(`[auditLog] Failed to write audit log for action=${action}, uid=${uid}:`, e);
    }
}
/** Recursively batch-delete all documents in a Firestore collection path. */
async function deleteCollection(collectionPath) {
    const snapshot = await db.collection(collectionPath).limit(300).get();
    if (snapshot.empty)
        return;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    if (snapshot.docs.length === 300) {
        await deleteCollection(collectionPath);
    }
}
// ============================================================
// FUNCTION 1: grantMatchReward
// ============================================================
/**
 * Grant coins for a match result. Idempotent via match_rewards/{uid}_{matchId}.
 *
 * Input:  { matchId: string, result: "win" | "loss" | "draw" }
 * Output: { ok: true, coinsAdded: number, newBalance: number }
 */
exports.grantMatchReward = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    requireAppCheck(context);
    const uid = requireAuth(context);
    const { matchId, result } = data;
    if (!matchId || typeof matchId !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "matchId is required.");
    }
    if (!result || !["win", "loss", "draw"].includes(result)) {
        throw new functions.https.HttpsError("invalid-argument", "result must be 'win', 'loss', or 'draw'.");
    }
    const coinsToAdd = (_a = MATCH_REWARDS[result]) !== null && _a !== void 0 ? _a : 0;
    const rewardDocId = `${uid}_${matchId}`;
    const rewardRef = db.collection("match_rewards").doc(rewardDocId);
    const userRef = db.collection("users").doc(uid);
    // Idempotency: if already processed, return current balance
    const rewardDoc = await rewardRef.get();
    if (rewardDoc.exists) {
        const userDoc = await userRef.get();
        const currentBalance = ((_d = (_c = (_b = userDoc.data()) === null || _b === void 0 ? void 0 : _b.Wallet) === null || _c === void 0 ? void 0 : _c.coins) !== null && _d !== void 0 ? _d : 0);
        console.log(`[grantMatchReward] Already processed: uid=${uid}, matchId=${matchId}`);
        return { ok: true, coinsAdded: 0, newBalance: currentBalance, message: "Already processed" };
    }
    // STATS-ONLY: the client (LocalStore.updateCoins) is the single source of
    // truth for Wallet.coins. The previous implementation also wrote
    // Wallet.coins here, which double-counted every match reward (once locally
    // + once by the CF), causing the historic "+15 ghost / revert after pull"
    // bug. We keep the idempotency record, Stats increments, and audit
    // transaction sub-doc — but Wallet.coins is left untouched.
    let walletCoins = 0;
    await db.runTransaction(async (tx) => {
        var _a, _b, _c;
        const userDoc = await tx.get(userRef);
        const wallet = ((_b = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.Wallet) !== null && _b !== void 0 ? _b : {});
        walletCoins = ((_c = wallet.coins) !== null && _c !== void 0 ? _c : 0);
        // Build atomic update — Stats only.
        const update = {
            "Stats.gamesPlayed": admin.firestore.FieldValue.increment(1),
        };
        if (result === "win") {
            update["Stats.wins"] = admin.firestore.FieldValue.increment(1);
        }
        else if (result === "loss") {
            update["Stats.losses"] = admin.firestore.FieldValue.increment(1);
        }
        else {
            update["Stats.draws"] = admin.firestore.FieldValue.increment(1);
        }
        tx.update(userRef, update);
        // Idempotency record. coinsAdded is recorded as 0 because the CF did
        // not change Wallet.coins — the audit trail must reflect that.
        tx.set(rewardRef, {
            uid,
            matchId,
            result,
            coinsAdded: 0,
            clientAuthoritativeCoins: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Stats audit transaction record (amount=0, type=match_stats).
        const txDocRef = userRef.collection("transactions").doc();
        tx.set(txDocRef, {
            type: "match_stats",
            amount: 0,
            balanceBefore: walletCoins,
            balanceAfter: walletCoins,
            matchId,
            result,
            itemId: null,
            itemName: null,
            productId: null,
            purchaseTokenHash: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            source: "cloud_function",
        });
        // Suppress unused var warnings.
        void coinsToAdd;
    });
    console.log(`[grantMatchReward] STATS-ONLY uid=${uid}, matchId=${matchId}, result=${result}, walletCoins=${walletCoins} (coin grant skipped — client authoritative)`);
    writeAuditLog(uid, "match_stats", { matchId, result, coinsAdded: 0, statsOnly: true }).catch(() => { });
    return { ok: true, coinsAdded: 0, newBalance: walletCoins, statsOnly: true };
});
// ============================================================
// FUNCTION 2 & 3: verifyAndroidPurchase + verifyGooglePlayPurchase (alias)
// ============================================================
/** Core purchase verification logic. Shared by both export names. */
async function _verifyAndGrantCoins(uid, productId, purchaseToken, packageName, orderId) {
    var _a, _b, _c, _d;
    if (!productId || !purchaseToken || !packageName) {
        throw new functions.https.HttpsError("invalid-argument", "productId, purchaseToken, and packageName are required.");
    }
    // Security: verify package name server-side
    if (packageName !== EXPECTED_PACKAGE_NAME) {
        console.warn(`[verifyPurchase] Invalid package name: ${packageName} from uid=${uid}`);
        throw new functions.https.HttpsError("invalid-argument", `Invalid package name: ${packageName}`);
    }
    // Resolve the product: either a coin pack (consumable) or a one-time
    // entitlement (non-consumable). Coin amount is taken from the server map
    // only — the client never sends it.
    const coinsToAdd = PRODUCT_COINS_MAP[productId];
    const entitlement = NON_CONSUMABLE_ENTITLEMENTS[productId];
    if (!coinsToAdd && !entitlement) {
        throw new functions.https.HttpsError("invalid-argument", `Unknown product ID: ${productId}`);
    }
    // Verify with Google Play Developer API
    let purchase;
    try {
        const androidPublisher = getAndroidPublisher();
        const response = await androidPublisher.purchases.products.get({
            packageName,
            productId,
            token: purchaseToken,
        });
        purchase = response.data;
    }
    catch (e) {
        if (e.code === 410) {
            throw new functions.https.HttpsError("invalid-argument", "Purchase token invalid or expired.");
        }
        if (e.code === 404) {
            throw new functions.https.HttpsError("not-found", "Purchase not found.");
        }
        if (e instanceof functions.https.HttpsError)
            throw e;
        console.error(`[verifyPurchase] Google Play API error for uid=${uid}:`, e);
        throw new functions.https.HttpsError("internal", e.message || "Google Play verification failed.");
    }
    if (purchase.purchaseState !== 0) {
        throw new functions.https.HttpsError("failed-precondition", `Purchase not valid. State: ${purchase.purchaseState}`);
    }
    // Idempotency: hash the token so we store a fixed-length safe key
    const tokenHash = crypto.createHash("sha256").update(purchaseToken).digest("hex");
    const iapRef = db.collection("iap_transactions").doc(tokenHash);
    const iapDoc = await iapRef.get();
    if (iapDoc.exists && ((_a = iapDoc.data()) === null || _a === void 0 ? void 0 : _a.processedAt)) {
        const userDoc = await db.collection("users").doc(uid).get();
        const currentBalance = ((_d = (_c = (_b = userDoc.data()) === null || _b === void 0 ? void 0 : _b.Wallet) === null || _c === void 0 ? void 0 : _c.coins) !== null && _d !== void 0 ? _d : 0);
        console.log(`[verifyPurchase] Already processed: uid=${uid}, productId=${productId}`);
        return {
            ok: true,
            coinsAdded: 0,
            newBalance: currentBalance,
            consumed: purchase.consumptionState === 1,
            restored: !!entitlement,
            productType: entitlement ? "avatar" : "coins",
            avatarId: entitlement === null || entitlement === void 0 ? void 0 : entitlement.entitlementId,
            message: "Purchase already processed",
        };
    }
    // Run Firestore transaction to grant the product atomically.
    const userRef = db.collection("users").doc(uid);
    let newBalance = 0;
    await db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f, _g;
        const userDoc = await tx.get(userRef);
        const wallet = ((_b = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.Wallet) !== null && _b !== void 0 ? _b : {});
        const currentCoins = ((_c = wallet.coins) !== null && _c !== void 0 ? _c : 0);
        const currentLifetime = ((_d = wallet.lifetimeEarned) !== null && _d !== void 0 ? _d : 0);
        if (entitlement) {
            // ── Non-consumable entitlement (premium avatar) ────────────────────
            const inventory = ((_f = (_e = userDoc.data()) === null || _e === void 0 ? void 0 : _e.Inventory) !== null && _f !== void 0 ? _f : {});
            const ownedAvatars = ((_g = inventory.avatars) !== null && _g !== void 0 ? _g : []);
            const alreadyOwned = ownedAvatars.includes(entitlement.inventoryAvatarId);
            const nextAvatars = alreadyOwned
                ? ownedAvatars
                : [...ownedAvatars, entitlement.inventoryAvatarId];
            const updates = {
                "Inventory.avatars": nextAvatars,
                [`Entitlements.${entitlement.entitlementId}`]: {
                    productId,
                    status: "active",
                    orderId: orderId !== null && orderId !== void 0 ? orderId : null,
                    purchaseTokenHash: tokenHash,
                    grantedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
            };
            tx.update(userRef, updates);
            tx.set(iapRef, {
                uid,
                productId,
                productType: "avatar",
                entitlementId: entitlement.entitlementId,
                avatarId: entitlement.inventoryAvatarId,
                coinsAdded: 0,
                purchaseToken,
                purchaseTokenHash: tokenHash,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
                consumed: false,
                orderId: orderId !== null && orderId !== void 0 ? orderId : null,
            });
            const txDocRef = userRef.collection("transactions").doc();
            tx.set(txDocRef, {
                type: "avatar_purchase",
                amount: 0,
                balanceBefore: currentCoins,
                balanceAfter: currentCoins,
                productId,
                purchaseTokenHash: tokenHash,
                itemId: entitlement.inventoryAvatarId,
                itemName: "Premium Arena Avatar",
                matchId: null,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                source: "cloud_function",
            });
            newBalance = currentCoins; // unchanged
            return;
        }
        // ── Consumable coin pack ───────────────────────────────────────────
        newBalance = currentCoins + coinsToAdd;
        tx.update(userRef, {
            "Wallet.coins": newBalance,
            "Wallet.lifetimeEarned": currentLifetime + coinsToAdd,
        });
        tx.set(iapRef, {
            uid,
            productId,
            productType: "coins",
            coinsAdded: coinsToAdd,
            purchaseToken,
            purchaseTokenHash: tokenHash,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            consumed: false,
            orderId: orderId !== null && orderId !== void 0 ? orderId : null,
        });
        const txDocRef = userRef.collection("transactions").doc();
        tx.set(txDocRef, {
            type: "iap_purchase",
            amount: coinsToAdd,
            balanceBefore: currentCoins,
            balanceAfter: newBalance,
            productId,
            purchaseTokenHash: tokenHash,
            itemId: null,
            itemName: null,
            matchId: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            source: "cloud_function",
        });
    });
    if (entitlement) {
        console.log(`[verifyPurchase] Granted entitlement ${entitlement.entitlementId} to uid=${uid} for ${productId}.`);
    }
    else {
        console.log(`[verifyPurchase] Granted ${coinsToAdd} coins to uid=${uid} for ${productId}. New balance: ${newBalance}`);
    }
    // Post-grant Google Play housekeeping.
    let consumed = false;
    try {
        const androidPublisher = getAndroidPublisher();
        if (entitlement) {
            // Non-consumable: acknowledge only — NEVER consume.
            if (purchase.acknowledgementState === 0) {
                await androidPublisher.purchases.products.acknowledge({
                    packageName,
                    productId,
                    token: purchaseToken,
                    requestBody: { developerPayload: "" },
                });
            }
            consumed = false;
        }
        else {
            // Consumable: consume so the user can buy it again.
            if (purchase.consumptionState === 0) {
                await androidPublisher.purchases.products.consume({
                    packageName,
                    productId,
                    token: purchaseToken,
                });
            }
            consumed = true;
        }
        await iapRef.update({ consumed });
    }
    catch (consumeError) {
        if (consumeError.code === 410) {
            consumed = !entitlement;
            await iapRef.update({ consumed }).catch(() => { });
        }
        else {
            console.error(`[verifyPurchase] Consume/acknowledge error (non-fatal) for uid=${uid}:`, consumeError);
        }
    }
    writeAuditLog(uid, entitlement ? "avatar_iap" : "iap_purchase", entitlement
        ? { productId, entitlementId: entitlement.entitlementId, tokenHash }
        : { productId, coinsAdded: coinsToAdd, tokenHash }).catch(() => { });
    return {
        ok: true,
        coinsAdded: entitlement ? 0 : coinsToAdd,
        newBalance,
        consumed,
        productType: entitlement ? "avatar" : "coins",
        avatarId: entitlement === null || entitlement === void 0 ? void 0 : entitlement.entitlementId,
    };
}
/**
 * Verify a Google Play purchase and grant coins. (New canonical name)
 *
 * Input:  { productId, purchaseToken, packageName, orderId? }
 * Output: { ok, coinsAdded, newBalance, consumed, message? }
 */
exports.verifyAndroidPurchase = functions
    .runWith({ secrets: ["GOOGLE_SERVICE_ACCOUNT_KEY"] })
    .https.onCall(async (data, context) => {
    requireAppCheck(context);
    const uid = requireAuth(context);
    const { productId, purchaseToken, packageName, orderId } = data;
    return _verifyAndGrantCoins(uid, productId, purchaseToken, packageName, orderId);
});
/**
 * Backward-compatible alias for verifyAndroidPurchase.
 * Keep this export so existing Flutter calls to 'verifyGooglePlayPurchase' continue working.
 */
exports.verifyGooglePlayPurchase = functions
    .runWith({ secrets: ["GOOGLE_SERVICE_ACCOUNT_KEY"] })
    .https.onCall(async (data, context) => {
    requireAppCheck(context);
    const uid = requireAuth(context);
    const { productId, purchaseToken, packageName, orderId } = data;
    return _verifyAndGrantCoins(uid, productId, purchaseToken, packageName, orderId);
});
// ============================================================
// FUNCTION 4: purchaseAvatar
// ============================================================
/**
 * Purchase an avatar from the catalog using coins.
 *
 * Input:  { itemId: string }
 * Output: { ok: true, newBalance, avatars: string[] }
 */
exports.purchaseAvatar = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    requireAppCheck(context);
    const uid = requireAuth(context);
    const { itemId } = data;
    if (!itemId)
        throw new functions.https.HttpsError("invalid-argument", "itemId is required.");
    const itemDoc = await db.collection("avatars").doc(itemId).get();
    if (!itemDoc.exists || ((_a = itemDoc.data()) === null || _a === void 0 ? void 0 : _a.enabled) !== true) {
        throw new functions.https.HttpsError("not-found", "Avatar not found or not available.");
    }
    const price = ((_c = (_b = itemDoc.data()) === null || _b === void 0 ? void 0 : _b.price) !== null && _c !== void 0 ? _c : 0);
    const itemName = ((_e = (_d = itemDoc.data()) === null || _d === void 0 ? void 0 : _d.name) !== null && _e !== void 0 ? _e : itemId);
    const userRef = db.collection("users").doc(uid);
    let newBalance = 0;
    let newAvatars = [];
    await db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f, _g;
        const userDoc = await tx.get(userRef);
        const wallet = ((_b = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.Wallet) !== null && _b !== void 0 ? _b : {});
        const inventory = ((_d = (_c = userDoc.data()) === null || _c === void 0 ? void 0 : _c.Inventory) !== null && _d !== void 0 ? _d : {});
        const currentCoins = ((_e = wallet.coins) !== null && _e !== void 0 ? _e : 0);
        const currentSpent = ((_f = wallet.lifetimeSpent) !== null && _f !== void 0 ? _f : 0);
        const ownedAvatars = ((_g = inventory.avatars) !== null && _g !== void 0 ? _g : []);
        if (ownedAvatars.includes(itemId)) {
            throw new functions.https.HttpsError("already-exists", "You already own this avatar.");
        }
        if (currentCoins < price) {
            throw new functions.https.HttpsError("failed-precondition", "Not enough coins.");
        }
        newBalance = currentCoins - price;
        newAvatars = [...ownedAvatars, itemId];
        tx.update(userRef, {
            "Wallet.coins": newBalance,
            "Wallet.lifetimeSpent": currentSpent + price,
            "Inventory.avatars": newAvatars,
        });
        const txDocRef = userRef.collection("transactions").doc();
        tx.set(txDocRef, {
            type: "avatar_purchase",
            amount: -price,
            balanceBefore: currentCoins,
            balanceAfter: newBalance,
            itemId,
            itemName,
            productId: null,
            purchaseTokenHash: null,
            matchId: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            source: "cloud_function",
        });
    });
    console.log(`[purchaseAvatar] uid=${uid} bought avatar=${itemId} for ${price} coins. New balance: ${newBalance}`);
    writeAuditLog(uid, "avatar_purchase", { itemId, price }).catch(() => { });
    return { ok: true, newBalance, avatars: newAvatars };
});
// ============================================================
// FUNCTION 5: purchaseXSkin
// ============================================================
/**
 * Purchase an X skin from the catalog using coins.
 *
 * Input:  { itemId: string }
 * Output: { ok: true, newBalance, xSkins: string[] }
 */
exports.purchaseXSkin = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    requireAppCheck(context);
    const uid = requireAuth(context);
    const { itemId } = data;
    if (!itemId)
        throw new functions.https.HttpsError("invalid-argument", "itemId is required.");
    const itemDoc = await db.collection("x_skins").doc(itemId).get();
    if (!itemDoc.exists || ((_a = itemDoc.data()) === null || _a === void 0 ? void 0 : _a.enabled) !== true) {
        throw new functions.https.HttpsError("not-found", "X skin not found or not available.");
    }
    const price = ((_c = (_b = itemDoc.data()) === null || _b === void 0 ? void 0 : _b.price) !== null && _c !== void 0 ? _c : 0);
    const itemName = ((_e = (_d = itemDoc.data()) === null || _d === void 0 ? void 0 : _d.name) !== null && _e !== void 0 ? _e : itemId);
    const userRef = db.collection("users").doc(uid);
    let newBalance = 0;
    let newSkins = [];
    await db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f, _g;
        const userDoc = await tx.get(userRef);
        const wallet = ((_b = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.Wallet) !== null && _b !== void 0 ? _b : {});
        const inventory = ((_d = (_c = userDoc.data()) === null || _c === void 0 ? void 0 : _c.Inventory) !== null && _d !== void 0 ? _d : {});
        const currentCoins = ((_e = wallet.coins) !== null && _e !== void 0 ? _e : 0);
        const currentSpent = ((_f = wallet.lifetimeSpent) !== null && _f !== void 0 ? _f : 0);
        const ownedSkins = ((_g = inventory.xSkins) !== null && _g !== void 0 ? _g : []);
        if (ownedSkins.includes(itemId)) {
            throw new functions.https.HttpsError("already-exists", "You already own this X skin.");
        }
        if (currentCoins < price) {
            throw new functions.https.HttpsError("failed-precondition", "Not enough coins.");
        }
        newBalance = currentCoins - price;
        newSkins = [...ownedSkins, itemId];
        tx.update(userRef, {
            "Wallet.coins": newBalance,
            "Wallet.lifetimeSpent": currentSpent + price,
            "Inventory.xSkins": newSkins,
        });
        const txDocRef = userRef.collection("transactions").doc();
        tx.set(txDocRef, {
            type: "x_skin_purchase",
            amount: -price,
            balanceBefore: currentCoins,
            balanceAfter: newBalance,
            itemId,
            itemName,
            productId: null,
            purchaseTokenHash: null,
            matchId: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            source: "cloud_function",
        });
    });
    console.log(`[purchaseXSkin] uid=${uid} bought xSkin=${itemId} for ${price} coins.`);
    writeAuditLog(uid, "x_skin_purchase", { itemId, price }).catch(() => { });
    return { ok: true, newBalance, xSkins: newSkins };
});
// ============================================================
// FUNCTION 6: purchaseOSkin
// ============================================================
/**
 * Purchase an O skin from the catalog using coins.
 *
 * Input:  { itemId: string }
 * Output: { ok: true, newBalance, oSkins: string[] }
 */
exports.purchaseOSkin = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    requireAppCheck(context);
    const uid = requireAuth(context);
    const { itemId } = data;
    if (!itemId)
        throw new functions.https.HttpsError("invalid-argument", "itemId is required.");
    const itemDoc = await db.collection("o_skins").doc(itemId).get();
    if (!itemDoc.exists || ((_a = itemDoc.data()) === null || _a === void 0 ? void 0 : _a.enabled) !== true) {
        throw new functions.https.HttpsError("not-found", "O skin not found or not available.");
    }
    const price = ((_c = (_b = itemDoc.data()) === null || _b === void 0 ? void 0 : _b.price) !== null && _c !== void 0 ? _c : 0);
    const itemName = ((_e = (_d = itemDoc.data()) === null || _d === void 0 ? void 0 : _d.name) !== null && _e !== void 0 ? _e : itemId);
    const userRef = db.collection("users").doc(uid);
    let newBalance = 0;
    let newSkins = [];
    await db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f, _g;
        const userDoc = await tx.get(userRef);
        const wallet = ((_b = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.Wallet) !== null && _b !== void 0 ? _b : {});
        const inventory = ((_d = (_c = userDoc.data()) === null || _c === void 0 ? void 0 : _c.Inventory) !== null && _d !== void 0 ? _d : {});
        const currentCoins = ((_e = wallet.coins) !== null && _e !== void 0 ? _e : 0);
        const currentSpent = ((_f = wallet.lifetimeSpent) !== null && _f !== void 0 ? _f : 0);
        const ownedSkins = ((_g = inventory.oSkins) !== null && _g !== void 0 ? _g : []);
        if (ownedSkins.includes(itemId)) {
            throw new functions.https.HttpsError("already-exists", "You already own this O skin.");
        }
        if (currentCoins < price) {
            throw new functions.https.HttpsError("failed-precondition", "Not enough coins.");
        }
        newBalance = currentCoins - price;
        newSkins = [...ownedSkins, itemId];
        tx.update(userRef, {
            "Wallet.coins": newBalance,
            "Wallet.lifetimeSpent": currentSpent + price,
            "Inventory.oSkins": newSkins,
        });
        const txDocRef = userRef.collection("transactions").doc();
        tx.set(txDocRef, {
            type: "o_skin_purchase",
            amount: -price,
            balanceBefore: currentCoins,
            balanceAfter: newBalance,
            itemId,
            itemName,
            productId: null,
            purchaseTokenHash: null,
            matchId: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            source: "cloud_function",
        });
    });
    console.log(`[purchaseOSkin] uid=${uid} bought oSkin=${itemId} for ${price} coins.`);
    writeAuditLog(uid, "o_skin_purchase", { itemId, price }).catch(() => { });
    return { ok: true, newBalance, oSkins: newSkins };
});
// ============================================================
// FUNCTION 7: equipAvatar
// ============================================================
/**
 * Equip an avatar the user already owns.
 *
 * Input:  { itemId: string }
 * Output: { ok: true }
 */
exports.equipAvatar = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    requireAppCheck(context);
    const uid = requireAuth(context);
    const { itemId } = data;
    if (!itemId)
        throw new functions.https.HttpsError("invalid-argument", "itemId is required.");
    const userDoc = await db.collection("users").doc(uid).get();
    const ownedAvatars = ((_c = (_b = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.Inventory) === null || _b === void 0 ? void 0 : _b.avatars) !== null && _c !== void 0 ? _c : []);
    if (!ownedAvatars.includes(itemId)) {
        throw new functions.https.HttpsError("permission-denied", "You do not own this avatar.");
    }
    await db.collection("users").doc(uid).update({ "Inventory.equippedAvatar": itemId });
    writeAuditLog(uid, "equip_avatar", { itemId }).catch(() => { });
    return { ok: true };
});
// ============================================================
// FUNCTION 8: equipXSkin
// ============================================================
/**
 * Equip an X skin the user already owns.
 *
 * Input:  { itemId: string }
 * Output: { ok: true }
 */
exports.equipXSkin = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    requireAppCheck(context);
    const uid = requireAuth(context);
    const { itemId } = data;
    if (!itemId)
        throw new functions.https.HttpsError("invalid-argument", "itemId is required.");
    const userDoc = await db.collection("users").doc(uid).get();
    const ownedSkins = ((_c = (_b = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.Inventory) === null || _b === void 0 ? void 0 : _b.xSkins) !== null && _c !== void 0 ? _c : []);
    if (!ownedSkins.includes(itemId)) {
        throw new functions.https.HttpsError("permission-denied", "You do not own this X skin.");
    }
    await db.collection("users").doc(uid).update({ "Inventory.equippedXSkin": itemId });
    writeAuditLog(uid, "equip_x_skin", { itemId }).catch(() => { });
    return { ok: true };
});
// ============================================================
// FUNCTION 9: equipOSkin
// ============================================================
/**
 * Equip an O skin the user already owns.
 *
 * Input:  { itemId: string }
 * Output: { ok: true }
 */
exports.equipOSkin = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    requireAppCheck(context);
    const uid = requireAuth(context);
    const { itemId } = data;
    if (!itemId)
        throw new functions.https.HttpsError("invalid-argument", "itemId is required.");
    const userDoc = await db.collection("users").doc(uid).get();
    const ownedSkins = ((_c = (_b = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.Inventory) === null || _b === void 0 ? void 0 : _b.oSkins) !== null && _c !== void 0 ? _c : []);
    if (!ownedSkins.includes(itemId)) {
        throw new functions.https.HttpsError("permission-denied", "You do not own this O skin.");
    }
    await db.collection("users").doc(uid).update({ "Inventory.equippedOSkin": itemId });
    writeAuditLog(uid, "equip_o_skin", { itemId }).catch(() => { });
    return { ok: true };
});
// ============================================================
// FUNCTION 10: deleteMyAccount
// ============================================================
/**
 * Securely delete the authenticated user's account and all associated data.
 * Uses Admin SDK — bypasses Firestore security rules.
 *
 * Steps:
 *  1. Write deleted_accounts/{uid} record (before deletion)
 *  2. Write audit log
 *  3. Delete users/{uid}/transactions subcollection
 *  4. Delete users/{uid}/purchase_counts subcollection
 *  5. Delete users/{uid} main document
 *  6. Delete deletion_feedback/{uid} if exists
 *  7. Delete deletion_requests/{uid} if exists
 *  8. Delete Firebase Auth user (last step)
 *
 * Output: { ok: true }
 */
exports.deleteMyAccount = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e, _f;
    requireAppCheck(context);
    const uid = requireAuth(context);
    console.log(`[deleteMyAccount] Starting deletion for uid=${uid}`);
    try {
        // Read user data for audit record
        const userDoc = await db.collection("users").doc(uid).get();
        const userData = (_a = userDoc.data()) !== null && _a !== void 0 ? _a : {};
        const email = (_b = context.auth.token.email) !== null && _b !== void 0 ? _b : null;
        const finalBalance = ((_d = (_c = userData.Wallet) === null || _c === void 0 ? void 0 : _c.coins) !== null && _d !== void 0 ? _d : 0);
        const totalGames = ((_f = (_e = userData.Stats) === null || _e === void 0 ? void 0 : _e.gamesPlayed) !== null && _f !== void 0 ? _f : 0);
        // Step 1: Write deleted_accounts record BEFORE deleting anything
        await db.collection("deleted_accounts").doc(uid).set({
            uid,
            email,
            finalBalance,
            totalGames,
            deletedAt: admin.firestore.FieldValue.serverTimestamp(),
            source: "user_request",
        });
        // Step 2: Write audit log
        await writeAuditLog(uid, "account_deleted", { email, finalBalance, totalGames }, "critical");
        // Step 3 & 4: Delete subcollections
        await deleteCollection(`users/${uid}/transactions`);
        await deleteCollection(`users/${uid}/purchase_counts`);
        // Step 5–7: Batch-delete main documents
        const batch = db.batch();
        batch.delete(db.collection("users").doc(uid));
        const feedbackDoc = await db.collection("deletion_feedback").doc(uid).get();
        if (feedbackDoc.exists)
            batch.delete(feedbackDoc.ref);
        const requestDoc = await db.collection("deletion_requests").doc(uid).get();
        if (requestDoc.exists)
            batch.delete(requestDoc.ref);
        await batch.commit();
        // Step 8: Delete Firebase Auth user (do this LAST so the function stays callable)
        await admin.auth().deleteUser(uid);
        console.log(`[deleteMyAccount] Deletion complete for uid=${uid}`);
        return { ok: true };
    }
    catch (e) {
        console.error(`[deleteMyAccount] Error for uid=${uid}:`, e);
        if (e instanceof functions.https.HttpsError)
            throw e;
        throw new functions.https.HttpsError("internal", "Account deletion failed: " + (e.message || "Unknown error"));
    }
});
// ============================================================
// FUNCTION: redeemReferralCode
// ============================================================
//
// Atomically credits the invitee (+100) and the referrer (+100), writes
// idempotent wallet_ledger records for both sides, creates
// /referrals/{inviteeUid}, and increments the referrer's
// Referral.validReferralCount + Referral.totalReferralCoinsEarned.
//
// Client cannot do this directly because it would require writing a
// different user's document; rules forbid that. The CF runs as admin.
//
// Idempotent: re-running with the same caller returns already-exists.
const REFERRAL_REWARD = 100;
const REFERRAL_MAX_FRIENDS = 10;
exports.redeemReferralCode = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    requireAppCheck(context);
    const callerUid = requireAuth(context);
    const { code } = (data !== null && data !== void 0 ? data : {});
    if (!code || typeof code !== "string" || !/^[0-9]{9}$/.test(code)) {
        throw new functions.https.HttpsError("invalid-argument", "Referral code must be exactly 9 digits.");
    }
    const codeRef = db.collection("referral_codes").doc(code);
    const referralRef = db.collection("referrals").doc(callerUid);
    const inviteeRef = db.collection("users").doc(callerUid);
    // Pre-transaction reads to fail fast with a useful error before paying for
    // a transaction.
    const codeSnap = await codeRef.get();
    if (!codeSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Referral code not found.");
    }
    const referrerUid = ((_b = (_a = codeSnap.data()) === null || _a === void 0 ? void 0 : _a.uid) !== null && _b !== void 0 ? _b : "");
    if (!referrerUid) {
        throw new functions.https.HttpsError("not-found", "Referral code is invalid.");
    }
    if (referrerUid === callerUid) {
        throw new functions.https.HttpsError("failed-precondition", "You cannot redeem your own invite code.");
    }
    const referrerRef = db.collection("users").doc(referrerUid);
    const inviteeLedgerId = `ref_${callerUid}_invitee`;
    const referrerLedgerId = `ref_${callerUid}_referrer`;
    const inviteeLedgerRef = inviteeRef.collection("wallet_ledger").doc(inviteeLedgerId);
    const referrerLedgerRef = referrerRef.collection("wallet_ledger").doc(referrerLedgerId);
    let newReferrerCount = 0;
    let inviteeAfter = 0;
    let referrerAfter = 0;
    try {
        await db.runTransaction(async (tx) => {
            var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m;
            const existingReferral = await tx.get(referralRef);
            if (existingReferral.exists) {
                throw new functions.https.HttpsError("already-exists", "This invite code has already been redeemed.");
            }
            const [inviteeSnap, referrerSnap, inviteeLedgerSnap, referrerLedgerSnap] = await Promise.all([
                tx.get(inviteeRef),
                tx.get(referrerRef),
                tx.get(inviteeLedgerRef),
                tx.get(referrerLedgerRef),
            ]);
            if (inviteeLedgerSnap.exists || referrerLedgerSnap.exists) {
                throw new functions.https.HttpsError("already-exists", "This referral reward has already been applied.");
            }
            const inviteeReferral = ((_b = (_a = inviteeSnap.data()) === null || _a === void 0 ? void 0 : _a.Referral) !== null && _b !== void 0 ? _b : {});
            if (inviteeReferral.referralUsed === true) {
                throw new functions.https.HttpsError("already-exists", "You have already redeemed an invite code.");
            }
            const referrerReferral = ((_d = (_c = referrerSnap.data()) === null || _c === void 0 ? void 0 : _c.Referral) !== null && _d !== void 0 ? _d : {});
            const currentCount = (_e = referrerReferral.validReferralCount) !== null && _e !== void 0 ? _e : 0;
            if (currentCount >= REFERRAL_MAX_FRIENDS) {
                throw new functions.https.HttpsError("resource-exhausted", "Referrer has reached the maximum number of invited friends.");
            }
            const inviteeBefore = ((_h = (_g = (_f = inviteeSnap.data()) === null || _f === void 0 ? void 0 : _f.Wallet) === null || _g === void 0 ? void 0 : _g.coins) !== null && _h !== void 0 ? _h : 0);
            const referrerBefore = ((_l = (_k = (_j = referrerSnap.data()) === null || _j === void 0 ? void 0 : _j.Wallet) === null || _k === void 0 ? void 0 : _k.coins) !== null && _l !== void 0 ? _l : 0);
            inviteeAfter = inviteeBefore + REFERRAL_REWARD;
            referrerAfter = referrerBefore + REFERRAL_REWARD;
            newReferrerCount = currentCount + 1;
            const newTotal = ((_m = referrerReferral.totalReferralCoinsEarned) !== null && _m !== void 0 ? _m : 0) +
                REFERRAL_REWARD;
            const now = admin.firestore.FieldValue.serverTimestamp();
            tx.set(referralRef, {
                inviteeUid: callerUid,
                referrerUid,
                code,
                rewardCoins: REFERRAL_REWARD,
                createdAt: now,
            });
            tx.set(inviteeRef, {
                Wallet: { coins: inviteeAfter },
                Referral: {
                    referredBy: referrerUid,
                    referralUsed: true,
                    updatedAt: now,
                },
            }, { merge: true });
            tx.set(referrerRef, {
                Wallet: { coins: referrerAfter },
                Referral: {
                    validReferralCount: newReferrerCount,
                    totalReferralCoinsEarned: newTotal,
                    updatedAt: now,
                },
            }, { merge: true });
            tx.set(inviteeLedgerRef, {
                uid: callerUid,
                type: "referral_invitee_reward",
                source: "redeemReferralCode",
                delta: REFERRAL_REWARD,
                before: inviteeBefore,
                after: inviteeAfter,
                transactionId: inviteeLedgerId,
                code,
                referrerUid,
                createdAt: now,
            });
            tx.set(referrerLedgerRef, {
                uid: referrerUid,
                type: "referral_referrer_reward",
                source: "redeemReferralCode",
                delta: REFERRAL_REWARD,
                before: referrerBefore,
                after: referrerAfter,
                transactionId: referrerLedgerId,
                code,
                inviteeUid: callerUid,
                createdAt: now,
            });
        });
    }
    catch (e) {
        if (e instanceof functions.https.HttpsError)
            throw e;
        console.error(`[redeemReferralCode] tx failed uid=${callerUid} code=${code}:`, e);
        throw new functions.https.HttpsError("internal", "Referral redemption failed: " + (e.message || "Unknown error"));
    }
    writeAuditLog(callerUid, "referral_redeemed", { code, referrerUid, reward: REFERRAL_REWARD, referrerCount: newReferrerCount }).catch(() => { });
    console.log(`[redeemReferralCode] uid=${callerUid} referrer=${referrerUid} code=${code} count=${newReferrerCount}`);
    console.log(`[REFERRAL_REWARD] granted referrer=${referrerUid} invited=${callerUid} coins=${REFERRAL_REWARD}`);
    // Best-effort FCM push to the referrer. Wrapped so a push failure never
    // fails the redeem (coins were already granted in the transaction above).
    try {
        const [referrerSnap2, inviteeSnap2] = await Promise.all([
            referrerRef.get(),
            inviteeRef.get(),
        ]);
        const tokensMap = ((_c = referrerSnap2.data()) === null || _c === void 0 ? void 0 : _c.fcmTokens) || {};
        const tokens = Object.keys(tokensMap);
        const friendName = ((_e = (_d = inviteeSnap2.data()) === null || _d === void 0 ? void 0 : _d.Profile) === null || _e === void 0 ? void 0 : _e.name) || "A friend";
        console.log(`[FCM] referral_push to=${referrerUid} tokenExists=${tokens.length > 0}`);
        if (tokens.length > 0) {
            const resp = await admin.messaging().sendEachForMulticast({
                tokens,
                notification: {
                    title: "Your friend joined XO Arena!",
                    body: `You earned ${REFERRAL_REWARD} coins from ${friendName}`,
                },
                data: { type: "referral_reward" },
                android: { priority: "high" },
            });
            // Prune tokens that are no longer registered.
            const stale = [];
            resp.responses.forEach((r, i) => {
                var _a;
                const codeStr = ((_a = r.error) === null || _a === void 0 ? void 0 : _a.code) || "";
                if (!r.success &&
                    (codeStr === "messaging/registration-token-not-registered" ||
                        codeStr === "messaging/invalid-registration-token")) {
                    stale.push(tokens[i]);
                }
            });
            if (stale.length > 0) {
                const update = {};
                stale.forEach((t) => {
                    update[`fcmTokens.${t}`] = admin.firestore.FieldValue.delete();
                });
                await referrerRef.update(update).catch(() => undefined);
            }
            console.log(`[FCM] referral_push_sent to=${referrerUid} tokenExists=true ` +
                `success=${resp.successCount} failure=${resp.failureCount}`);
        }
    }
    catch (err) {
        console.error(`[FCM] referral_push_failed to=${referrerUid} error=${String(err)}`);
    }
    return {
        ok: true,
        inviteeReward: REFERRAL_REWARD,
        referrerReward: REFERRAL_REWARD,
        inviteeBalance: inviteeAfter,
        referrerCount: newReferrerCount,
    };
});
// ============================================================
// FUNCTION: expireStaleArenaRooms (scheduled janitor)
// ============================================================
//
// Server-side safety net for the Arena friend-room lifecycle. Runs every 5
// minutes and guarantees that no room can stay alive forever, regardless of
// who closed their app. It mirrors the client-side opportunistic cleanup in
// ArenaResumeFlow.settlePendingActiveRoom so the two converge on the same
// terminal state.
//
// Two timeout models (must match the Flutter constants in arena_repo.dart):
//   • Empty *waiting* rooms (host alone) — 10-minute creation TTL (expiresAt).
//     Nothing is at stake, so they are removed outright.
//   • *Occupied* rooms (guest joined or match started) — 20-minute inactivity
//     TTL measured from max(updatedAt, either presence lastSeenMs). These are
//     marked `expired` (NOT removed) with a `cleanupAfter` grace window so each
//     player can refund their own locked bet via the idempotent
//     ArenaBetService.refundOwnBet on their next app open; the node is removed
//     on a later pass once `cleanupAfter` has elapsed.
//
// WALLET-NEUTRAL: this function never touches Wallet.coins or wallet_ledger.
// All bet refunds/payouts remain client-driven through the existing 4-layer
// idempotent guards (matches the kEnableServerCoinRewards=false policy).
/** RTDB instance URL — pinned to the project's EU-West region. */
const ARENA_RTDB_URL = "https://xo-arenaneon-clash-default-rtdb.europe-west1.firebasedatabase.app";
/** Empty-waiting-room creation TTL. Matches kArenaRoomTtlMs (10 min). */
const ARENA_ROOM_TTL_MS = 10 * 60 * 1000;
/** Occupied-room inactivity TTL. Matches kArenaInactivityTtlMs (20 min). */
const ARENA_INACTIVITY_TTL_MS = 20 * 60 * 1000;
/** Terminal room statuses that should never be re-expired. */
const ARENA_TERMINAL_STATUSES = new Set([
    "finished",
    "expired",
    "cancelled",
    "abandoned",
]);
function toInt(value) {
    if (typeof value === "number")
        return value;
    if (typeof value === "string") {
        const n = parseInt(value, 10);
        return Number.isNaN(n) ? 0 : n;
    }
    return 0;
}
/** Latest activity ms on a room: max(updatedAt, each presence lastSeenMs). */
function arenaLastActivityMs(room) {
    let last = toInt(room.updatedAt);
    const presence = room.playersPresence;
    if (presence && typeof presence === "object") {
        for (const key of Object.keys(presence)) {
            const entry = presence[key];
            if (entry && typeof entry === "object") {
                const ls = toInt(entry.lastSeenMs);
                if (ls > last)
                    last = ls;
            }
        }
    }
    return last;
}
exports.expireStaleArenaRooms = (0, scheduler_1.onSchedule)({ schedule: "every 5 minutes", region: "europe-west1" }, async () => {
    var _a, _b;
    const rtdb = admin.app().database(ARENA_RTDB_URL);
    const roomsRef = rtdb.ref("rooms");
    const snap = await roomsRef.get();
    if (!snap.exists()) {
        console.log("[ROOM_TIMEOUT] janitor: no rooms");
        return;
    }
    const now = Date.now();
    const rooms = snap.val();
    let removed = 0;
    let expired = 0;
    for (const code of Object.keys(rooms)) {
        const room = rooms[code];
        // Corrupt / non-map node — drop it.
        if (!room || typeof room !== "object") {
            await roomsRef.child(code).remove().catch(() => undefined);
            removed++;
            continue;
        }
        const status = String((_a = room.status) !== null && _a !== void 0 ? _a : "waiting");
        const guestUid = String((_b = room.guestUid) !== null && _b !== void 0 ? _b : "");
        const occupied = guestUid.length > 0 || status !== "waiting";
        // ── Already-terminal rooms: remove once their grace window has passed. ──
        // A `cleanupAfter` stamp is the explicit grace signal; if one is missing
        // (orphaned terminal room), fall back to the inactivity TTL measured from
        // last activity so nothing can linger forever.
        if (ARENA_TERMINAL_STATUSES.has(status)) {
            const cleanupAfter = toInt(room.cleanupAfter);
            const graceElapsed = cleanupAfter > 0
                ? now > cleanupAfter
                : now - arenaLastActivityMs(room) > ARENA_INACTIVITY_TTL_MS;
            if (graceElapsed) {
                await roomsRef.child(code).remove().catch(() => undefined);
                removed++;
            }
            continue;
        }
        // ── Empty waiting room: 10-minute creation TTL → remove outright. ──────
        if (!occupied) {
            const expiresAt = toInt(room.expiresAt);
            const past = (expiresAt > 0 && now > expiresAt) ||
                now - toInt(room.createdAt) > ARENA_ROOM_TTL_MS;
            if (past) {
                await roomsRef.child(code).remove().catch(() => undefined);
                removed++;
            }
            continue;
        }
        // ── Occupied room: 20-minute inactivity TTL → mark expired + grace. ────
        const inactiveFor = now - arenaLastActivityMs(room);
        if (inactiveFor > ARENA_INACTIVITY_TTL_MS) {
            // Betting rooms get a long claim window so an offline player never
            // loses an unrefunded locked entry; non-bet rooms only need a short
            // grace so both clients can observe the expiry.
            const betLocked = room.betEnabled === true && room.coinsLocked === true;
            const grace = betLocked ? 24 * 60 * 60 * 1000 : 2 * 60 * 1000;
            await roomsRef
                .child(code)
                .update({
                status: "expired",
                result: "expired",
                finalResult: "expired",
                cleanupAfter: now + grace,
                updatedAt: admin.database.ServerValue.TIMESTAMP,
            })
                .catch(() => undefined);
            expired++;
            console.log(`[ROOM_TIMEOUT] expired room=${code} reason=20min_inactive ` +
                `inactiveFor=${Math.round(inactiveFor / 1000)}s betLocked=${betLocked}`);
        }
    }
    console.log(`[ROOM_TIMEOUT] janitor done scanned=${Object.keys(rooms).length} ` +
        `expired=${expired} removed=${removed}`);
});
//# sourceMappingURL=index.js.map