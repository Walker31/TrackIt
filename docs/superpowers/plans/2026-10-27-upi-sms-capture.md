# UPI SMS Auto-Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On Android, turn bank UPI transaction SMS into suggested transactions the user confirms with one tap.

**Architecture:** A pure-Dart parser turns an SMS into a `ParsedSmsTxn`; a local store keeps parsed captures (deduplicated) and payee→category rules; a service ties an `SmsSource` (a Kotlin channel on Android, a no-op elsewhere) to the store and to `ExpenseProvider`; a provider and two widgets expose opt-in and review. Accepted captures become ordinary `Expense` rows, so existing sync handles them.

**Tech Stack:** Flutter (Dart ^3.11), sqflite, Riverpod `ChangeNotifierProvider`, Kotlin `MethodChannel`/`EventChannel`, `permission_handler`.

**Spec:** `docs/superpowers/specs/2026-10-27-upi-sms-capture-design.md`

## Global Constraints

- Android only: everything is hidden/no-op when `kIsWeb || defaultTargetPlatform != TargetPlatform.android`.
- Manifest permissions: `android.permission.READ_SMS`, `android.permission.RECEIVE_SMS`. Never `SEND_SMS`.
- The SMS body is never persisted, logged, or sent anywhere; only parsed fields are stored.
- Opt-in, default off. Settings keys: `sms_capture_enabled` (`'1'`/`'0'`), `sms_capture_checkpoint` (milliseconds since epoch, as a string).
- Captures and payee rules are local-only: not in `DatabaseService._syncedTables`, never sent to the API.
- Accepted captures are saved with `paymentMethod: PaymentMethod.upi`, `timestamp` = SMS time, `description` = payee.
- Business sender IDs match `^[A-Z]{2}-[A-Z0-9]{3,8}(-[STG])?$` (a `-P` promotional suffix is rejected).
- Dedupe key: `upi:<ref>:<type>` when a UPI reference exists, else `sms:<sender>:<receivedAtMillis>:<amount>`.
- No new SMS plugin; add only `permission_handler` to `pubspec.yaml`.
- Commit messages end without a Claude co-author line (repo owner preference).

## Review Focus

1. **Transfer between the user's own accounts** (same UPI ref, one debit SMS, one credit SMS) → two captures, both reviewable/dismissable. Pinned in Task 2 (`own-account transfer keeps both directions`).
2. **The same SMS seen by the live listener and again by the next inbox scan** → exactly one capture. Pinned in Task 3 (`a message seen twice is captured once`).
3. **Non-transaction SMS that mention rupees** (OTP, collect request, bill due, autopay "will be debited", promotions, personal numbers) → no capture. Pinned in Task 1 (the six `ignores …` tests).
4. **SMS permission revoked in system settings after opting in** → scans quietly return 0, the app keeps working, Settings shows the toggle as needing permission. Pinned in Task 3 (`revoked permission makes scan a no-op`).
5. **A payment the user already typed in manually** → the capture is flagged "Possible duplicate" instead of silently creating a second expense. Pinned in Task 2 (`flags a capture that matches an existing expense`).

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/services/sms/upi_sms_parser.dart` (new) | `RawSms`, `ParsedSmsTxn`, `UpiSmsParser.parse` — pure Dart, no I/O |
| `lib/services/sms/capture_store.dart` (new) | `CapturedTxn`, `CaptureStatus`, schema, dedupe insert, review queries, payee rules |
| `lib/services/sms/sms_source.dart` (new) | `SmsSource` interface, `PlatformSmsSource` (channels + `permission_handler`), `UnsupportedSmsSource` |
| `lib/services/sms/sms_capture_service.dart` (new) | Settings, checkpoint, scan/listen, draft building, accept/dismiss |
| `android/app/src/main/kotlin/com/trackit/app/MainActivity.kt` | `trackit/sms` inbox query + `trackit/sms/incoming` live receiver |
| `android/app/src/main/AndroidManifest.xml` | The two SMS permissions |
| `lib/services/database_service.dart` | Call `CaptureStore.ensureSchema`; clear capture tables in `clearAllData` |
| `lib/providers/sms_capture_provider.dart` (new) | UI state: supported, enabled, pending, suggestions, duplicates |
| `lib/providers/expense_provider.dart` | `addExpense` returns the saved `Expense` |
| `lib/providers/app_providers.dart` | `smsCaptureProviderProvider` |
| `lib/layout.dart` | Refresh captures on app resume |
| `lib/pages/settings_page.dart` | Opt-in toggle + import-range dialog |
| `lib/widgets/wallet/capture_review_card.dart` (new) | "N payments to review" card + review sheet |
| `lib/pages/wallet_screen.dart` | Show the card above Financial Analysis |
| `lib/widgets/wallet/add_expense_sheet.dart` | Pre-fill without switching to edit mode |

---

### Task 1: SMS parser

**Files:**
- Create: `lib/services/sms/upi_sms_parser.dart`
- Test: `test/services/sms/upi_sms_parser_test.dart`

**Interfaces:**
- Consumes: `TxnType` from `lib/models/expenses.dart`.
- Produces:
  - `class RawSms { final int? id; final String sender; final String body; final DateTime receivedAt; const RawSms({this.id, required this.sender, required this.body, required this.receivedAt}); }`
  - `class ParsedSmsTxn { final String sender; final DateTime receivedAt; final double amount; final TxnType type; final String? payee; final String? upiRef; final String? accountLast4; String get dedupeKey; }`
  - `class UpiSmsParser { static ParsedSmsTxn? parse(RawSms sms); static bool isBusinessSender(String sender); }`

The fixtures below are modelled on common Indian bank formats. Before finishing, add two or three real messages from your own phone (amounts and refs changed) as extra cases.

- [ ] **Step 1: Write the failing tests**

```dart
RawSms sms(String sender, String body) =>
    RawSms(sender: sender, body: body, receivedAt: DateTime(2026, 10, 27, 13, 45));

void expectTxn(ParsedSmsTxn? t, {required double amount, required TxnType type,
    String? payee, String? ref, String? last4}) {
  expect(t, isNotNull);
  expect(t!.amount, amount);
  expect(t.type, type);
  expect(t.payee, payee);
  expect(t.upiRef, ref);
  expect(t.accountLast4, last4);
}

test('HDFC debit', () => expectTxn(UpiSmsParser.parse(sms('VM-HDFCBK-S',
    'Sent Rs.250.00\nFrom HDFC Bank A/C *1234\nTo SWIGGY\nOn 27/10/26\nRef 430012345678\nNot You?\nCall 18002586161/SMS BLOCK UPI to 7308080808')),
  amount: 250.0, type: TxnType.expense, payee: 'SWIGGY', ref: '430012345678', last4: '1234'));

test('SBI debit without a currency symbol', () => expectTxn(UpiSmsParser.parse(sms('JD-SBIUPI-S',
    'Dear UPI user A/C X5678 debited by 1,250.5 on date 27Oct26 trf to RAHUL KUMAR Refno 430098765432. If not u? call 1800111109. -SBI')),
  amount: 1250.5, type: TxnType.expense, payee: 'RAHUL KUMAR', ref: '430098765432', last4: '5678'));

test('ICICI debit naming the payee before "credited"', () => expectTxn(UpiSmsParser.parse(sms('AX-ICICIT-S',
    'ICICI Bank Acct XX901 debited for Rs 99.00 on 27-Oct-26; ZOMATO credited. UPI:430011112222. Call 18002662 for dispute. SMS BLOCK 901 to 9215676766.')),
  amount: 99.0, type: TxnType.expense, payee: 'ZOMATO', ref: '430011112222', last4: '901'));

test('Kotak debit to a VPA with lakh grouping', () => expectTxn(UpiSmsParser.parse(sms('VK-KOTAKB-S',
    'Sent Rs.1,25,000.00 from Kotak Bank AC X4321 to landlord@okaxis on 27-10-26.UPI Ref 430033334444. Not you, https://kotak.com/KBANKT/Fraud')),
  amount: 125000.0, type: TxnType.expense, payee: 'landlord@okaxis', ref: '430033334444', last4: '4321'));

test('HDFC credit from a VPA', () => expectTxn(UpiSmsParser.parse(sms('VM-HDFCBK-S',
    'Rs.500.00 credited to HDFC Bank A/c XX1234 on 27-10-26 by VPA friend@oksbi (UPI Ref No 430055556666).')),
  amount: 500.0, type: TxnType.income, payee: 'friend@oksbi', ref: '430055556666', last4: '1234'));

test('Axis debit in UPI/P2M/<ref>/<payee> form', () => expectTxn(UpiSmsParser.parse(sms('BZ-AXISBK-S',
    'INR 340.00 debited\nA/c no. XX7788\n27-10-26, 13:45:10\nUPI/P2M/430077778888/UBER INDIA\nNot you? SMS BLOCKUPI Cust ID to 919951860002\nAxis Bank')),
  amount: 340.0, type: TxnType.expense, payee: 'UBER INDIA', ref: '430077778888', last4: '7788'));

test('ignores OTP messages', () => expect(UpiSmsParser.parse(sms('AD-HDFCBK-S',
    '123456 is OTP for txn of Rs.250.00 at SWIGGY on HDFC Bank card ending 1234. Valid till 13:50. Do not share OTP')), isNull));
test('ignores collect requests', () => expect(UpiSmsParser.parse(sms('AX-PAYTMB-S',
    'RAHUL has requested Rs.300 from you on Paytm. Pay now: https://p.paytm.me/xyz')), isNull));
test('ignores bill-due reminders', () => expect(UpiSmsParser.parse(sms('VM-HDFCBK-S',
    'Payment of Rs.4,560.00 is due on your HDFC Bank Credit Card XX9012 by 05-11-26. Minimum amount due Rs.230.00.')), isNull));
test('ignores autopay notices', () => expect(UpiSmsParser.parse(sms('VM-ICICIT-S',
    'Rs 199.00 will be debited from your A/c XX901 on 01-11-26 towards NETFLIX mandate.')), isNull));
test('ignores promotional senders', () => expect(UpiSmsParser.parse(sms('VM-SWIGGY-P',
    'Get 50% off up to Rs.100 credited as cashback on your next order! Use code TREAT.')), isNull));
test('ignores personal numbers', () => expect(UpiSmsParser.parse(sms('+919876543210',
    'Sent Rs.250 to you on GPay')), isNull));

test('dedupe key uses ref and direction', () {
  final t = UpiSmsParser.parse(sms('VM-HDFCBK-S',
      'Rs.500.00 credited to HDFC Bank A/c XX1234 on 27-10-26 by VPA friend@oksbi (UPI Ref No 430055556666).'))!;
  expect(t.dedupeKey, 'upi:430055556666:income');
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/sms/upi_sms_parser_test.dart`
Expected: FAIL — `upi_sms_parser.dart` does not exist.

- [ ] **Step 3: Implement `UpiSmsParser.parse(RawSms sms) -> ParsedSmsTxn?`**

Order: reject non-business senders (Global Constraints regex) → reject if the body (lower-cased) contains any of `otp`, `one time password`, `has requested`, `will be debited`, `is due`, `amount due`, `due on` → find the amount (first of `(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)` or `debited by\s*([\d,]+(?:\.\d{1,2})?)`, commas stripped) → type from whichever of the debit words (`debited`, `sent`, `paid`, `spent`, `withdrawn`) or credit words (`credited`, `received`, `deposited`) appears **first** in the body; neither → `null`. Ref: a 12-digit number after `ref`, `ref no`, `refno`, `upi`, `upi ref` or `rrn`, or inside `UPI/P2[AM]/(\d{12})/`. Last digits: `(?:a/?c|acct|account)\s*(?:no\.?)?\s*[*xX]+(\d{3,4})`. Payee, first match of: VPA after `to`/`by vpa`/`by`; text between `To`/`trf to`/`to` and the next `on`/`ref`/newline; text between `;` and `credited`; the segment after `UPI/P2[AM]/<ref>/`. Trim payees.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/sms/upi_sms_parser_test.dart`
Expected: PASS (13 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/sms/upi_sms_parser.dart test/services/sms/upi_sms_parser_test.dart
git commit -m "Add on-device parser for bank UPI transaction SMS"
```

---

### Task 2: Capture store and payee rules

**Files:**
- Create: `lib/services/sms/capture_store.dart`
- Modify: `lib/services/database_service.dart` (`_ensureCompatibleSchema`: call `CaptureStore.ensureSchema(db)` next to `SyncOutbox.ensureSchema(db)`; `clearAllData`: delete both new tables)
- Test: `test/services/sms/capture_store_test.dart`

**Interfaces:**
- Consumes: `ParsedSmsTxn` (Task 1); `DatabaseService.openInMemoryForTesting()`.
- Produces:
  - `enum CaptureStatus { pending, accepted, dismissed }`
  - `class CapturedTxn { final int id; final String sender; final DateTime receivedAt; final double amount; final TxnType type; final String? payee; final String? upiRef; final String? accountLast4; final CaptureStatus status; final int? expenseId; }`
  - `class CaptureStore` with `static const capturesTable = 'captured_transactions'`, `static const rulesTable = 'payee_rules'`, and:
    - `static Future<void> ensureSchema(DatabaseExecutor db)`
    - `Future<bool> insertIfNew(ParsedSmsTxn t)` — true when a row was added
    - `Future<List<CapturedTxn>> pending()` — newest `received_at` first
    - `Future<void> markAccepted(int captureId, int expenseId)`
    - `Future<void> dismiss(int captureId)`
    - `Future<void> learn(String payee, String categoryId)`
    - `Future<String?> suggestCategory(String? payee)`
    - `Future<bool> looksAlreadyLogged(CapturedTxn c)`
    - `static String payeeKey(String payee)` — lower-case, trimmed, internal whitespace collapsed

Schema (copy exactly):

```sql
CREATE TABLE IF NOT EXISTS captured_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dedupe_key TEXT NOT NULL UNIQUE,
  sender TEXT NOT NULL,
  received_at TEXT NOT NULL,
  amount REAL NOT NULL,
  type TEXT NOT NULL,
  payee TEXT,
  upi_ref TEXT,
  account_last4 TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'dismissed')),
  expense_id INTEGER REFERENCES expenses(id) ON DELETE SET NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS payee_rules (
  payee_key TEXT PRIMARY KEY,
  category_id TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

- [ ] **Step 1: Write the failing tests**

```dart
// setUp: db = await DatabaseService.openInMemoryForTesting(); store = CaptureStore();
// parsed(...) builds a ParsedSmsTxn via UpiSmsParser.parse on a fixture from Task 1.

test('inserting the same transaction twice stores it once', () async {
  expect(await store.insertIfNew(hdfcDebit), isTrue);
  expect(await store.insertIfNew(hdfcDebit), isFalse);
  expect(await store.pending(), hasLength(1));
});

test('own-account transfer keeps both directions', () async {
  // Debit and credit SMS that share UPI ref 430099990000.
  await store.insertIfNew(debitWithRef('430099990000'));
  await store.insertIfNew(creditWithRef('430099990000'));
  expect((await store.pending()).map((c) => c.type),
      unorderedEquals([TxnType.expense, TxnType.income]));
});

test('accepted and dismissed captures leave the review queue', () async {
  await store.insertIfNew(hdfcDebit);
  await store.insertIfNew(axisDebit);
  final [first, second] = await store.pending();
  final expenseId = await db.insert('expenses', /* any valid Expense.toMap() */);
  await store.markAccepted(first.id, expenseId);
  await store.dismiss(second.id);
  expect(await store.pending(), isEmpty);
});

test('learned payees suggest their category, case-insensitively', () async {
  await store.learn('SWIGGY', 'cat-food');
  expect(await store.suggestCategory('Swiggy '), 'cat-food');
  expect(await store.suggestCategory('ZOMATO'), isNull);
  expect(await store.suggestCategory(null), isNull);
});

test('flags a capture that matches an existing expense', () async {
  await store.insertIfNew(hdfcDebit); // ₹250 expense on 27 Oct 2026
  final capture = (await store.pending()).single;
  expect(await store.looksAlreadyLogged(capture), isFalse);
  // A manually typed ₹250 expense later the same day.
  await db.insert('expenses', /* Expense(amount: 250, timestamp: 27 Oct 2026 20:00).toMap() */);
  expect(await store.looksAlreadyLogged(capture), isTrue);
});

test('clearAllData empties captures and rules', () async {
  await store.insertIfNew(hdfcDebit);
  await store.learn('SWIGGY', 'cat-food');
  await DatabaseService().clearAllData();
  expect(await store.pending(), isEmpty);
  expect(await store.suggestCategory('SWIGGY'), isNull);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/sms/capture_store_test.dart`
Expected: FAIL — `capture_store.dart` does not exist.

- [ ] **Step 3: Implement `CaptureStore`** — `insertIfNew` uses `ConflictAlgorithm.ignore` on `dedupe_key` and returns `id > 0`; `looksAlreadyLogged` matches `expenses` with equal `amount`, equal `type`, and `timestamp` in `[startOfDay, startOfNextDay)` of the capture's local date; `learn` upserts with `ConflictAlgorithm.replace`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/sms/capture_store_test.dart`
Expected: PASS (6 tests). Also run `flutter test` — all existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add lib/services/sms/capture_store.dart lib/services/database_service.dart test/services/sms/capture_store_test.dart
git commit -m "Store parsed SMS captures and learned payee categories locally"
```

---

### Task 3: Capture service

**Files:**
- Create: `lib/services/sms/sms_source.dart` (interface + `UnsupportedSmsSource` only; the platform class comes in Task 4)
- Create: `lib/services/sms/sms_capture_service.dart`
- Test: `test/services/sms/sms_capture_service_test.dart`

**Interfaces:**
- Consumes: Tasks 1–2; `Expense`, `Category`, `PaymentMethod`, `defaultCategories` from `lib/models/expenses.dart`.
- Produces:
  - `abstract class SmsSource { Future<bool> hasPermission(); Future<bool> requestPermission(); Future<List<RawSms>> inboxSince(DateTime since); Stream<RawSms> incoming(); }`
  - `class UnsupportedSmsSource implements SmsSource` (false / empty / `Stream.empty()`)
  - `enum EnableResult { enabled, permissionDenied, unsupported }`
  - `class SmsCaptureService` — `SmsCaptureService({SmsSource? source, CaptureStore? store})` (defaults: `SmsSource.forPlatform()` from Task 4, `CaptureStore()`), with:
    - `Future<bool> isEnabled()`
    - `Future<EnableResult> enable({required Duration importWindow})` — `Duration.zero` means "just new messages"
    - `Future<void> disable()` — keeps existing captures
    - `Future<int> scan()` — returns the number of new captures
    - `StreamSubscription<RawSms> listen(void Function() onNewCapture)`
    - `Expense draftFor(CapturedTxn c, {Category? category})`
    - `Future<void> markAccepted(CapturedTxn c, Expense saved)` — `store.markAccepted` + `store.learn(payee, saved.categoryId!)` when both are non-null
    - `Future<void> dismiss(CapturedTxn c)`

Until Task 4 lands, make `SmsCaptureService`'s default `source` `UnsupportedSmsSource()`; Task 4 switches it to `SmsSource.forPlatform()`.

- [ ] **Step 1: Write the failing tests** (with a `FakeSmsSource` that holds `List<RawSms> inbox`, a `StreamController<RawSms> live`, and a mutable `bool granted`; helpers `hdfcAt(DateTime)` / `axisAt(DateTime)` return `RawSms` with the Task 1 HDFC-debit / Axis-debit fixture bodies at that time; `setUp` opens the in-memory DB and defines `now = DateTime.now()` and `food` = the `Food & Dining` default category)

```dart
test('enable with denied permission stays off', () async {
  source.granted = false;
  expect(await service.enable(importWindow: const Duration(days: 30)),
      EnableResult.permissionDenied);
  expect(await service.isEnabled(), isFalse);
});

test('enable imports only the chosen window', () async {
  source.inbox = [hdfcAt(now.subtract(const Duration(days: 10))),
                  axisAt(now.subtract(const Duration(days: 45)))];
  await service.enable(importWindow: const Duration(days: 30));
  expect((await store.pending()).map((c) => c.amount), [250.0]);
});

test('scan only reads messages after the checkpoint', () async {
  await service.enable(importWindow: Duration.zero);
  source.inbox = [hdfcAt(now.add(const Duration(minutes: 1)))];
  expect(await service.scan(), 1);
  expect(await service.scan(), 0);
});

test('a message seen twice is captured once', () async {
  await service.enable(importWindow: Duration.zero);
  var notified = 0;
  service.listen(() => notified++);
  final msg = hdfcAt(now.add(const Duration(minutes: 1)));
  source.live.add(msg);
  await pumpEventQueue();
  source.inbox = [msg];
  await service.scan();
  expect(notified, 1);
  expect(await store.pending(), hasLength(1));
});

test('revoked permission makes scan a no-op', () async {
  await service.enable(importWindow: Duration.zero);
  source.granted = false;
  source.inbox = [hdfcAt(now.add(const Duration(minutes: 1)))];
  expect(await service.scan(), 0);
});

test('disabled capture does not scan', () async {
  source.inbox = [hdfcAt(now)];
  expect(await service.scan(), 0);
});

test('draft is a UPI transaction at the SMS time', () async {
  await store.insertIfNew(UpiSmsParser.parse(hdfcAt(now))!);
  final c = (await store.pending()).single;
  final food = defaultCategories.firstWhere((x) => x.name == 'Food & Dining');
  final d = service.draftFor(c, category: food);
  expect([d.id, d.amount, d.type, d.paymentMethod, d.timestamp, d.description, d.categoryId],
      [null, 250.0, TxnType.expense, PaymentMethod.upi, c.receivedAt, 'SWIGGY', food.id]);
});

test('accepting learns the payee category', () async {
  await store.insertIfNew(UpiSmsParser.parse(hdfcAt(now))!);
  final c = (await store.pending()).single;
  final saved = await ExpenseService().addExpense(service.draftFor(c, category: food));
  await service.markAccepted(c, saved);
  expect(await store.pending(), isEmpty);
  expect(await store.suggestCategory('SWIGGY'), food.id);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/sms/sms_capture_service_test.dart`
Expected: FAIL — files do not exist.

- [ ] **Step 3: Implement `SmsSource`, `UnsupportedSmsSource` and `SmsCaptureService`** — settings via the `settings` table keys in Global Constraints; `enable` sets checkpoint to `now - importWindow` before its first `scan`; `scan` advances the checkpoint to the newest `receivedAt` it read (unchanged when none); `draftFor` without a category uses the `Miscellaneous` default for expenses and the first default income category for income, and sets `category: category.legacy`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/sms/sms_capture_service_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/sms/sms_source.dart lib/services/sms/sms_capture_service.dart test/services/sms/sms_capture_service_test.dart
git commit -m "Add SMS capture service with checkpointed scans and live listening"
```

---

### Task 4: Android SMS channel

**Files:**
- Modify: `android/app/src/main/kotlin/com/trackit/app/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml` (add the two `<uses-permission>` lines after `INTERNET`)
- Modify: `lib/services/sms/sms_source.dart` (add `PlatformSmsSource`, `SmsSource.forPlatform()`)
- Modify: `lib/services/sms/sms_capture_service.dart` (default source → `SmsSource.forPlatform()`)
- Modify: `pubspec.yaml` (`permission_handler`, latest stable at implementation time)

**Interfaces:**
- Consumes: `SmsSource`, `RawSms`.
- Produces: `factory SmsSource.forPlatform()` — `PlatformSmsSource()` on Android (not web), else `UnsupportedSmsSource()`.
- Channel contract (both sides must match):
  - `MethodChannel('trackit/sms')`, method `inboxSince`, args `{'sinceMs': int}` → `List<Map>` of `{'id': int, 'address': String, 'body': String, 'date': int}` from `Telephony.Sms.Inbox.CONTENT_URI`, `date > sinceMs`, ordered `date ASC`, at most 2000 rows.
  - `EventChannel('trackit/sms/incoming')` → one map per received SMS with the same keys (`id` null); multipart messages joined per sender; `date` = `SmsMessage.timestampMillis`.

- [ ] **Step 1: Implement the Kotlin side in `MainActivity.configureFlutterEngine`** — the inbox query runs off the main thread and replies on it; the `EventChannel` `StreamHandler` registers a `BroadcastReceiver` for `Telephony.Sms.Intents.SMS_RECEIVED_ACTION` in `onListen` with `ContextCompat.registerReceiver(..., android.Manifest.permission.BROADCAST_SMS, null, ContextCompat.RECEIVER_EXPORTED)` and unregisters in `onCancel`; never log message bodies.

- [ ] **Step 2: Implement `PlatformSmsSource`** — `hasPermission`/`requestPermission` use `Permission.sms` from `permission_handler`; `inboxSince` and `incoming` map channel maps to `RawSms` (`receivedAt` from `date` ms).

- [ ] **Step 3: Verify it builds and analyzes**

Run: `flutter analyze` → `No issues found!`
Run: `flutter build apk --debug` → `√ Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 4: Verify on a phone** (install the debug APK; temporary debug button or `flutter run` with a breakpoint is fine, remove before committing)

Check: the permission prompt appears once; `inboxSince(30 days ago)` returns your recent bank SMS; a new bank SMS arrives on `incoming()` while the app is open; denying permission makes `hasPermission()` false without crashing.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/trackit/app/MainActivity.kt android/app/src/main/AndroidManifest.xml lib/services/sms/ pubspec.yaml pubspec.lock
git commit -m "Read and receive SMS on Android through a small platform channel"
```

---

### Task 5: Provider and app wiring

**Files:**
- Create: `lib/providers/sms_capture_provider.dart`
- Modify: `lib/providers/expense_provider.dart` (`Future<Expense> addExpense(Expense expense)` returns the saved expense; callers unchanged)
- Modify: `lib/providers/app_providers.dart`
- Modify: `lib/layout.dart` (`WidgetsBindingObserver`: on `AppLifecycleState.resumed` call `ref`'s capture provider `refresh()`; `Layout` becomes a `ConsumerStatefulWidget`)
- Test: `test/providers/sms_capture_provider_test.dart`

**Interfaces:**
- Consumes: `SmsCaptureService`, `CaptureStore`, `ExpenseProvider.addExpense`.
- Produces:
  - `final smsCaptureProviderProvider = ChangeNotifierProvider<SmsCaptureProvider>((ref) => SmsCaptureProvider(expenses: ref.read(expenseProviderProvider)));`
  - `class SmsCaptureProvider extends ChangeNotifier` — `SmsCaptureProvider({required ExpenseProvider expenses, SmsCaptureService? service, CaptureStore? store, bool? supported})`; getters `bool supported`, `bool enabled`, `bool permissionMissing` (enabled but `hasPermission()` is false), `List<CapturedTxn> pending`, `Category? suggestionFor(CapturedTxn c)`, `bool isPossibleDuplicate(CapturedTxn c)`; methods `Future<void> refresh()`, `Future<EnableResult> enable(Duration importWindow)`, `Future<void> disable()`, `Future<bool> quickAccept(CapturedTxn c)` (false when there is no suggestion), `Future<void> acceptEdited(CapturedTxn c, Expense edited)`, `Future<void> dismiss(CapturedTxn c)`. While enabled it holds a `listen` subscription that calls `refresh()`; it is cancelled in `dispose` and `disable`.

- [ ] **Step 1: Write the failing tests** (in-memory DB, `FakeSmsSource` from Task 3 moved to `test/services/sms/fake_sms_source.dart`, `supported: true`)

```dart
test('refresh loads pending captures with suggestions and duplicate flags', () async { /* learn SWIGGY→food, insert HDFC capture and a same-day ₹250 expense; expect suggestionFor(...)?.id == food.id and isPossibleDuplicate(...) */ });
test('quickAccept adds the expense to the month and empties the queue', () async { /* expect expenses.monthExpenses has the ₹250 UPI row; pending is empty */ });
test('quickAccept without a suggestion does nothing', () async { /* returns false; pending unchanged */ });
test('acceptEdited saves the edited amount and learns its category', () async { /* edited amount 260, travel category → monthExpenses has 260; suggestCategory(payee) == travel.id */ });
test('unsupported platform never scans', () async { /* supported: false → enable returns EnableResult.unsupported, pending empty */ });
test('revoked permission is reported, not thrown', () async { /* enable, then source.granted = false; refresh() completes; permissionMissing == true; enabled stays true */ });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/providers/sms_capture_provider_test.dart`
Expected: FAIL — provider does not exist.

- [ ] **Step 3: Implement the provider, the `addExpense` return value, the Riverpod provider and the resume hook**

`supported` defaults to `!kIsWeb && defaultTargetPlatform == TargetPlatform.android`. The constructor calls `refresh()` (so captures are scanned when the app opens). Categories for suggestions come from `CatalogService().getCategories()`.

- [ ] **Step 4: Run all tests**

Run: `flutter test`
Expected: all pass, including the 6 new tests.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/ lib/layout.dart test/providers/sms_capture_provider_test.dart test/services/sms/
git commit -m "Expose SMS captures to the app and refresh them on resume"
```

---

### Task 6: Opt-in and review UI

**Files:**
- Create: `lib/widgets/wallet/capture_review_card.dart` (`CaptureReviewCard` + private review sheet)
- Modify: `lib/pages/wallet_screen.dart` (card at the top of the Personal tab's left column, before "Financial Analysis")
- Modify: `lib/pages/settings_page.dart` ("Data & Sync" section, Android only)
- Modify: `lib/widgets/wallet/add_expense_sheet.dart` (`_editing => widget.initial?.id != null`, so a draft without an id pre-fills while keeping "Add expense" / "Save ₹… expense")
- Test: `test/widgets/capture_review_card_test.dart`

**Interfaces:**
- Consumes: `SmsCaptureProvider` (Task 5), `AddExpenseSheet(initial:, onAdd:)`, `confirmDestructive` is **not** used for dismiss (it is reversible-feeling and frequent).
- Produces: `class CaptureReviewCard extends ConsumerWidget` (renders `SizedBox.shrink()` when unsupported, disabled, or nothing pending).

UI copy (exact):
- Settings tile title: `Auto-capture UPI payments`; subtitle: `Reads bank SMS on this phone to suggest expenses. Messages never leave your device.`
- Import dialog title: `Import recent payments?`; options: `Just new messages`, `Last 30 days`, `Last 90 days`.
- Permission denied snackbar: `SMS permission is needed to capture payments.` with action `Open settings` (`openAppSettings()`).
- When `permissionMissing`: the tile subtitle becomes `SMS permission was turned off. Tap to allow it again.` and tapping the tile calls `enable(Duration.zero)`.
- Card: `1 payment to review` / `N payments to review`; button `Review`.
- Row badge: `Possible duplicate`; empty category chip: `Pick category`.
- Actions: check icon tooltip `Add`, close icon tooltip `Dismiss`; tapping the row opens the add-expense sheet pre-filled (`draftFor`).
- After adding: success toast `<formatRupees(amount)> added to <category name>.` (`aboveNav: true`).

- [ ] **Step 1: Write the failing widget tests** (pump `CaptureReviewCard` inside `ProviderScope(overrides: [smsCaptureProviderProvider.overrideWith(...)])` with a provider seeded through the fake source)

```dart
testWidgets('hidden when nothing is pending', ...);          // find.byType(Card) / text findsNothing
testWidgets('shows the count with correct plural', ...);      // '1 payment to review', then '2 payments to review'
testWidgets('dismiss removes the row', ...);                  // tap Dismiss tooltip → row text gone
testWidgets('Possible duplicate badge appears for a matching expense', ...);
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/capture_review_card_test.dart`
Expected: FAIL — widget does not exist.

- [ ] **Step 3: Implement the card, review sheet, settings toggle and the `_editing` change** — reuse `LedgerRow` for rows and `AppCard` for the card; the review sheet is a `showModalBottomSheet` list that rebuilds from the provider.

- [ ] **Step 4: Verify**

Run: `flutter test` → all pass. Run: `flutter analyze` → `No issues found!`
On the phone: enable with "Last 30 days" → card shows your recent UPI payments; Add one with a suggestion → it appears in Wallet history as UPI with the SMS date; Edit one → sheet is pre-filled and says "Add expense"; Dismiss one → gone; receive a new UPI SMS with the app open → the count goes up; turn the toggle off → card disappears.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/wallet/capture_review_card.dart lib/pages/wallet_screen.dart lib/pages/settings_page.dart lib/widgets/wallet/add_expense_sheet.dart test/widgets/capture_review_card_test.dart
git commit -m "Add UPI auto-capture opt-in and review queue to Settings and Wallet"
```
