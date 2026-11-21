#!/usr/bin/env node
// Project Altair - administrator tools for the team PC.
//
//   node admin.js create-admin   <UserID> <Password> "<Full Name>"
//   node admin.js reset-password <UserID> <NewPassword>
//
// Add --emulator at the end to work against the local Firebase emulators.
//
// These two jobs need Google's Admin SDK, which must never be put inside a
// phone app. It runs here instead, with the key file serviceAccountKey.json
// (BUILD_GUIDE.md, Part 3). It is free: no paid Firebase plan is involved.

const fs = require("node:fs");
const path = require("node:path");

// Must match loginDomain in lib/app/config.dart.
const LOGIN_DOMAIN = "altair.example.com";
const ID_PATTERN = /^[a-z0-9][a-z0-9._-]{2,31}$/;

const USAGE = [
  "Usage:",
  '  node admin.js create-admin   <UserID> <Password> "<Full Name>"',
  "  node admin.js reset-password <UserID> <NewPassword>",
  "",
  "Add --emulator to use the local emulators instead of the real project.",
].join("\n  ");

function fail(message) {
  console.error(`\n  ${message}\n`);
  process.exit(1);
}

const emulator = process.argv.includes("--emulator");
const [command, userId, secret, ...rest] = process.argv
  .slice(2)
  .filter((arg) => arg !== "--emulator");

if (!["create-admin", "reset-password"].includes(command) || !userId || !secret) {
  fail(USAGE);
}
if (!ID_PATTERN.test(userId.toLowerCase())) {
  fail("User ID: use 3-32 letters, digits, dot, dash or underscore.");
}
if (secret.length < 8) {
  fail("The password must be at least 8 characters long.");
}

const { initializeApp, cert } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

if (emulator) {
  process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
  initializeApp({ projectId: "demo-project-altair" });
} else {
  const keyPath = path.join(__dirname, "serviceAccountKey.json");
  if (!fs.existsSync(keyPath)) {
    fail(
      "serviceAccountKey.json is missing from the tools folder.\n" +
        "  Download it as described in BUILD_GUIDE.md, Part 3.",
    );
  }
  initializeApp({
    credential: cert(JSON.parse(fs.readFileSync(keyPath, "utf8"))),
  });
}

const auth = getAuth();
const db = getFirestore();
const loginName = `${userId.toLowerCase()}@${LOGIN_DOMAIN}`;
const now = () => FieldValue.serverTimestamp();

async function findAccount() {
  try {
    return await auth.getUserByEmail(loginName);
  } catch (error) {
    if (error.code === "auth/user-not-found") return null;
    throw error;
  }
}

// Creates the first Super Admin, or turns an existing account into one.
async function createAdmin() {
  const fullName = rest.join(" ").trim();
  if (!fullName) fail('Add the full name in quotes, for example "Md. Mahin Rahman".');

  let account = await findAccount();
  if (account) {
    await auth.updateUser(account.uid, { password: secret, disabled: false });
  } else {
    account = await auth.createUser({ email: loginName, password: secret });
  }

  const ref = db.collection("users").doc(account.uid);
  const old = (await ref.get()).data() || {};
  await ref.set({
    userId,
    fullName,
    role: "superAdmin",
    position: old.position || "",
    subTeamId: old.subTeamId || "",
    subTeamName: old.subTeamName || "",
    photoUrl: old.photoUrl || "",
    disabled: false,
    mustChangePassword: false,
    createdAt: old.createdAt || now(),
    updatedAt: now(),
  });
  console.log(`\n  Super Admin ready. Sign in to the app with the User ID "${userId}".\n`);
}

// Replaces a forgotten password. The old one stops working at once.
async function resetPassword() {
  const account = await findAccount();
  if (!account) fail(`There is no account with the User ID "${userId}".`);

  await auth.updateUser(account.uid, { password: secret });
  await auth.revokeRefreshTokens(account.uid);

  const ref = db.collection("users").doc(account.uid);
  if ((await ref.get()).exists) {
    await ref.update({ mustChangePassword: true, updatedAt: now() });
  }
  console.log(
    `\n  Password replaced for "${userId}". Give the member the new password;\n` +
      "  the app asks them to choose their own at the next sign-in.\n",
  );
}

(command === "create-admin" ? createAdmin() : resetPassword())
  .then(() => process.exit(0))
  .catch((error) => fail(`Failed: ${error.message || error}`));
