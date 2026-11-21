# Project Altair

The operations app of the Project Altair rover team — Android and iOS, one
shared cloud backend, live on every phone.

**To build it, follow [`BUILD_GUIDE.md`](BUILD_GUIDE.md).**

Flutter · Dart · Riverpod · Firebase **free Spark plan** (Authentication and
Firestore only) · Material 3 with a custom design system.

**It needs no paid Firebase plan**: no Cloud Functions, no Cloud Storage, no
billing account.

---

## What is in the app

| Area | What it does |
|------|--------------|
| Startup | 2.4 s intro: the arm mark is revealed dead-centre, a thin 0–100 % counter runs at the bottom, then the counter blurs away and the logo glides to its place on the next screen. |
| Sign-in | User ID + password issued by the administrator. Show/hide password, Remember me, automatic lock-out after repeated wrong tries. No registration screen, no e-mail. New members are asked to choose their own password at first sign-in. |
| **Tasks** — ROVER OPERATIONS | Live board. Add task (+), START and END TASK with **server-recorded** times, live elapsed timer, filters by Active/Completed, sub-team and member. |
| **History** | Every ended task, with start, end, total duration and description. Search, date range, sub-team, member, newest/oldest. |
| **Notes** — TEAM NOTES | Shared noticeboard. Categories, important (orange) and pinned notes, search, sort, edit/delete own notes. |
| **Leads / Seniors / Juniors** | Three separate directories. Cards expand to photo, phone, WhatsApp, Messenger with CALL NOW / WHATSAPP / MESSENGER buttons. Seniors and juniors are grouped into expandable sub-team sections with counts. |
| Profile & settings | Photo, **change password**, stay signed in, live-alert switches, **Dark / Light / System theme**, **liquid-glass strength slider**, reduce motion, haptic feedback, About, Privacy policy, Log out. |
| Admin panel | Accounts (create, role, disable; password reset from the team PC), sub-teams (add, rename, reorder, delete), activity log. |
| Live alerts | New task, task started, task completed, important note — shown as a banner while the app is open; each can be switched off per person. |

Swipe left/right or use the glass pill to move between the six dashboards.
Tablets get a side list and centred content.

### Look and motion

The design language follows the *Planet Jumping* reference, translated to the
team's engineering identity (no space or planet imagery, logo colours only):

- each dashboard opens with an index tag (`[01]`), a **giant condensed title**
  that rises out of a blur, and a strip of key numbers divided by hairlines
  that rise in one after another;
- a **NEXT `[02] HISTORY`** chip and the navigation "travel" through a
  **portal**: a rounded window grows from the control you tapped until it
  fills the screen, then clears to show the new dashboard (swiping stays a
  plain slide);
- the navigation is a glass pill with a **solid orange marker** that follows
  your finger; the icon under it turns dark exactly as far as it is covered;
- **Reduce motion** (Profile → Appearance), or the phone's own "remove
  animations" setting, turns all of this into instant changes.

### Liquid glass

The top bar, navigation, sheets, dialogs and toasts are real blurred glass
with a light rim. List cards only *look* frosted (no live blur) so scrolling
stays smooth. Strength is set in **Profile → Appearance** from *Off* (solid
panels) to *Vivid*; the default is *Subtle* (35 %). The phone's own
"high contrast" accessibility setting also switches the glass to solid.

### Colours and type

Sampled from the logo: teal `#0B1E24`, orange `#F5841C`, white. Every colour
in the app comes from `lib/core/theme/palette.dart`. Type is **Quicksand**
(the closest match to the logo wordmark), **Bebas Neue** for the giant
dashboard titles, and **JetBrains Mono** for timers and IDs so digits do not
jump while a clock ticks.

---

## Who can do what

| Action | Super Admin | Team Lead | Senior | Junior |
|--------|:-:|:-:|:-:|:-:|
| See all dashboards | ✓ | ✓ | ✓ | ✓ |
| Add a task | ✓ | ✓ | ✓ | ✓ |
| START a task | ✓ | ✓ | if responsible or creator | if responsible or creator |
| END a task | ✓ | ✓ | if responsible, starter or creator | same |
| Edit / delete a live task | ✓ | ✓ | – | – |
| Edit / delete a history record | ✓ | – | – | – |
| Publish a note, edit / delete own note | ✓ | ✓ | ✓ | ✓ |
| Pin / unpin any note | ✓ | ✓ | – | – |
| Edit / delete anyone's note | ✓ | – | – | – |
| Add / edit / delete directory profiles | ✓ | ✓ | – | – |
| Sub-teams, accounts, activity log | ✓ | – | – | – |
| Change own photo and password | ✓ | ✓ | ✓ | ✓ |

The app hides what a member may not use, but the real enforcement is on the
server, in `firestore.rules`: every read and write is checked there against
the caller's own account document, which only a Super Admin can create or
change. To change a permission, change it in `lib/data/permissions.dart`
**and** in the rules.

---

## How the important parts work

**Sign-in.** Firebase Authentication checks the password and stores only a
salted hash of it. Its sign-in method is called "Email/Password", so the app
turns a User ID such as `ALT-001` into the internal name
`alt-001@altair.example.com`; members never see or type it, and because
`example.com` is a reserved name no reset e-mail can ever be delivered to
anyone. Being signed in is not enough to see anything: the security rules
also require an account document in `users/`, and only a Super Admin can
create one. Nothing secret is stored in the app.

**Accounts.** A Super Admin creates a member in the app (the new sign-in is
made on a second, short-lived connection so the admin stays signed in),
changes roles and disables accounts — all enforced by the rules. Changing
*someone else's* password needs Google's Admin SDK, which must never be
inside a phone app and, on the free plan, has no server to live on. That one
job is therefore done with `tools/admin.js` on the team PC.

**Pictures.** Stored the same way as in the RFID rickshaw system: shrunk to
at most 640 × 640, JPEG quality 76, saved as a Base64 data URL in the
database — no file-storage service. Each picture is its own document in
`photos/`; profiles hold only a short reference, so lists of people stay
light and a picture is downloaded once per phone and then read from the
phone's cache.

**Live alerts.** With no server there is nobody to send a push message, so
the app compares each live update with the one before and shows a banner for
what teammates just did. This works while the app is open.

**Activity log.** Each phone adds a line after an action. The rules only
accept a line signed with the writer's own account and the server's clock,
and lines can never be edited or deleted.

**Task timing.** START and END run as Firestore transactions. The security
rules only accept them if the start/end time equals the server clock and the
person is allowed to do it, so a phone cannot back-date or forge a time. END
writes the History record and removes the live task in one atomic step. The
timer on screen is always *(server time now − server start time)*, with the
phone's clock error measured once per session, so it stays right after the
app is closed, the phone restarts, or someone else opens the board. Starting
and ending need a connection for exactly this reason.

**Offline.** Everything already loaded stays readable offline. New tasks,
notes and profile edits made offline are saved on the phone and sent when the
connection returns ("Saved on this phone" toast).

**Duplicate taps.** The task, note and profile forms create their document
ID before saving, so a double tap or a retry writes the same record instead
of two.

---

## Project layout

```
lib/
  main.dart                 start-up, Firebase, emulator switch
  app/                      MaterialApp, theme mode, intro -> login -> home gate, logo flight
  core/
    theme/                  palette (dark + light), text styles
    glass/                  GlassSurface, FrostCard, AmbientBackground
    motion/                 easings, Reveal, haptics, reduce-motion switch
    settings/               theme, glass, motion, haptics, alerts, stay signed in
    widgets/                buttons, inputs, sheets, toasts, dialogs, avatar
    utils/                  date/duration formatting, call / WhatsApp / Messenger
    photos.dart             in-memory shelf of decoded profile pictures
  data/
    models/                 AppUser, RoverTask, Note, Member, SubTeam, ActivityLog
    repositories/           auth, tasks, notes, team, admin, photos
    services/               server clock, live alerts
    permissions.dart        the table above, in code
    providers.dart          Riverpod providers (state management)
  features/
    splash/ auth/ shell/ tasks/ history/ notes/ members/ profile/ admin/
firestore.rules             server-side authorisation
tools/admin.js              PC tool: first administrator, password resets
tools/setup-platforms.mjs   platform settings after `flutter create`
```

### Database

```
users/{uid}            account profile, role, disabled flag  (created by Super Admins)
photos/{id}            one small Base64 JPEG each            (read one at a time)
clockSync/{uid}        measures the phone-to-server clock offset
tasks/{taskId}         live tasks: pending / inProgress
taskHistory/{taskId}   completed tasks (permanent)
notes/{noteId}         shared noticeboard
subTeams/{id}          configurable sub-teams
teamLeads/ seniorMembers/ juniorMembers/   three separate directories
activityLogs/{id}      who did what                          (append-only)
```

---

## What it costs

| Item | Cost |
|------|------|
| Firebase **Spark plan** | **Free.** No card. Limits: 50,000 Firestore reads and 20,000 writes per day, 1 GB of data. If a day's allowance runs out the app pauses until it resets (midnight US Pacific time); it never bills. To stay well inside the limits the app loads only what is on screen, keeps pictures out of lists, and pages History 50 records at a time. |
| iPhone build | Needs a Mac; sharing with the whole team needs the Apple Developer Program (99 USD / year). Android has no such cost. |
| Google Play listing | One-time 25 USD, only if you publish there instead of sharing the APK. |

---

## Decisions worth knowing

- **Light mode** was added on request; dark stays the default and the splash
  is always in the dark brand colours.
- **History times are locked.** A Super Admin can correct a record's title,
  description, member or sub-team, or delete it, but nobody can alter the
  server-recorded start and end times.
- **Own profile.** Members change their own photo and password; name,
  position, sub-team and role are set by the administrator.
- **Responsible member** is chosen from the accounts list, so "who may start
  this task" can be enforced by the server.
- **Directory profiles require** photo, name, sub-team, phone, WhatsApp and
  Messenger link, as specified. WhatsApp defaults to the phone number.
- **Phone numbers** typed with a leading 0 are sent to WhatsApp with country
  code 880. Change `defaultCountryCode` in `lib/app/config.dart` if needed.
- **No paid plan, and what that changed.** Three things a server used to do
  are done differently: (1) alerts appear while the app is open — there are
  no push notifications to a closed app, and the "pinned note edited" alert
  was dropped; (2) another member's password is reset from the team PC, not
  from a phone; (3) the activity log is written by the phones (signed and
  append-only) instead of by a server.
- **No registration screen.** The admin's "Create account" button uses
  Firebase's ordinary sign-up call, so that call has to stay open, and a
  technically skilled outsider could create an empty sign-in with it. It is
  useless: without an account document made by a Super Admin the rules
  refuse every read and write.
- **Disabled accounts** lose database access immediately and are signed out.
- **Old profile pictures** of a member are kept so their earlier notes still
  show the picture they were posted with.
- **The Privacy policy text** in the app is a plain description of what the
  app stores. Have it reviewed if the app is published in a store.

## What has and has not been verified

- `tools/admin.js`: 13 checks (bad input, first admin, repeat run, password
  reset) against an in-memory stand-in for Firebase — not a live project.
- `tools/setup-platforms.mjs`: run against sample Android and iOS files.
- Dart app (49 files, ~10,500 lines): parsed for syntax; every constructor
  and top-level function call checked against the Flutter 3.50, Riverpod 3.5,
  FlutterFire and plugin sources for parameter names and required arguments.
  **It has not been compiled or run on a device.**
- Security rules: written and reviewed by hand. **Not run in the Firestore
  emulator** (it could not be downloaded on the machine this was written
  on). `firebase deploy` checks their syntax; the ten-minute check in
  `BUILD_GUIDE.md` step 4.2 exercises each rule on your own project.

## Credits

Fonts: Quicksand, Bebas Neue and JetBrains Mono, SIL Open Font License
(licence files in `assets/fonts/`). Design language adapted from the *Planet
Jumping* reference.

## Author

Md. Mahin Rahman · [github.com/thisisdibbo](https://github.com/thisisdibbo) ·
mr.d2003feb@gmail.com
