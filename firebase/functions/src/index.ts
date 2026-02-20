import * as admin from "firebase-admin";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

admin.initializeApp();

const db = admin.firestore();

// ---------------------------------------------------------------------------
// processReceipt
// Triggered when a file is uploaded to Firebase Storage.
// TODO: Call Google Cloud Vision API to OCR the receipt image.
// TODO: Parse the OCR result to extract amount, date, vendor, and category.
// TODO: Write a TransactionModel document to Firestore under
//       /users/{uid}/transactions/{txnId}.
// TODO: If confidence < 0.5, also write a document to /admin_flags/{txnId}
//       with status: 'open' for manual review.
// ---------------------------------------------------------------------------
export const processReceipt = onObjectFinalized(
  { region: "africa-south1" },
  async (event) => {
    const filePath = event.data.name;
    // Receipt path convention: receipts/{uid}/{filename}
    if (!filePath || !filePath.startsWith("receipts/")) return;

    const uid = filePath.split("/")[1];
    if (!uid) return;

    console.log(`Processing receipt for uid=${uid}, path=${filePath}`);

    // TODO: Implement Cloud Vision OCR call
    // const [result] = await visionClient.textDetection(`gs://${bucket}/${filePath}`);
    // const rawText = result.textAnnotations?.[0]?.description ?? '';
    // const confidence = parseConfidence(result);
    // const txn = parseTransaction(rawText, filePath, uid, confidence);
    // await db.collection('users').doc(uid).collection('transactions').doc(txn.txnId).set(txn);
    // if (confidence < 0.5) {
    //   await db.collection('admin_flags').doc(txn.txnId).set({ ...txn, status: 'open' });
    // }
  }
);

// ---------------------------------------------------------------------------
// stripeWebhook
// HTTP endpoint called by Stripe for subscription lifecycle events.
// TODO: Verify the Stripe-Signature header against the webhook secret.
// TODO: Handle 'customer.subscription.updated': update user.plan in Firestore
//       based on the price/product mapping.
// TODO: Handle 'invoice.payment_failed': mark user as past_due, send FCM.
// TODO: Return 200 quickly to avoid Stripe retries.
// ---------------------------------------------------------------------------
export const stripeWebhook = onRequest(
  { region: "us-central1" },
  async (req, res) => {
    const sig = req.headers["stripe-signature"];
    if (!sig) {
      res.status(400).send("Missing stripe-signature header");
      return;
    }

    // TODO: const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2023-10-16' });
    // TODO: const event = stripe.webhooks.constructEvent(req.rawBody, sig, process.env.STRIPE_WEBHOOK_SECRET!);

    // TODO: switch (event.type) {
    //   case 'customer.subscription.updated': ...
    //   case 'invoice.payment_failed': ...
    // }

    res.status(200).json({ received: true });
  }
);

// ---------------------------------------------------------------------------
// budgetAlertCheck
// Runs every 24 hours. Reads all budget documents across all users,
// compares each budget's limit to the user's actual monthly spend,
// and sends an FCM push notification when alertAt threshold is exceeded.
// TODO: Use a collectionGroup query on 'budgets' for scalability.
// TODO: For each budget breach, fetch the user's FCM token and send via
//       admin.messaging().send().
// ---------------------------------------------------------------------------
export const budgetAlertCheck = onSchedule(
  { schedule: "every 24 hours", region: "us-central1" },
  async (_event) => {
    console.log("Running budget alert check...");

    // TODO: const budgetsSnap = await db.collectionGroup('budgets').get();
    // TODO: For each budget, compute spend and check alertAt threshold.
    // TODO: Send FCM notification if threshold exceeded and not already notified today.
  }
);

// ---------------------------------------------------------------------------
// invoiceReminder
// Runs every 24 hours. Checks for user-configured invoice due dates
// stored in Firestore and sends FCM reminders for upcoming/overdue invoices.
// TODO: Query /users/{uid}/invoices where dueDate is within the next 3 days.
// TODO: Send FCM for each matching invoice.
// ---------------------------------------------------------------------------
export const invoiceReminder = onSchedule(
  { schedule: "every 24 hours", region: "us-central1" },
  async (_event) => {
    console.log("Running invoice reminder check...");

    // TODO: const now = admin.firestore.Timestamp.now();
    // TODO: Query invoices due within 3 days and send reminders.
  }
);

// ---------------------------------------------------------------------------
// adminGetUser
// Admin-only HTTP endpoint. Returns full user profile + last 50 transactions.
// TODO: Validate that the caller has admin: true custom claim via ID token.
// TODO: Accept uid as a query parameter.
// TODO: Fetch UserModel from /users/{uid}.
// TODO: Fetch last 50 transactions from /users/{uid}/transactions.
// TODO: Return as JSON.
// ---------------------------------------------------------------------------
export const adminGetUser = onRequest(
  { region: "us-central1" },
  async (req, res) => {
    const idToken = req.headers.authorization?.replace("Bearer ", "");
    if (!idToken) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    let decodedToken: admin.auth.DecodedIdToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch {
      res.status(401).json({ error: "Invalid token" });
      return;
    }

    if (!decodedToken.admin) {
      res.status(403).json({ error: "Forbidden: admin privileges required" });
      return;
    }

    const uid = req.query.uid as string;
    if (!uid) {
      res.status(400).json({ error: "Missing uid parameter" });
      return;
    }

    // TODO: Fetch user and transactions, return as JSON
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
      res.status(404).json({ error: "User not found" });
      return;
    }

    const txnsSnap = await db
      .collection("users")
      .doc(uid)
      .collection("transactions")
      .orderBy("date", "desc")
      .limit(50)
      .get();

    res.status(200).json({
      user: userDoc.data(),
      transactions: txnsSnap.docs.map((d) => d.data()),
    });
  }
);

// ---------------------------------------------------------------------------
// adminUpdateUser
// Admin-only HTTP endpoint. Updates a user's plan or disabled status.
// TODO: Validate admin claim (same as adminGetUser).
// TODO: Accept uid, plan (optional), disabled (optional) in request body.
// TODO: Update Firestore document and Firebase Auth user if needed.
// ---------------------------------------------------------------------------
export const adminUpdateUser = onRequest(
  { region: "us-central1" },
  async (req, res) => {
    const idToken = req.headers.authorization?.replace("Bearer ", "");
    if (!idToken) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    let decodedToken: admin.auth.DecodedIdToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch {
      res.status(401).json({ error: "Invalid token" });
      return;
    }

    if (!decodedToken.admin) {
      res.status(403).json({ error: "Forbidden: admin privileges required" });
      return;
    }

    const { uid, plan, disabled } = req.body as {
      uid: string;
      plan?: string;
      disabled?: boolean;
    };
    if (!uid) {
      res.status(400).json({ error: "Missing uid" });
      return;
    }

    const updates: Record<string, unknown> = {};
    if (plan) updates.plan = plan;
    if (disabled !== undefined) {
      await admin.auth().updateUser(uid, { disabled });
    }
    if (Object.keys(updates).length > 0) {
      await db.collection("users").doc(uid).update(updates);
    }

    res.status(200).json({ success: true });
  }
);

// ---------------------------------------------------------------------------
// exportUserData
// HTTP endpoint (called by the authenticated user themselves).
// Generates a CSV of all their transactions, uploads to Storage under
// /exports/{uid}/transactions_{timestamp}.csv, and returns a signed URL.
// TODO: Validate the caller's own UID (not admin-only).
// TODO: Fetch all transactions for the user.
// TODO: Convert to CSV.
// TODO: Upload to Storage.
// TODO: Generate and return a signed download URL (valid 1 hour).
// ---------------------------------------------------------------------------
export const exportUserData = onRequest(
  { region: "us-central1" },
  async (req, res) => {
    const idToken = req.headers.authorization?.replace("Bearer ", "");
    if (!idToken) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    let decodedToken: admin.auth.DecodedIdToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch {
      res.status(401).json({ error: "Invalid token" });
      return;
    }

    const uid = decodedToken.uid;

    // TODO: Fetch transactions, generate CSV, upload, return signed URL.
    const txnsSnap = await db
      .collection("users")
      .doc(uid)
      .collection("transactions")
      .orderBy("date", "desc")
      .get();

    const header = "txnId,amount,currency,vendor,category,date,isTaxDeductible";
    const rows = txnsSnap.docs.map((d) => {
      const t = d.data();
      return [
        t.txnId,
        t.amount,
        t.currency,
        `"${String(t.vendor).replace(/"/g, '""')}"`,
        t.category,
        t.date,
        t.isTaxDeductible,
      ].join(",");
    });
    const csv = [header, ...rows].join("\n");

    const timestamp = Date.now();
    const filePath = `exports/${uid}/transactions_${timestamp}.csv`;
    const bucket = admin.storage().bucket();
    const file = bucket.file(filePath);
    await file.save(csv, { contentType: "text/csv" });

    const [url] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + 60 * 60 * 1000, // 1 hour
    });

    res.status(200).json({ downloadUrl: url });
  }
);

// ---------------------------------------------------------------------------
// exchangeRateSync
// Runs every 60 minutes. Fetches latest FX rates from an external API
// and stores them in Firestore at /system/exchangeRates.
// TODO: Use process.env.EXCHANGE_RATE_API_KEY for authentication.
// TODO: Fetch rates from e.g. https://v6.exchangerate-api.com/v6/{key}/latest/ZAR
// TODO: Store result in Firestore /system/exchangeRates with a lastUpdated timestamp.
// ---------------------------------------------------------------------------
export const exchangeRateSync = onSchedule(
  { schedule: "every 60 minutes", region: "us-central1" },
  async (_event) => {
    console.log("Syncing exchange rates...");

    // TODO: const apiKey = process.env.EXCHANGE_RATE_API_KEY;
    // TODO: const response = await axios.get(`https://v6.exchangerate-api.com/v6/${apiKey}/latest/ZAR`);
    // TODO: const rates = response.data.conversion_rates;
    // TODO: await db.collection('system').doc('exchangeRates').set({
    //   rates,
    //   baseCurrency: 'ZAR',
    //   lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    // });
  }
);
