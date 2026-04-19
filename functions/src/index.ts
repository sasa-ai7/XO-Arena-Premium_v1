import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { google } from "googleapis";

admin.initializeApp();

const db = admin.firestore();

// Expected package name (hardcoded for security)
const EXPECTED_PACKAGE_NAME = "com.sasa.xogame";

// Product ID to coins mapping (server-authoritative)
const PRODUCT_COINS_MAP: Record<string, number> = {
  "coins_pack_200": 200,
  "coins_pack_400": 400,
  "coins_pack_600": 600,
  "coins_pack_800": 800,
  "coins_pack_1000": 1000,
  "coins_pack_2000": 2000,
  "coins_pack_3000": 3000,
  "coins_pack_5000": 5000,
  "coins_pack_10000": 10000,
  "coins_pack_20000": 20000,
};

/**
 * Initialize Google Play Developer API client
 * Uses Firebase Secrets for service account key (accessed via process.env)
 * 
 * To set the secret:
 * firebase functions:secrets:set GOOGLE_SERVICE_ACCOUNT_KEY
 */
function getAndroidPublisher() {
  try {
    // Get service account key from Firebase Secrets
    // Secret is automatically available via process.env after deployment with:
    // firebase functions:secrets:set GOOGLE_SERVICE_ACCOUNT_KEY
    const serviceAccountKey = process.env.GOOGLE_SERVICE_ACCOUNT_KEY;
    
    if (!serviceAccountKey) {
      throw new Error("GOOGLE_SERVICE_ACCOUNT_KEY secret not set. Deploy with: firebase functions:secrets:set GOOGLE_SERVICE_ACCOUNT_KEY");
    }

    const serviceAccount = JSON.parse(serviceAccountKey);

    const auth = new google.auth.JWT(
      serviceAccount.client_email,
      undefined,
      serviceAccount.private_key,
      ["https://www.googleapis.com/auth/androidpublisher"]
    );

    return google.androidpublisher({ version: "v3", auth });
  } catch (error: any) {
    console.error("Failed to initialize Google Play API:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Google Play API not configured: " + (error.message || "Unknown error")
    );
  }
}

/**
 * Verify Google Play purchase and grant coins
 * 
 * This is an HTTPS callable function that:
 * 1. Verifies Firebase Auth token (automatic via callable)
 * 2. Extracts UID from token (server-authoritative)
 * 3. Verifies purchase with Google Play Developer API
 * 4. Grants coins to user in Firestore (idempotent)
 * 5. Consumes purchase via Google Play API
 * 
 * Request: {
 *   productId: string,
 *   purchaseToken: string,
 *   packageName: string,
 *   orderId?: string
 * }
 * 
 * Response: {
 *   ok: boolean,
 *   coinsAdded?: number,
 *   newBalance?: number,
 *   consumed: boolean,
 *   message?: string
 * }
 */
export const verifyGooglePlayPurchase = functions.https.onCall(
  async (data, context) => {
    // Security: Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    // Extract UID from verified token (server-authoritative)
    const uid = context.auth.uid;

    // Extract request data
    const { productId, purchaseToken, packageName, orderId } = data;

    // Validate required fields
    if (!productId || !purchaseToken || !packageName) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: productId, purchaseToken, packageName"
      );
    }

    // Security: Verify package name matches expected
    if (packageName !== EXPECTED_PACKAGE_NAME) {
      console.warn(`[${uid}] Invalid package name: ${packageName}`);
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Invalid package name: ${packageName}`
      );
    }

    // Validate product ID
    const coinsToAdd = PRODUCT_COINS_MAP[productId];
    if (!coinsToAdd) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Invalid product ID: ${productId}`
      );
    }

    try {
      // Initialize Google Play API client
      const androidPublisher = getAndroidPublisher();

      // Step 1: Verify purchase with Google Play Developer API
      console.log(
        `[${uid}] Verifying purchase: productId=${productId}, token=${purchaseToken.substring(0, 20)}...`
      );

      const purchaseResponse = await androidPublisher.purchases.products.get({
        packageName: packageName,
        productId: productId,
        token: purchaseToken,
      });

      const purchase = purchaseResponse.data;

      // Verify purchase state (0 = Purchased, 1 = Canceled)
      if (purchase.purchaseState !== 0) {
        console.warn(
          `[${uid}] Purchase not valid. State: ${purchase.purchaseState}`
        );
        throw new functions.https.HttpsError(
          "failed-precondition",
          `Purchase not valid. State: ${purchase.purchaseState}`
        );
      }

      // Step 2: Check idempotency - has this purchase been processed before?
      const transactionRef = db.collection("iap_transactions").doc(purchaseToken);
      const transactionDoc = await transactionRef.get();

      if (transactionDoc.exists) {
        const transactionData = transactionDoc.data();
        if (transactionData?.processedAt) {
          console.log(
            `[${uid}] Purchase already processed: ${productId} (token: ${purchaseToken.substring(0, 20)}...)`
          );
          // Get current balance
          const userRef = db.collection("users").doc(uid);
          const userDoc = await userRef.get();
          const currentBalance = userDoc.exists
            ? userDoc.data()?.coinBalance || 0
            : 0;

          return {
            ok: true,
            coinsAdded: 0,
            newBalance: currentBalance,
            consumed: purchase.consumptionState === 1,
            message: "Purchase already processed",
          };
        }
      }

      // Step 3: Grant coins to user (idempotent via Firestore transaction)
      const userRef = db.collection("users").doc(uid);
      let newBalance: number;
      let coinsAdded: number;

      await db.runTransaction(async (transaction) => {
        // Get current balance
        const userDoc = await transaction.get(userRef);
        const currentBalance = userDoc.exists
          ? userDoc.data()?.coinBalance || 0
          : 0;

        // Calculate new balance
        newBalance = currentBalance + coinsToAdd;
        coinsAdded = coinsToAdd;

        // Update user balance
        transaction.update(userRef, {
          coinBalance: newBalance,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Record transaction for idempotency
        transaction.set(transactionRef, {
          uid: uid,
          productId: productId,
          coinsAdded: coinsToAdd,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          consumed: false, // Will be updated after consume
          orderId: orderId || null,
        });
      });

      console.log(
        `[${uid}] Granted ${coinsAdded} coins for ${productId}. New balance: ${newBalance}`
      );

      // Step 4: Consume the purchase via Google Play API (if not already consumed)
      let consumed = false;
      if (purchase.consumptionState === 0) {
        // 0 = Yet to be consumed, 1 = Consumed
        try {
          await androidPublisher.purchases.products.consume({
            packageName: packageName,
            productId: productId,
            token: purchaseToken,
          });
          consumed = true;
          console.log(`[${uid}] Purchase consumed: ${productId}`);

          // Update transaction record
          await transactionRef.update({
            consumed: true,
          });
        } catch (consumeError: any) {
          // Handle specific consume errors
          if (consumeError.code === 410) {
            // Already consumed (race condition)
            console.log(
              `[${uid}] Purchase already consumed (race condition): ${productId}`
            );
            consumed = true;
            await transactionRef.update({
              consumed: true,
            });
          } else {
            console.error(
              `[${uid}] Failed to consume purchase: ${consumeError.message}`
            );
            // Coins are already granted, so return success even if consume fails
            // The purchase will be consumed on next verification attempt
          }
        }
      } else {
        consumed = true; // Already consumed
        await transactionRef.update({
          consumed: true,
        });
      }

      // Step 5: Return success response
      return {
        ok: true,
        coinsAdded: coinsAdded,
        newBalance: newBalance,
        consumed: consumed,
      };
    } catch (error: any) {
      console.error(`[${uid}] Purchase verification error:`, error);

      // Handle specific Google Play API errors
      if (error.code === 410) {
        // Purchase token is invalid or expired
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Invalid or expired purchase token"
        );
      } else if (error.code === 404) {
        // Purchase not found
        throw new functions.https.HttpsError(
          "not-found",
          "Purchase not found"
        );
      } else if (error instanceof functions.https.HttpsError) {
        // Re-throw HttpsError as-is
        throw error;
      }

      // Generic error
      throw new functions.https.HttpsError(
        "internal",
        error.message || "Internal server error"
      );
    }
  }
);
