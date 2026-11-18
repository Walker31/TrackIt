# UPI auto-capture from bank SMS — design

**Status:** approved direction (research, 2026-10-27). TrackIt v1 is the code at
`app-checkup-sync-ui` @ `99b6a9c`; this is the first v2 feature.

## Goal

Stop typing UPI payments by hand. On Android, read the bank's transaction SMS
that arrives for every UPI debit/credit (whichever UPI app paid), turn it into
a suggested expense or income, and let the user confirm it with one tap.

## Why SMS

Every UPI payment produces a bank SMS regardless of the app used. The other
routes were rejected: Account Aggregator needs an RBI/SEBI/IRDAI/PFRDA
regulated entity; Gmail access needs a paid security assessment; accessibility
scraping is fragile and Play-hostile; notification parsing only covers some
apps (a later enrichment, not the base). iOS cannot read SMS, so iOS and web
keep manual entry.

## Behaviour

1. **Opt-in.** Off by default. Settings → Data & Sync → "Auto-capture UPI
   payments" (shown on Android only). Turning it on explains what is read,
   asks for SMS permission, and offers a one-time import: *just new messages*,
   *last 30 days* or *last 90 days*.
2. **Capture.** When the app opens or returns to the foreground it scans the
   inbox for messages newer than its checkpoint. While the app is open it also
   listens for new SMS. (Capture while the app is closed is out of scope.)
3. **Parse on the device.** Only messages from business sender IDs
   (TRAI DLT format, e.g. `VM-HDFCBK-S`) are considered; promotional (`-P`),
   OTP, collect-request, "will be debited" mandate and bill-due messages are
   ignored. Extracted: amount, debit/credit, payee (name or VPA), UPI reference
   number, account last digits.
4. **Store only what was parsed.** The SMS body is never stored or sent
   anywhere. Captures live in a local table and are never synced.
5. **No duplicates.** A capture is unique per UPI reference **and** direction,
   so the same message seen twice (scan + listener) is stored once, while a
   transfer between the user's own accounts (same reference, one debit and one
   credit) yields two captures.
6. **Review.** Wallet → Personal shows "N payments to review" when there are
   pending captures. Each shows payee, amount, date, a suggested category and a
   "Possible duplicate" badge when an expense with the same amount, type and
   day already exists. Actions: **Add** (with the suggested category),
   **Edit** (opens the add-expense sheet pre-filled), **Dismiss**.
7. **Learn categories.** Accepting a capture remembers payee → category; the
   next capture from that payee is suggested that category.
8. **Accepted captures become normal transactions**: payment method UPI,
   timestamp = SMS time, description = payee. They then sync like any expense.

## Constraints

- Android permissions: `READ_SMS`, `RECEIVE_SMS` only (never `SEND_SMS`).
- No new SMS plugin dependency; a small Kotlin channel does the inbox query and
  live receiver. `permission_handler` requests the runtime permission.
- Distributed as an APK today. Publishing on Google Play would need the SMS
  Permissions Declaration under "SMS-based money management" (discretionary).

## Out of scope (later)

Capture while the app is closed (background receiver + notification); UPI app
notification parsing for richer merchant names; statement import; syncing
payee rules across devices.
