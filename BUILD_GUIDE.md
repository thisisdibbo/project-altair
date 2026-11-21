# Project Altair — build guide (free Firebase plan)

Follow the parts in order. Every step says **what to type** and **why**.
Commands are for Windows (PowerShell or Command Prompt). Run them inside the
project folder unless a step says otherwise.

**Nothing here costs money.** The app runs on Firebase's free **Spark** plan:
no billing account, no card, no upgrade. It uses only Firebase Authentication
and the Firestore database.

> **Status of this code.** See "What has and has not been verified" in
> `README.md`. If `flutter run` or `flutter build` prints an error, copy the
> error text back to Claude and it will be fixed.

> **Already started with the earlier guide?** Throw away the old project
> folder and use this one (about 40 files changed, so patching by hand is not
> practical). You can keep the Firebase project you created. **Do not upgrade
> to Blaze**, skip Storage and Cloud Functions entirely, and do step 2.2
> (switch on Email/Password), which is new.

---

## Part 0 — Install the tools (once)

| # | Install | Link | Why |
|---|---------|------|-----|
| 1 | **Flutter SDK** 3.38 or newer | https://docs.flutter.dev/get-started/install/windows/mobile | Turns the Dart code into Android and iOS apps. |
| 2 | **Android Studio** (it installs the Android SDK) | https://developer.android.com/studio | Flutter needs the Android SDK to build an APK. |
| 3 | **Node.js 22 LTS** | https://nodejs.org | Runs the Firebase command-line tool and the small admin tool. |
| 4 | **Git for Windows** | https://git-scm.com/download/win | Flutter uses Git internally. |

Then open a **new** terminal and run:

```
flutter doctor --android-licenses
flutter doctor
```

*Why:* the first accepts the Android licences; the second checks everything.
Android toolchain and Flutter must show a green tick. (Xcode and Visual Studio
warnings do not matter on Windows.)

Install the two Firebase command-line tools:

```
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

*Why:* `firebase` uploads the security rules; `flutterfire` links the app to
your Firebase project. If Windows later says `flutterfire` is not recognised,
add `%LOCALAPPDATA%\Pub\Cache\bin` to your PATH and open a new terminal.

---

## Part 1 — Prepare the project

**1.1 Unzip** the project to a short path with no spaces, for example
`C:\dev\project_altair`, then:

```
cd C:\dev\project_altair
```

*Why:* long or OneDrive paths cause random Android build failures.

**1.2 Create the Android and iOS folders**

```
flutter create --org com.projectaltair --project-name project_altair --platforms=android,ios .
```

*Why:* the zip contains the app code; this adds the standard `android/` and
`ios/` shells around it. It never overwrites existing files. Your Android app
ID becomes `com.projectaltair.project_altair`.

**1.3 Download the packages**

```
flutter pub get
```

*Why:* fetches Firebase, Riverpod and the other libraries listed in
`pubspec.yaml`.

**1.4 Apply the platform settings**

```
node tools/setup-platforms.mjs
```

*Why:* sets the name under the icon to "Project Altair", allows internet in
release builds, and adds the camera / gallery permission texts iOS requires.

**1.5 Generate the app icon and the launch screen**

```
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

*Why:* builds every icon size from the logo, and makes the very first screen
dark teal so there is no white flash before the animated intro.

---

## Part 2 — Create the backend (Firebase, free plan)

**2.1 Create the project.** Open https://console.firebase.google.com →
**Add project** → name it (e.g. `project-altair`) → Google Analytics: off.
The plan shown at the bottom-left must say **Spark** — leave it that way.

*Why:* this is the central database every phone syncs with. Spark is the free
plan; the app needs nothing from the paid one.

**2.2 Switch on password sign-in.** Left menu → Build → **Authentication** →
**Get started** → **Sign-in method** → **Email/Password** → turn on the
**first** switch only → **Save**.

*Why:* members sign in with a User ID and password. Firebase checks the
password and keeps only a scrambled (hashed) copy. Firebase calls this method
"Email/Password"; the app turns a User ID such as `ALT-001` into the internal
name `alt-001@altair.example.com` by itself, so nobody ever types or needs an
e-mail address. (`example.com` is a reserved name that can never receive
mail, so nobody can hijack an account through a "reset e-mail".)

**2.3 Create the database.** Left menu → Build → **Firestore Database** →
**Create database** → (if it asks for an edition, choose **Standard**) →
location **asia-south1 (Mumbai)** → **Start in production mode** → Create.

*Why:* this stores tasks, notes, people and the small profile pictures.
Mumbai is the closest location to Bangladesh, which keeps the app quick.
The location cannot be changed later. "Production mode" keeps the database
locked until your own rules are uploaded in step 2.5.

**2.4 Log in and select the project**

```
firebase login
firebase use --add
```

Pick your project, and type `default` when asked for an alias.

*Why:* tells the command-line tool which project to upload to.

**2.5 Upload the security rules**

```
firebase deploy --only firestore:rules,firestore:indexes
```

*Why:* the rules are what actually stop an unauthorised person reading or
changing data, and what stops a member doing more than their role allows.
Without them the database stays locked and the app shows "permission denied".
This command also checks the rules file for mistakes before uploading it.

**2.6 Create the first administrator**

1. Firebase console → ⚙ **Project settings** → **Service accounts** →
   **Generate new private key**.
2. Save the downloaded file as **`tools/serviceAccountKey.json`**.
3. Run (choose your own ID, a password of 8+ characters, and your name):

```
cd tools
npm install
node admin.js create-admin ALT-001 "ChooseAStrongPassword" "Your Name"
cd ..
```

*Why:* accounts can only be created by an administrator, so the very first
one has to be made from your PC. **Keep `serviceAccountKey.json` on your PC
only and never share it** — it is a master key to the project, and you need
it again whenever a member forgets a password (Part 5). It is already listed
in `.gitignore`, so it will not be uploaded to GitHub.

---

## Part 3 — Link the app to your Firebase project

```
flutterfire configure --platforms=android,ios
```

Choose your project. Accept the suggested app IDs.

*Why:* this overwrites `lib/firebase_options.dart` with your project's
settings. Until you do it, the app shows "Backend not connected".

---

## Part 4 — Run it, check it, build the APK

**4.1 Run on your phone.** Enable *Developer options → USB debugging* on the
Android phone, connect it by USB, then:

```
flutter run
```

Sign in with the administrator ID and password from step 2.6.

**4.2 Ten-minute check (do this once).** Each line exercises a different
security rule. If any step answers **"You do not have permission"**, tell
Claude which step — that points to the exact rule to fix.

1. Shield icon (top right) → **Sub-teams** → add Mechanical, Electrical,
   Software, Autonomous (or your own).
2. **User accounts** → **Create account** for a test member (role Junior).
3. Tasks → **+** → add a task → **START** → **END TASK** → it appears in
   History with start, end and duration.
4. Notes → **+** → publish a note → pin it.
5. Leads → **+** → add a profile card **with a photo**.
6. Profile (your picture, top right) → change your picture → **Change
   password**.
7. Log out, sign in as the test member: the app asks them to choose their own
   password; the shield icon is not there; they cannot edit or delete the
   task and note you made.

**4.3 Build the installable APK**

```
flutter build apk --release
```

The file is `build\app\outputs\flutter-apk\app-release.apk`. Send it to the
team (Drive, WhatsApp, USB); they tap it to install.

*Why this works without a signing key:* Flutter's default release build is
signed with a debug key, which is fine for sharing inside the team. To publish
on Google Play you must create your own key:
https://docs.flutter.dev/deployment/android#signing-the-app

**4.4 iOS**

iOS apps can only be built on a **Mac with Xcode**. On the Mac: repeat Parts
0, 1 and 3, then `cd ios && pod install && cd ..`, open
`ios/Runner.xcworkspace` in Xcode, choose your Team under *Signing &
Capabilities*, and run `flutter build ipa`. A free Apple ID can install the
app on your own iPhone for 7 days at a time; giving it to the whole team
needs the Apple Developer Program (99 USD / year) — that is Apple's fee, not
Firebase's.

---

## Part 5 — Running the team

**Add a member.** In the app: shield icon → User accounts → Create account.
Give the person their User ID and the password shown. The app asks them to
choose their own password the first time they sign in.

**A member forgot their password.** In the app: shield icon → User accounts →
open the member → **Reset password** shows the exact command. Run it on your
PC inside the `tools` folder:

```
node admin.js reset-password ALT-014 "NewTemporaryPassword"
```

*Why on the PC:* on the free plan there is no server of your own, and a phone
app must never contain the master key that can change other people's
passwords. Your PC holds that key (step 2.6), so the reset is done there.

**Someone leaves the team.** Shield icon → User accounts → open the member →
**Disable**. They lose access at once and are signed out.

**The free limits.** Firestore's free plan allows **50,000 reads and 20,000
writes per day** and 1 GB of data. A team of around 50 people using the app
normally stays far below that. If a day ever does run out, the app shows
"Today's free database allowance is used up" and works again after midnight
US Pacific time (early afternoon in Bangladesh); nothing is lost and nothing
is charged. You can watch usage in Firebase console → Firestore → **Usage**.

---

## Part 6 — Optional: try the app without a Firebase project (DEV MODE)

The app can run against Firebase's local emulators on your PC. This needs
**Java 21+** (https://adoptium.net) in addition to Part 0 and Part 1.

Terminal 1:

```
firebase emulators:start --project demo-project-altair
```

Terminal 2:

```
cd tools
npm install
node admin.js create-admin ALT-001 "DevPassword1" "Dev Admin" --emulator
cd ..
flutter run --dart-define=ALTAIR_EMULATORS=true
```

Use the **Android emulator** for this. A **DEV MODE** ribbon is shown in the
corner. Data lives only on your PC and disappears when the emulators stop.

---

## If something goes wrong

| What you see | What to do |
|--------------|-----------|
| `flutter pub get` reports a version conflict | Copy the message to Claude. (The versions are set for Flutter 3.38+.) |
| A compile error in a `.dart` file | Copy the full error text to Claude. |
| App shows **Backend not connected** | Do Part 3, then run again. |
| Sign-in says **"Sign-in is not switched on in Firebase yet"** | Step 2.2 was skipped. |
| Sign-in says **Wrong User ID or password** for the admin | Run step 2.6 again with the same ID — it sets that account's password again. |
| After sign-in: **Profile unavailable** | The account exists but has no profile. Run step 2.6 (admin) or create the member in the app. |
| Everything shows **You do not have permission** | Step 2.5 (rules) was not deployed, or the account was disabled. |
| `node admin.js …` says the key file is missing | Do step 2.6 points 1–2 again. |
| "That picture is too large to store" | Pick a normal JPG photo. Pictures are shrunk to 640 × 640 automatically; only unusual files (large PNG screenshots) are refused. |
| Timer shows a few seconds off after a phone clock change | Pull down to refresh on the Tasks screen — it re-syncs with the server clock. |
