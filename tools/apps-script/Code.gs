/**
 * Project Altair - closed-app notifications and the expense Google Sheet.
 *
 * Runs free in Google Apps Script, bound to your expense Google Sheet.
 * Every 10 minutes, and whenever the app nudges it, it looks in the
 * database for anything new since its last look, then:
 *   - sends a notification to the phones listening on that topic, and
 *   - for a new expense, adds a row to the "Expenses" tab and saves the
 *     receipt photo in the Drive folder "Project Altair receipts";
 *   - keeps the "Inventory" tab a copy of the current inventory.
 *
 * Setup (once): see README.md next to this file. In short: add the script
 * property SERVICE_ACCOUNT, run setup(), then deploy as a web app and put
 * its URL in lib/app/config.dart (notifyUrl).
 */

const PROPS = PropertiesService.getScriptProperties();
const TITLE = 'Project Altair';
const SCOPES = [
  'https://www.googleapis.com/auth/datastore',
  'https://www.googleapis.com/auth/firebase.messaging',
  'https://www.googleapis.com/auth/identitytoolkit',
].join(' ');

const EVENT_TYPES = { meeting: 'Meeting', test: 'Test day', deadline: 'Deadline' };

/** What to watch. `key` is also the topic the phones listen on. */
const WATCH = [
  {
    key: 'taskCreated', collection: 'tasks', field: 'createdAt',
    message: (d) => 'New task: ' + d.title,
  },
  {
    key: 'taskStarted', collection: 'tasks', field: 'startedAt',
    message: (d) => d.startedByName + ' started "' + d.title + '"',
  },
  {
    key: 'taskCompleted', collection: 'taskHistory', field: 'endedAt',
    message: (d) => d.endedByName + ' completed "' + d.title + '"',
  },
  {
    key: 'importantNotes', collection: 'notes', field: 'createdAt',
    when: (d) => d.important === true || d.pinned === true,
    message: (d) => d.authorName + ': ' + d.title,
  },
  {
    key: 'newPolls', collection: 'polls', field: 'createdAt',
    message: (d) => 'New poll by ' + d.createdByName + ': ' + d.question,
  },
  {
    key: 'newEvents', collection: 'events', field: 'createdAt',
    message: (d) => (EVENT_TYPES[d.type] || 'Event') + ': ' + d.title +
      ' · ' + Utilities.formatDate(d.at, Session.getScriptTimeZone(), 'd MMM, h:mm a'),
  },
  {
    key: 'newExpenses', collection: 'expenses', field: 'createdAt',
    also: addExpenseRow_,
    message: (d) => d.createdByName + ' logged Tk ' + d.amount + ': ' + d.reason,
  },
];

// ── entry points ─────────────────────────────────────────────────────

/** The app's nudge. Anyone may call it: it only looks for real new data. */
function doPost() {
  run_();
  return ContentService.createTextOutput('ok');
}

/** Open the web app URL in a browser to check it is live. */
function doGet() {
  return ContentService.createTextOutput(TITLE + ' notifier is running.');
}

/** The 10-minute check. */
function tick() {
  run_();
}

/** Run once from the editor after adding the SERVICE_ACCOUNT property. */
function setup() {
  accessToken_();
  PROPS.setProperty('SHEET_ID', SpreadsheetApp.getActiveSpreadsheet().getId());
  expenseSheet_();
  receiptFolder_();
  const now = new Date().toISOString();
  for (const w of WATCH) PROPS.setProperty('wm.' + w.key, now);
  for (const t of ScriptApp.getProjectTriggers()) {
    if (t.getHandlerFunction() === 'tick') ScriptApp.deleteTrigger(t);
  }
  ScriptApp.newTrigger('tick').timeBased().everyMinutes(10).create();
  console.log('Setup finished for project ' + projectId_() + '.');
}

/** Sends one test notification to every phone that has "New tasks" on. */
function sendTest() {
  send_(accessToken_(), 'taskCreated', 'Test: closed-app notifications work.');
  console.log('Test sent.');
}

// ── the check ────────────────────────────────────────────────────────

function run_() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(25000)) return;
  try {
    const token = accessToken_();
    for (const w of WATCH) {
      const prop = 'wm.' + w.key;
      const since = PROPS.getProperty(prop);
      if (!since) {
        PROPS.setProperty(prop, new Date().toISOString());
        continue;
      }
      let docs;
      try {
        docs = query_(token, w.collection, w.field, since);
      } catch (e) {
        console.error(w.key + ': ' + e);
        continue;
      }
      for (const doc of docs) {
        try {
          if (!w.when || w.when(doc.data)) {
            if (w.also) w.also(token, doc);
            send_(token, w.key, w.message(doc.data));
          }
        } catch (e) {
          console.error(w.key + ' ' + doc.id + ': ' + e);
        }
        PROPS.setProperty(prop, doc.mark);
      }
    }
    try {
      syncInventory_(token);
    } catch (e) {
      console.error('inventory: ' + e);
    }
    try {
      removeDeletedLogins_(token);
    } catch (e) {
      console.error('deleted accounts: ' + e);
    }
  } finally {
    lock.releaseLock();
  }
}

/** Documents whose `field` is later than `since`, oldest first. */
function query_(token, collection, field, since) {
  const res = UrlFetchApp.fetch(dbUrl_() + ':runQuery', {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + token },
    muteHttpExceptions: true,
    payload: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: collection }],
        where: {
          fieldFilter: {
            field: { fieldPath: field },
            op: 'GREATER_THAN',
            value: { timestampValue: since },
          },
        },
        orderBy: [{ field: { fieldPath: field }, direction: 'ASCENDING' }],
        limit: 50,
      },
    }),
  });
  if (res.getResponseCode() !== 200) {
    throw new Error('database ' + res.getResponseCode() + ' ' +
      res.getContentText().slice(0, 300));
  }
  return JSON.parse(res.getContentText())
    .filter((row) => row.document)
    .map((row) => ({
      id: row.document.name.split('/').pop(),
      mark: row.document.fields[field].timestampValue,
      data: decode_(row.document.fields),
    }));
}

function send_(token, topic, body) {
  const res = UrlFetchApp.fetch(
    'https://fcm.googleapis.com/v1/projects/' + projectId_() + '/messages:send', {
      method: 'post',
      contentType: 'application/json',
      headers: { Authorization: 'Bearer ' + token },
      muteHttpExceptions: true,
      payload: JSON.stringify({
        message: {
          topic: topic,
          notification: { title: TITLE, body: String(body).slice(0, 240) },
        },
      }),
    });
  if (res.getResponseCode() !== 200) {
    throw new Error('notification ' + res.getResponseCode() + ' ' +
      res.getContentText().slice(0, 300));
  }
}

// ── expense sheet ────────────────────────────────────────────────────

function addExpenseRow_(token, doc) {
  const d = doc.data;
  let receipt = '';
  try {
    receipt = saveReceipt_(token, d.receiptUrl, doc.id);
  } catch (e) {
    console.error('receipt for ' + doc.id + ': ' + e);
  }
  expenseSheet_().appendRow([
    d.createdAt, d.createdByName, d.reason, d.amount, "'" + d.bkash,
    receipt, '', doc.id,
  ]);
}

function expenseSheet_() {
  const book = SpreadsheetApp.openById(PROPS.getProperty('SHEET_ID'));
  let sheet = book.getSheetByName('Expenses');
  if (!sheet) {
    sheet = book.insertSheet('Expenses');
    sheet.appendRow(['Date', 'Member', 'Reason', 'Amount (Tk)', 'bKash',
      'Receipt', 'Paid back', 'Expense ID']);
    sheet.setFrozenRows(1);
    sheet.getRange(1, 1, 1, 8).setFontWeight('bold');
  }
  return sheet;
}

/** Copies the receipt photo from the database into Drive; returns its link. */
function saveReceipt_(token, ref, expenseId) {
  if (!ref || ref.indexOf('db:') !== 0) return '';
  const res = UrlFetchApp.fetch(dbUrl_() + '/photos/' + ref.slice(3), {
    headers: { Authorization: 'Bearer ' + token },
    muteHttpExceptions: true,
  });
  if (res.getResponseCode() !== 200) {
    throw new Error('photo ' + res.getResponseCode());
  }
  const image = JSON.parse(res.getContentText()).fields.image.stringValue;
  const type = image.slice(5, image.indexOf(';'));
  const bytes = Utilities.base64Decode(image.slice(image.indexOf(',') + 1));
  const name = 'receipt-' + expenseId + (type === 'image/png' ? '.png' : '.jpg');
  return receiptFolder_().createFile(Utilities.newBlob(bytes, type, name)).getUrl();
}

function receiptFolder_() {
  const id = PROPS.getProperty('RECEIPT_FOLDER_ID');
  if (id) {
    try {
      return DriveApp.getFolderById(id);
    } catch (e) {
      // Deleted: make a new one below.
    }
  }
  const folder = DriveApp.createFolder('Project Altair receipts');
  PROPS.setProperty('RECEIPT_FOLDER_ID', folder.getId());
  return folder;
}

// ── inventory tab ────────────────────────────────────────────────────

/** Rewrites the "Inventory" tab whenever anything in the inventory changed. */
function syncInventory_(token) {
  const since = PROPS.getProperty('inventory.mark') || '1970-01-01T00:00:00Z';
  const changed = firestoreQuery_(token, {
    from: [{ collectionId: 'inventory' }],
    where: {
      fieldFilter: {
        field: { fieldPath: 'updatedAt' },
        op: 'GREATER_THAN',
        value: { timestampValue: since },
      },
    },
    limit: 1,
  }).length > 0;
  let count = PROPS.getProperty('inventory.count');
  try {
    count = String(countInventory_(token));
  } catch (e) {
    console.error('inventory count: ' + e);
  }
  if (!changed && count === PROPS.getProperty('inventory.count')) return;

  const items = firestoreQuery_(token, {
    from: [{ collectionId: 'inventory' }],
    orderBy: [{ field: { fieldPath: 'name' }, direction: 'ASCENDING' }],
    limit: 1000,
  });
  writeInventory_(items.map((doc) => decode_(doc.fields)));

  let mark = since;
  for (const doc of items) {
    const t = doc.fields.updatedAt && doc.fields.updatedAt.timestampValue;
    if (t && timeKey_(t) > timeKey_(mark)) mark = t;
  }
  PROPS.setProperty('inventory.mark', mark);
  if (count !== null) PROPS.setProperty('inventory.count', count);
}

function writeInventory_(items) {
  const book = SpreadsheetApp.openById(PROPS.getProperty('SHEET_ID'));
  const sheet = book.getSheetByName('Inventory') || book.insertSheet('Inventory');
  const cell = (v) => (v === null || v === undefined ? '' : v);
  const header = ['Item', 'Category', 'Quantity', 'Where kept', 'Status',
    'Taken on', 'Notes'];
  const rows = items.map((d) => [
    cell(d.name), cell(d.category), cell(d.quantity), cell(d.location),
    d.borrowedById ? 'With ' + cell(d.borrowedByName) : 'Available',
    d.borrowedById ? cell(d.borrowedAt) : '',
    cell(d.notes),
  ]);
  sheet.clearContents();
  sheet.getRange(1, 1, 1, header.length).setValues([header]).setFontWeight('bold');
  if (rows.length) sheet.getRange(2, 1, rows.length, header.length).setValues(rows);
  sheet.setFrozenRows(1);
}

/** Raw documents of a query, with their database fields. */
function firestoreQuery_(token, structuredQuery) {
  const res = UrlFetchApp.fetch(dbUrl_() + ':runQuery', {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + token },
    muteHttpExceptions: true,
    payload: JSON.stringify({ structuredQuery: structuredQuery }),
  });
  if (res.getResponseCode() !== 200) {
    throw new Error('database ' + res.getResponseCode() + ' ' +
      res.getContentText().slice(0, 300));
  }
  return JSON.parse(res.getContentText())
    .filter((row) => row.document)
    .map((row) => row.document);
}

/** How many items the inventory has (a cheap count, not a full read). */
function countInventory_(token) {
  const res = UrlFetchApp.fetch(dbUrl_() + ':runAggregationQuery', {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + token },
    muteHttpExceptions: true,
    payload: JSON.stringify({
      structuredAggregationQuery: {
        structuredQuery: { from: [{ collectionId: 'inventory' }] },
        aggregations: [{ alias: 'n', count: {} }],
      },
    }),
  });
  if (res.getResponseCode() !== 200) {
    throw new Error('count ' + res.getResponseCode() + ' ' +
      res.getContentText().slice(0, 300));
  }
  const done = JSON.parse(res.getContentText()).find((part) => part.result);
  return Number(done.result.aggregateFields.n.integerValue);
}

/** Database times compare correctly as text once the fraction has 9 digits. */
function timeKey_(t) {
  const m = /^(.+T\d\d:\d\d:\d\d)(?:\.(\d+))?Z$/.exec(t);
  return m ? m[1] + '.' + (m[2] || '').padEnd(9, '0') : t;
}

// ── Google sign-in with the service account ──────────────────────────

function serviceAccount_() {
  const raw = PROPS.getProperty('SERVICE_ACCOUNT');
  if (!raw) {
    throw new Error('Add the script property SERVICE_ACCOUNT first ' +
      '(the whole serviceAccountKey.json).');
  }
  return JSON.parse(raw);
}

// ── deleted accounts ─────────────────────────────────────────────────
// The app deletes an account and its cards itself. On the free plan a
// phone cannot delete somebody else's sign-in, so it leaves a note in
// accountDeletions; this removes the sign-in with the team's key, which
// frees the User ID, and then removes the note.

function removeDeletedLogins_(token) {
  const notes = firestoreQuery_(token, {
    from: [{ collectionId: 'accountDeletions' }],
    limit: 20,
  });
  for (const note of notes) {
    const uid = note.name.split('/').pop();
    const res = UrlFetchApp.fetch(
      'https://identitytoolkit.googleapis.com/v1/projects/' + projectId_() +
        '/accounts:delete', {
        method: 'post',
        contentType: 'application/json',
        headers: { Authorization: 'Bearer ' + token },
        muteHttpExceptions: true,
        payload: JSON.stringify({ localId: uid }),
      });
    const gone = res.getResponseCode() === 200 ||
      res.getContentText().indexOf('USER_NOT_FOUND') >= 0;
    if (!gone) {
      console.error('delete sign-in ' + uid + ': ' + res.getResponseCode() +
        ' ' + res.getContentText().slice(0, 300));
      continue;
    }
    UrlFetchApp.fetch('https://firestore.googleapis.com/v1/' + note.name, {
      method: 'delete',
      headers: { Authorization: 'Bearer ' + token },
      muteHttpExceptions: true,
    });
  }
}

function projectId_() {
  return serviceAccount_().project_id;
}

function dbUrl_() {
  return 'https://firestore.googleapis.com/v1/projects/' + projectId_() +
    '/databases/(default)/documents';
}

function accessToken_() {
  const cache = CacheService.getScriptCache();
  const cached = cache.get('token2');
  if (cached) return cached;

  const key = serviceAccount_();
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) => Utilities.base64EncodeWebSafe(
    typeof value === 'string' ? value : JSON.stringify(value)).replace(/=+$/, '');
  const unsigned = encode({ alg: 'RS256', typ: 'JWT' }) + '.' + encode({
    iss: key.client_email,
    scope: SCOPES,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  });
  const signature = Utilities.base64EncodeWebSafe(
    Utilities.computeRsaSha256Signature(unsigned, key.private_key)).replace(/=+$/, '');

  const res = UrlFetchApp.fetch('https://oauth2.googleapis.com/token', {
    method: 'post',
    muteHttpExceptions: true,
    payload: {
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: unsigned + '.' + signature,
    },
  });
  if (res.getResponseCode() !== 200) {
    throw new Error('Google sign-in failed: ' + res.getContentText().slice(0, 300));
  }
  const token = JSON.parse(res.getContentText()).access_token;
  cache.put('token2', token, 3000);
  return token;
}

// ── reading database values ──────────────────────────────────────────

function decode_(fields) {
  const out = {};
  for (const name in fields) out[name] = value_(fields[name]);
  return out;
}

function value_(v) {
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('mapValue' in v) return decode_(v.mapValue.fields || {});
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(value_);
  return null;
}
