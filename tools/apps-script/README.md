# Notifications and the expense sheet (Google Apps Script)

`Code.gs` runs free in Google Apps Script, inside the Google Sheet that
holds the expense log. It:

- sends closed-app notifications (Android) for new tasks, started and
  completed tasks, important or pinned notes, polls, calendar events and,
  to team leads, new expenses;
- adds every new expense as a row in the **Expenses** tab and copies the
  receipt photo into the Drive folder **Project Altair receipts**.

It checks the database every 10 minutes, and right away when the app
nudges it after a change.

## Set it up (once)

1. Create a Google Sheet named `Project Altair expenses`.
2. In the sheet: **Extensions → Apps Script**. Delete the sample code,
   paste all of `Code.gs`, press **Save**.
3. **Project Settings** (gear icon) → **Script Properties** → **Add script
   property**. Name: `SERVICE_ACCOUNT`. Value: open
   `tools/serviceAccountKey.json` in Notepad, select all, copy, paste.
   **Save script properties**.
4. Back in **Editor**, pick `setup` in the function list and press **Run**.
   Allow the permissions it asks for (Google shows "Google hasn't verified
   this app" for your own scripts: **Advanced → Go to … (unsafe)**).
   The log should end with `Setup finished for project …`.
5. **Deploy → New deployment** → gear → **Web app**. Execute as: **Me**.
   Who has access: **Anyone**. **Deploy**, then copy the **Web app URL**
   (it ends in `/exec`).
6. Paste that URL into `lib/app/config.dart` as `notifyUrl`, then rebuild
   the app.
7. Test: open the app on an Android phone once (allow notifications),
   close it, then run `sendTest` in the Apps Script editor.

## Good to know

- The service account key now also lives in this script's properties.
  Only your Google account can see them. Never paste it into the code.
- Deleting an expense in the app does not remove its sheet row. Use the
  **Paid back** column to mark repayments.
- After changing `Code.gs`, use **Deploy → Manage deployments → Edit →
  Version: New version** so the web app URL keeps working.
- iPhones cannot receive closed-app notifications without the paid Apple
  developer account; in-app alerts still work there.
