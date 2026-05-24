import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { google } from "googleapis";
import * as crypto from "crypto";

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
const PRODUCT_COINS_MAP: Record<string, number> = {
  "xo_arena_2000": 2000,
  "xo_arena_4000": 4000,
  "xo_arena_6000": 6000,
  "xo_arena_8000": 8000,
  "xo_arena_10000": 10000,
  "xo_arena_20000": 22000,   // 20,000 + 2,000 bonus
  "xo_arena_30000": 33000,   // 30,000 + 3,000 bonus
  "xo_arena_50000": 57500,   // 50,000 + 7,500 bonus
  "xo_arena_100000": 120000, // 100,000 + 20,000 bonus
  "xo_arena_200000": 240000, // 200,000 + 40,000 bonus
};

/**
 * Non-consumable products. Each entry describes a one-time entitlement that
 * is acknowledged with Google Play but never consumed, so the user's "owned"
 * status persists across reinstalls and restored purchases.
 */
const NON_CONSUMABLE_ENTITLEMENTS: Record<
  string,
  { entitlementId: string; inventoryAvatarId: string }
> = {
  xo_avatar_premium: {
    entitlementId: "premium_avatar_7",
    inventoryAvatarId: "premium_avatar_7",
  },
  xo_avatar_premium_apex: {
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
const MATCH_REWARDS: Record<string, number> = {
  win: 15,
  loss: 0,
  draw: 5,
};

// ============================================================
// HELPERS
// ============================================================

/** Throws HttpsError if caller is not authenticated. Returns verified uid. */
function requireAuth(context: functions.https.CallableContext): string {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to perform this action."
    );
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
function requireAppCheck(context: functions.https.CallableContext): void {
  if (context.app === undefined) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "This function must be called from an App Check verified app."
    );
  }
}

/**
 * Initialize Google Play Developer API client.
 * Reads service account key from Firebase Secret: GOOGLE_SERVICE_ACCOUNT_KEY
 */
function getAndroidPublisher() {
  const serviceAccountKey = process.env.GOOGLE_SERVICE_ACCOUNT_KEY;
  if (!serviceAccountKey) {
    throw new functions.https.HttpsError(
      "internal",
      "Google Play API not configured. Set GOOGLE_SERVICE_ACCOUNT_KEY secret."
    );
  }
  const sa = JSON.parse(serviceAccountKey);
  const auth = new google.auth.JWT(
    sa.client_email,
    undefined,
    sa.private_key,
    ["https://www.googleapis.com/auth/androidpublisher"]
  );
  return google.androidpublisher({ version: "v3", auth });
}

/** Write an audit log entry. Best-effort — errors are swallowed. */
async function writeAuditLog(
  uid: string,
  action: string,
  details: Record<string, unknown>,
  severity: "info" | "warning" | "critical" = "info"
): Promise<void> {
  try {
    await db.collection("audit_logs").add({
      uid,
      action,
      details,
      severity,
      source: "cloud_function",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.warn(`[auditLog] Failed to write audit log for action=${action}, uid=${uid}:`, e);
  }
}

/** Recursively batch-delete all documents in a Firestore collection path. */
async function deleteCollection(collectionPath: string): Promise<void> {
  const snapshot = await db.collection(collectionPath).limit(300).get();
  if (snapshot.empty) return;
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
export const grantMatchReward = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const { matchId, result } = data as { matchId?: string; result?: string };

  if (!matchId || typeof matchId !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "matchId is required.");
  }
  if (!result || !["win", "loss", "draw"].includes(result)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "result must be 'win', 'loss', or 'draw'."
    );
  }

  const coinsToAdd = MATCH_REWARDS[result] ?? 0;
  const rewardDocId = `${uid}_${matchId}`;
  const rewardRef = db.collection("match_rewards").doc(rewardDocId);
  const userRef = db.collection("users").doc(uid);

  // Idempotency: if already processed, return current balance
  const rewardDoc = await rewardRef.get();
  if (rewardDoc.exists) {
    const userDoc = await userRef.get();
    const currentBalance = (userDoc.data()?.Wallet?.coins ?? 0) as number;
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
    const userDoc = await tx.get(userRef);
    const wallet = (userDoc.data()?.Wallet ?? {}) as Record<string, number>;
    walletCoins = (wallet.coins ?? 0) as number;

    // Build atomic update — Stats only.
    const update: admin.firestore.UpdateData<admin.firestore.DocumentData> = {
      "Stats.gamesPlayed": admin.firestore.FieldValue.increment(1),
    };

    if (result === "win") {
      update["Stats.wins"] = admin.firestore.FieldValue.increment(1);
    } else if (result === "loss") {
      update["Stats.losses"] = admin.firestore.FieldValue.increment(1);
    } else {
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

  console.log(
    `[grantMatchReward] STATS-ONLY uid=${uid}, matchId=${matchId}, result=${result}, walletCoins=${walletCoins} (coin grant skipped — client authoritative)`
  );
  writeAuditLog(uid, "match_stats", { matchId, result, coinsAdded: 0, statsOnly: true }).catch(() => {});

  return { ok: true, coinsAdded: 0, newBalance: walletCoins, statsOnly: true };
});

// ============================================================
// FUNCTION 2 & 3: verifyAndroidPurchase + verifyGooglePlayPurchase (alias)
// ============================================================

/** Core purchase verification logic. Shared by both export names. */
async function _verifyAndGrantCoins(
  uid: string,
  productId: string,
  purchaseToken: string,
  packageName: string,
  orderId?: string
): Promise<Record<string, unknown>> {
  if (!productId || !purchaseToken || !packageName) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "productId, purchaseToken, and packageName are required."
    );
  }

  // Security: verify package name server-side
  if (packageName !== EXPECTED_PACKAGE_NAME) {
    console.warn(`[verifyPurchase] Invalid package name: ${packageName} from uid=${uid}`);
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Invalid package name: ${packageName}`
    );
  }

  // Resolve the product: either a coin pack (consumable) or a one-time
  // entitlement (non-consumable). Coin amount is taken from the server map
  // only — the client never sends it.
  const coinsToAdd = PRODUCT_COINS_MAP[productId];
  const entitlement = NON_CONSUMABLE_ENTITLEMENTS[productId];
  if (!coinsToAdd && !entitlement) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Unknown product ID: ${productId}`
    );
  }

  // Verify with Google Play Developer API
  let purchase: { purchaseState?: number | null; consumptionState?: number | null; acknowledgementState?: number | null };
  try {
    const androidPublisher = getAndroidPublisher();
    const response = await androidPublisher.purchases.products.get({
      packageName,
      productId,
      token: purchaseToken,
    });
    purchase = response.data;
  } catch (e: any) {
    if (e.code === 410) {
      throw new functions.https.HttpsError("invalid-argument", "Purchase token invalid or expired.");
    }
    if (e.code === 404) {
      throw new functions.https.HttpsError("not-found", "Purchase not found.");
    }
    if (e instanceof functions.https.HttpsError) throw e;
    console.error(`[verifyPurchase] Google Play API error for uid=${uid}:`, e);
    throw new functions.https.HttpsError("internal", e.message || "Google Play verification failed.");
  }

  if (purchase.purchaseState !== 0) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      `Purchase not valid. State: ${purchase.purchaseState}`
    );
  }

  // Idempotency: hash the token so we store a fixed-length safe key
  const tokenHash = crypto.createHash("sha256").update(purchaseToken).digest("hex");
  const iapRef = db.collection("iap_transactions").doc(tokenHash);
  const iapDoc = await iapRef.get();

  if (iapDoc.exists && iapDoc.data()?.processedAt) {
    const userDoc = await db.collection("users").doc(uid).get();
    const currentBalance = (userDoc.data()?.Wallet?.coins ?? 0) as number;
    console.log(`[verifyPurchase] Already processed: uid=${uid}, productId=${productId}`);
    return {
      ok: true,
      coinsAdded: 0,
      newBalance: currentBalance,
      consumed: purchase.consumptionState === 1,
      restored: !!entitlement,
      productType: entitlement ? "avatar" : "coins",
      avatarId: entitlement?.entitlementId,
      message: "Purchase already processed",
    };
  }

  // Run Firestore transaction to grant the product atomically.
  const userRef = db.collection("users").doc(uid);
  let newBalance = 0;

  await db.runTransaction(async (tx) => {
    const userDoc = await tx.get(userRef);
    const wallet = (userDoc.data()?.Wallet ?? {}) as Record<string, number>;
    const currentCoins = (wallet.coins ?? 0) as number;
    const currentLifetime = (wallet.lifetimeEarned ?? 0) as number;

    if (entitlement) {
      // ── Non-consumable entitlement (premium avatar) ────────────────────
      const inventory = (userDoc.data()?.Inventory ?? {}) as Record<string, unknown>;
      const ownedAvatars = ((inventory.avatars ?? []) as string[]);
      const alreadyOwned = ownedAvatars.includes(entitlement.inventoryAvatarId);
      const nextAvatars = alreadyOwned
        ? ownedAvatars
        : [...ownedAvatars, entitlement.inventoryAvatarId];

      const updates: admin.firestore.UpdateData<admin.firestore.DocumentData> = {
        "Inventory.avatars": nextAvatars,
        [`Entitlements.${entitlement.entitlementId}`]: {
          productId,
          status: "active",
          orderId: orderId ?? null,
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
        consumed: false, // never consumed
        orderId: orderId ?? null,
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
      orderId: orderId ?? null,
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
  } else {
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
    } else {
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
  } catch (consumeError: any) {
    if (consumeError.code === 410) {
      consumed = !entitlement;
      await iapRef.update({ consumed }).catch(() => {});
    } else {
      console.error(`[verifyPurchase] Consume/acknowledge error (non-fatal) for uid=${uid}:`, consumeError);
    }
  }

  writeAuditLog(
    uid,
    entitlement ? "avatar_iap" : "iap_purchase",
    entitlement
      ? { productId, entitlementId: entitlement.entitlementId, tokenHash }
      : { productId, coinsAdded: coinsToAdd, tokenHash }
  ).catch(() => {});

  return {
    ok: true,
    coinsAdded: entitlement ? 0 : coinsToAdd,
    newBalance,
    consumed,
    productType: entitlement ? "avatar" : "coins",
    avatarId: entitlement?.entitlementId,
  };
}

/**
 * Verify a Google Play purchase and grant coins. (New canonical name)
 *
 * Input:  { productId, purchaseToken, packageName, orderId? }
 * Output: { ok, coinsAdded, newBalance, consumed, message? }
 */
export const verifyAndroidPurchase = functions
  .runWith({ secrets: ["GOOGLE_SERVICE_ACCOUNT_KEY"] })
  .https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const { productId, purchaseToken, packageName, orderId } = data as {
    productId?: string;
    purchaseToken?: string;
    packageName?: string;
    orderId?: string;
  };
  return _verifyAndGrantCoins(uid, productId!, purchaseToken!, packageName!, orderId);
});

/**
 * Backward-compatible alias for verifyAndroidPurchase.
 * Keep this export so existing Flutter calls to 'verifyGooglePlayPurchase' continue working.
 */
export const verifyGooglePlayPurchase = functions
  .runWith({ secrets: ["GOOGLE_SERVICE_ACCOUNT_KEY"] })
  .https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const { productId, purchaseToken, packageName, orderId } = data as {
    productId?: string;
    purchaseToken?: string;
    packageName?: string;
    orderId?: string;
  };
  return _verifyAndGrantCoins(uid, productId!, purchaseToken!, packageName!, orderId);
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
export const purchaseAvatar = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const { itemId } = data as { itemId?: string };

  if (!itemId) throw new functions.https.HttpsError("invalid-argument", "itemId is required.");

  const itemDoc = await db.collection("avatars").doc(itemId).get();
  if (!itemDoc.exists || itemDoc.data()?.enabled !== true) {
    throw new functions.https.HttpsError("not-found", "Avatar not found or not available.");
  }
  const price = (itemDoc.data()?.price ?? 0) as number;
  const itemName = (itemDoc.data()?.name ?? itemId) as string;

  const userRef = db.collection("users").doc(uid);
  let newBalance = 0;
  let newAvatars: string[] = [];

  await db.runTransaction(async (tx) => {
    const userDoc = await tx.get(userRef);
    const wallet = (userDoc.data()?.Wallet ?? {}) as Record<string, number>;
    const inventory = (userDoc.data()?.Inventory ?? {}) as Record<string, unknown>;

    const currentCoins = (wallet.coins ?? 0) as number;
    const currentSpent = (wallet.lifetimeSpent ?? 0) as number;
    const ownedAvatars = ((inventory.avatars ?? []) as string[]);

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
  writeAuditLog(uid, "avatar_purchase", { itemId, price }).catch(() => {});

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
export const purchaseXSkin = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const { itemId } = data as { itemId?: string };

  if (!itemId) throw new functions.https.HttpsError("invalid-argument", "itemId is required.");

  const itemDoc = await db.collection("x_skins").doc(itemId).get();
  if (!itemDoc.exists || itemDoc.data()?.enabled !== true) {
    throw new functions.https.HttpsError("not-found", "X skin not found or not available.");
  }
  const price = (itemDoc.data()?.price ?? 0) as number;
  const itemName = (itemDoc.data()?.name ?? itemId) as string;

  const userRef = db.collection("users").doc(uid);
  let newBalance = 0;
  let newSkins: string[] = [];

  await db.runTransaction(async (tx) => {
    const userDoc = await tx.get(userRef);
    const wallet = (userDoc.data()?.Wallet ?? {}) as Record<string, number>;
    const inventory = (userDoc.data()?.Inventory ?? {}) as Record<string, unknown>;
    const currentCoins = (wallet.coins ?? 0) as number;
    const currentSpent = (wallet.lifetimeSpent ?? 0) as number;
    const ownedSkins = ((inventory.xSkins ?? []) as string[]);

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
  writeAuditLog(uid, "x_skin_purchase", { itemId, price }).catch(() => {});

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
export const purchaseOSkin = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const { itemId } = data as { itemId?: string };

  if (!itemId) throw new functions.https.HttpsError("invalid-argument", "itemId is required.");

  const itemDoc = await db.collection("o_skins").doc(itemId).get();
  if (!itemDoc.exists || itemDoc.data()?.enabled !== true) {
    throw new functions.https.HttpsError("not-found", "O skin not found or not available.");
  }
  const price = (itemDoc.data()?.price ?? 0) as number;
  const itemName = (itemDoc.data()?.name ?? itemId) as string;

  const userRef = db.collection("users").doc(uid);
  let newBalance = 0;
  let newSkins: string[] = [];

  await db.runTransaction(async (tx) => {
    const userDoc = await tx.get(userRef);
    const wallet = (userDoc.data()?.Wallet ?? {}) as Record<string, number>;
    const inventory = (userDoc.data()?.Inventory ?? {}) as Record<string, unknown>;
    const currentCoins = (wallet.coins ?? 0) as number;
    const currentSpent = (wallet.lifetimeSpent ?? 0) as number;
    const ownedSkins = ((inventory.oSkins ?? []) as string[]);

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
  writeAuditLog(uid, "o_skin_purchase", { itemId, price }).catch(() => {});

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
export const equipAvatar = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const { itemId } = data as { itemId?: string };

  if (!itemId) throw new functions.https.HttpsError("invalid-argument", "itemId is required.");

  const userDoc = await db.collection("users").doc(uid).get();
  const ownedAvatars = ((userDoc.data()?.Inventory?.avatars ?? []) as string[]);

  if (!ownedAvatars.includes(itemId)) {
    throw new functions.https.HttpsError("permission-denied", "You do not own this avatar.");
  }

  await db.collection("users").doc(uid).update({ "Inventory.equippedAvatar": itemId });

  writeAuditLog(uid, "equip_avatar", { itemId }).catch(() => {});
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
export const equipXSkin = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const { itemId } = data as { itemId?: string };

  if (!itemId) throw new functions.https.HttpsError("invalid-argument", "itemId is required.");

  const userDoc = await db.collection("users").doc(uid).get();
  const ownedSkins = ((userDoc.data()?.Inventory?.xSkins ?? []) as string[]);

  if (!ownedSkins.includes(itemId)) {
    throw new functions.https.HttpsError("permission-denied", "You do not own this X skin.");
  }

  await db.collection("users").doc(uid).update({ "Inventory.equippedXSkin": itemId });

  writeAuditLog(uid, "equip_x_skin", { itemId }).catch(() => {});
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
export const equipOSkin = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const { itemId } = data as { itemId?: string };

  if (!itemId) throw new functions.https.HttpsError("invalid-argument", "itemId is required.");

  const userDoc = await db.collection("users").doc(uid).get();
  const ownedSkins = ((userDoc.data()?.Inventory?.oSkins ?? []) as string[]);

  if (!ownedSkins.includes(itemId)) {
    throw new functions.https.HttpsError("permission-denied", "You do not own this O skin.");
  }

  await db.collection("users").doc(uid).update({ "Inventory.equippedOSkin": itemId });

  writeAuditLog(uid, "equip_o_skin", { itemId }).catch(() => {});
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
export const deleteMyAccount = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);

  console.log(`[deleteMyAccount] Starting deletion for uid=${uid}`);

  try {
    // Read user data for audit record
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data() ?? {};
    const email = context.auth!.token.email ?? null;
    const finalBalance = (userData.Wallet?.coins ?? 0) as number;
    const totalGames = (userData.Stats?.gamesPlayed ?? 0) as number;

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
    await writeAuditLog(
      uid,
      "account_deleted",
      { email, finalBalance, totalGames },
      "critical"
    );

    // Step 3 & 4: Delete subcollections
    await deleteCollection(`users/${uid}/transactions`);
    await deleteCollection(`users/${uid}/purchase_counts`);

    // Step 5–7: Batch-delete main documents
    const batch = db.batch();
    batch.delete(db.collection("users").doc(uid));

    const feedbackDoc = await db.collection("deletion_feedback").doc(uid).get();
    if (feedbackDoc.exists) batch.delete(feedbackDoc.ref);

    const requestDoc = await db.collection("deletion_requests").doc(uid).get();
    if (requestDoc.exists) batch.delete(requestDoc.ref);

    await batch.commit();

    // Step 8: Delete Firebase Auth user (do this LAST so the function stays callable)
    await admin.auth().deleteUser(uid);

    console.log(`[deleteMyAccount] Deletion complete for uid=${uid}`);
    return { ok: true };
  } catch (e: any) {
    console.error(`[deleteMyAccount] Error for uid=${uid}:`, e);
    if (e instanceof functions.https.HttpsError) throw e;
    throw new functions.https.HttpsError(
      "internal",
      "Account deletion failed: " + (e.message || "Unknown error")
    );
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

export const redeemReferralCode = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const callerUid = requireAuth(context);
  const { code } = (data ?? {}) as { code?: string };

  if (!code || typeof code !== "string" || !/^[0-9]{9}$/.test(code)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Referral code must be exactly 9 digits."
    );
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
  const referrerUid = (codeSnap.data()?.uid ?? "") as string;
  if (!referrerUid) {
    throw new functions.https.HttpsError("not-found", "Referral code is invalid.");
  }
  if (referrerUid === callerUid) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "You cannot redeem your own invite code."
    );
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
      const existingReferral = await tx.get(referralRef);
      if (existingReferral.exists) {
        throw new functions.https.HttpsError(
          "already-exists",
          "This invite code has already been redeemed."
        );
      }

      const [inviteeSnap, referrerSnap, inviteeLedgerSnap, referrerLedgerSnap] =
        await Promise.all([
          tx.get(inviteeRef),
          tx.get(referrerRef),
          tx.get(inviteeLedgerRef),
          tx.get(referrerLedgerRef),
        ]);

      if (inviteeLedgerSnap.exists || referrerLedgerSnap.exists) {
        throw new functions.https.HttpsError(
          "already-exists",
          "This referral reward has already been applied."
        );
      }

      const inviteeReferral = (inviteeSnap.data()?.Referral ?? {}) as Record<string, unknown>;
      if (inviteeReferral.referralUsed === true) {
        throw new functions.https.HttpsError(
          "already-exists",
          "You have already redeemed an invite code."
        );
      }

      const referrerReferral = (referrerSnap.data()?.Referral ?? {}) as Record<string, unknown>;
      const currentCount = (referrerReferral.validReferralCount as number | undefined) ?? 0;
      if (currentCount >= REFERRAL_MAX_FRIENDS) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "Referrer has reached the maximum number of invited friends."
        );
      }

      const inviteeBefore = ((inviteeSnap.data()?.Wallet?.coins as number | undefined) ?? 0);
      const referrerBefore = ((referrerSnap.data()?.Wallet?.coins as number | undefined) ?? 0);
      inviteeAfter = inviteeBefore + REFERRAL_REWARD;
      referrerAfter = referrerBefore + REFERRAL_REWARD;
      newReferrerCount = currentCount + 1;
      const newTotal =
        ((referrerReferral.totalReferralCoinsEarned as number | undefined) ?? 0) +
        REFERRAL_REWARD;

      const now = admin.firestore.FieldValue.serverTimestamp();

      tx.set(referralRef, {
        inviteeUid: callerUid,
        referrerUid,
        code,
        rewardCoins: REFERRAL_REWARD,
        createdAt: now,
      });

      tx.set(
        inviteeRef,
        {
          Wallet: { coins: inviteeAfter },
          Referral: {
            referredBy: referrerUid,
            referralUsed: true,
            updatedAt: now,
          },
        },
        { merge: true }
      );

      tx.set(
        referrerRef,
        {
          Wallet: { coins: referrerAfter },
          Referral: {
            validReferralCount: newReferrerCount,
            totalReferralCoinsEarned: newTotal,
            updatedAt: now,
          },
        },
        { merge: true }
      );

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
  } catch (e: any) {
    if (e instanceof functions.https.HttpsError) throw e;
    console.error(`[redeemReferralCode] tx failed uid=${callerUid} code=${code}:`, e);
    throw new functions.https.HttpsError(
      "internal",
      "Referral redemption failed: " + (e.message || "Unknown error")
    );
  }

  writeAuditLog(
    callerUid,
    "referral_redeemed",
    { code, referrerUid, reward: REFERRAL_REWARD, referrerCount: newReferrerCount }
  ).catch(() => {});

  console.log(
    `[redeemReferralCode] uid=${callerUid} referrer=${referrerUid} code=${code} count=${newReferrerCount}`
  );

  return {
    ok: true,
    inviteeReward: REFERRAL_REWARD,
    referrerReward: REFERRAL_REWARD,
    inviteeBalance: inviteeAfter,
    referrerCount: newReferrerCount,
  };
});
