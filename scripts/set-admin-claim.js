#!/usr/bin/env node
/**
 * Sets the `admin: true` custom claim on a Firebase Auth user.
 *
 * Usage:
 *   node set-admin-claim.js <email-or-uid>
 *
 * Requirements:
 *   1. npm install firebase-admin   (run once in this directory)
 *   2. A service account key JSON downloaded from:
 *      Firebase Console → Project Settings → Service Accounts → Generate new private key
 *      Save it as  scripts/serviceAccountKey.json  (already in .gitignore)
 */

const admin = require('firebase-admin');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'serviceAccountKey.json');
const PROJECT_ID = 'snapspend-ec4b6';

// ── bootstrap ────────────────────────────────────────────────────────────────

let serviceAccount;
try {
  serviceAccount = require(SERVICE_ACCOUNT_PATH);
} catch {
  console.error(`
ERROR: Service account key not found at:
  ${SERVICE_ACCOUNT_PATH}

To get one:
  1. Go to https://console.firebase.google.com/project/${PROJECT_ID}/settings/serviceaccounts/adminsdk
  2. Click "Generate new private key"
  3. Save the downloaded JSON as:
     scripts/serviceAccountKey.json
`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// ── main ─────────────────────────────────────────────────────────────────────

async function main() {
  const input = process.argv[2];
  if (!input) {
    console.error('Usage: node set-admin-claim.js <email-or-uid>');
    process.exit(1);
  }

  let uid;
  if (input.includes('@')) {
    // Look up by email
    console.log(`Looking up user by email: ${input}`);
    const user = await admin.auth().getUserByEmail(input);
    uid = user.uid;
    console.log(`Found UID: ${uid}`);
  } else {
    uid = input;
    console.log(`Using UID directly: ${uid}`);
  }

  // Set the custom claim
  await admin.auth().setCustomUserClaims(uid, { admin: true });
  console.log(`✓ admin: true claim set on ${uid}`);

  // Verify
  const updated = await admin.auth().getUser(uid);
  console.log('Custom claims now:', updated.customClaims);
  console.log('\nDone. The user will need to sign out and back in (or wait ~1 hour) for the claim to take effect in existing sessions.');
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
