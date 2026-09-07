# Customer-First Ledger — Technical Specification v1

**Status:** MVP architecture baseline  
**Platform:** Flutter, Android-first for UPI validation  
**Local database:** Drift + SQLite  
**Cloud:** Supabase/PostgreSQL  
**State management:** Riverpod  
**Routing:** GoRouter  
**Date:** 2026-09-07

---

## 1. Product Scope

Customer-First Ledger is an offline-first personal ledger for urban Indian consumers who purchase goods/services from neighborhood merchants on credit.

### Core loop

```text
Record Purchase
      ↓
Track Merchant-wise Outstanding
      ↓
Clear Dues via Native UPI Intent
      ↓
Record Settlement + UTR
      ↓
Generate Itemized WhatsApp Statement
      ↓
Eventually Sync/Backup to Cloud
```

### MVP screens

1. Dashboard
2. Store Ledger Detail
3. Add Merchant / VPA Setup

Optional MVP feature:

4. QR scanner for standard UPI QR parsing

### Explicit non-goals

- No payment gateway
- No Razorpay/Cashfree/Stripe
- No card processing
- No custody or pooling of funds
- No NBFC functionality
- No `READ_SMS`
- No `RECEIVE_SMS`
- No automatic bank/SMS transaction scraping
- No merchant-side application in the first MVP

---

# 2. Architecture

The application follows a local-first architecture.

```text
┌──────────────────────────────────────────────┐
│                  Flutter UI                  │
│       Dashboard / Ledger / Merchant          │
└──────────────────────┬───────────────────────┘
                       │
                 Riverpod State
                       │
┌──────────────────────▼───────────────────────┐
│                  Domain Layer                 │
│ Entities / Use Cases / Repository Contracts  │
└──────────────────────┬───────────────────────┘
                       │
┌──────────────────────▼───────────────────────┐
│                   Data Layer                  │
│ Drift DAOs / Repository Implementations      │
└──────────────────────┬───────────────────────┘
                       │
              ┌────────▼────────┐
              │  SQLite / Drift │
              │ Local Source of │
              │     Truth       │
              └────────┬────────┘
                       │
                 Sync Outbox
                       │
              Background Sync
                       │
              ┌────────▼────────┐
              │    Supabase     │
              │ Cloud Replica / │
              │ Backup / Future │
              │ Synchronization │
              └─────────────────┘
```

## Core architectural invariant

> If a local SQLite transaction commits successfully, the user's action is considered successful. Cloud synchronization is asynchronous and eventually consistent.

The cloud must never be required for the core ledger to function.

---

# 3. Technology Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter |
| Language | Dart |
| Architecture | Clean Architecture / Feature-first |
| State | Riverpod |
| Routing | GoRouter |
| Local DB | Drift |
| DB engine | SQLite |
| Cloud DB | Supabase PostgreSQL |
| Background sync | Android WorkManager via Flutter-compatible implementation |
| Payments | Native UPI URI intent |
| Receipt sharing | WhatsApp URI / share intent |
| QR | Optional UPI QR scanner |
| Money | Integer paise (`int`) |
| IDs | UUID |
| Serialization | JSON where needed |
| Testing | flutter_test + integration tests |

---

# 4. Domain Model

## 4.1 Merchant

Represents a neighborhood merchant/store.

```text
Merchant
├── id: UUID
├── name: String
├── category: MerchantCategory
├── phone: String?
├── upiVpa: String
├── createdAt: DateTime
├── updatedAt: DateTime
└── isActive: bool
```

### MerchantCategory

```text
GROCERY
MILK
LAUNDRY
OTHER
```

---

## 4.2 Purchase

Represents an individual credit purchase.

```text
Purchase
├── id: UUID
├── merchantId: UUID
├── amountPaise: int
├── note: String
├── category: String?
├── purchaseDate: DateTime
├── createdAt: DateTime
├── updatedAt: DateTime
└── syncStatus: SyncStatus
```

A purchase is historical data. It should not be deleted simply because it was settled.

---

## 4.3 Settlement

Represents an attempt to clear one or more outstanding purchases.

```text
Settlement
├── id: UUID
├── merchantId: UUID
├── amountPaise: int
├── status: SettlementStatus
├── transactionId: String?
├── utr: String?
├── initiatedAt: DateTime
├── completedAt: DateTime?
├── createdAt: DateTime
├── updatedAt: DateTime
└── syncStatus: SyncStatus
```

---

## 4.4 SettlementItem

Associates purchases with a settlement.

```text
SettlementItem
├── settlementId: UUID
├── purchaseId: UUID
└── amountPaise: int
```

This allows future support for:

- partial settlements
- multiple purchases in one settlement
- settlement history
- corrections/reversals

For the MVP, `amountPaise` should normally equal the full purchase amount.

---

## 4.5 SyncQueueItem

Represents an operation waiting to reach the cloud.

```text
SyncQueueItem
├── id: UUID
├── entityType: SyncEntityType
├── entityId: UUID
├── operation: SyncOperation
├── attemptCount: int
├── lastAttemptAt: DateTime?
├── lastError: String?
└── createdAt: DateTime
```

### SyncEntityType

```text
MERCHANT
PURCHASE
SETTLEMENT
SETTLEMENT_ITEM
```

### SyncOperation

```text
UPSERT
DELETE
```

For financial records, physical deletion should generally be avoided. Corrections should preferably be represented by explicit domain operations.

---

# 5. SQLite / Drift Schema

## 5.1 merchants

```sql
CREATE TABLE merchants (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    phone TEXT,
    upi_vpa TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1
);
```

### Constraints

- `name` cannot be empty.
- `upi_vpa` must pass application-level UPI VPA validation.
- Phone is optional.
- Merchant is soft-deactivated using `is_active`.

---

## 5.2 purchases

```sql
CREATE TABLE purchases (
    id TEXT PRIMARY KEY,
    merchant_id TEXT NOT NULL,
    amount_paise INTEGER NOT NULL,
    note TEXT NOT NULL,
    category TEXT,
    purchase_date INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    sync_status TEXT NOT NULL DEFAULT 'PENDING',

    FOREIGN KEY (merchant_id)
        REFERENCES merchants(id)
);
```

### Constraints

```text
amount_paise > 0
merchant_id must exist
```

---

## 5.3 settlements

```sql
CREATE TABLE settlements (
    id TEXT PRIMARY KEY,
    merchant_id TEXT NOT NULL,
    amount_paise INTEGER NOT NULL,
    status TEXT NOT NULL,
    transaction_id TEXT,
    utr TEXT,
    initiated_at INTEGER NOT NULL,
    completed_at INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    sync_status TEXT NOT NULL DEFAULT 'PENDING',

    FOREIGN KEY (merchant_id)
        REFERENCES merchants(id)
);
```

---

## 5.4 settlement_items

```sql
CREATE TABLE settlement_items (
    settlement_id TEXT NOT NULL,
    purchase_id TEXT NOT NULL,
    amount_paise INTEGER NOT NULL,

    PRIMARY KEY (settlement_id, purchase_id),

    FOREIGN KEY (settlement_id)
        REFERENCES settlements(id),

    FOREIGN KEY (purchase_id)
        REFERENCES purchases(id)
);
```

---

## 5.5 sync_queue

```sql
CREATE TABLE sync_queue (
    id TEXT PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_attempt_at INTEGER,
    last_error TEXT,
    created_at INTEGER NOT NULL
);
```

---

# 6. Balance Calculation

The outstanding balance must be derived from ledger state.

For the MVP:

```text
Outstanding =
SUM(Purchase amounts not associated with a successful settlement)
```

Do not persist a mutable `balance` column as the authoritative value.

This avoids:

```text
Purchase added
→ balance += amount

Settlement
→ balance -= amount
```

getting out of sync after edits, retries, or partial failures.

Instead calculate from source records.

Example:

```text
Sharma Kirana

₹120 Bread & Eggs
₹450 Vegetables
₹200 Milk

Outstanding = ₹770
```

---

# 7. Settlement State Machine

Settlement status:

```text
INITIATED
    │
    ▼
UPI_LAUNCHED
    │
    ├───────────────┐
    ▼               ▼
SUCCESS          FAILED
    │
    ▼
SETTLED
```

An additional ambiguous state is recommended:

```text
UNKNOWN
```

because a client-side UPI response should not automatically be treated as definitive financial proof.

### States

#### INITIATED

Local settlement record created before launching UPI.

#### UPI_LAUNCHED

UPI URI successfully handed to the operating system.

#### SUCCESS

The UPI application reports a successful result. This should trigger local settlement completion according to the application's defined result parser.

#### FAILED

Explicit failure/cancellation result.

#### UNKNOWN

No reliable final result was obtained.

#### SETTLED

Local ledger has been marked as settled after the application's settlement confirmation logic.

---

# 8. Critical Payment Rule

Never clear the ledger merely because the UPI application was opened.

Incorrect:

```text
Clear Dues
 ↓
Open PhonePe
 ↓
Immediately zero balance
```

Correct:

```text
Clear Dues
 ↓
Create local Settlement(INITIATED)
 ↓
Launch UPI
 ↓
Receive result
 ↓
Parse result
 ↓
Only then transition settlement state
 ↓
Associate/settle purchases
```

For ambiguous results, preserve the outstanding ledger until the application has sufficient evidence to mark the settlement successful.

---

# 9. UPI Intent

URI format:

```text
upi://pay?pa={merchant_vpa}&pn={merchant_name}&am={amount}&cu=INR&tn=Settlement_via_App
```

The implementation must:

1. Validate VPA.
2. Validate positive amount.
3. Encode URI parameters correctly.
4. Store local settlement before launching.
5. Launch native intent.
6. Capture returned result where the platform/payment application provides one.
7. Persist result locally.
8. Avoid assuming success merely because an external UPI app opened.

### Amount conversion

Database:

```text
₹770.50
```

Stored as:

```text
77050 paise
```

UPI amount:

```text
770.50
```

Never use floating-point values as financial storage.

---

# 10. Android Package Visibility

AndroidManifest must include UPI scheme visibility for Android 11+.

Conceptually:

```xml
<queries>

    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="upi" />
    </intent>

    <package android:name="com.google.android.apps.nbu.paisa.user" />
    <package android:name="com.phonepe.app" />
    <package android:name="net.one97.paytm" />

</queries>
```

Do not request SMS permissions.

No:

```xml
android.permission.READ_SMS
android.permission.RECEIVE_SMS
```

No automatic SMS transaction extraction.

---

# 11. WhatsApp Receipt

Receipt generation is a separate domain service.

Example:

```text
Hi Sharma Kirana,

I have cleared my pending tab of ₹770 via UPI.

Ref/UTR: 123456789012

Breakdown:
- Bread & Eggs: ₹120
- Vegetables: ₹450
- Milk: ₹200

Track your customer ledgers easily with [AppName].
```

The message must be URL encoded before constructing the WhatsApp URI.

Conceptually:

```text
whatsapp://send?phone={merchant_phone}&text={url_encoded_message}
```

If merchant phone is unavailable, the app should provide a generic share/copy option rather than requiring WhatsApp.

---

# 12. Sync Architecture

The sync system follows an outbox pattern.

```text
User Action
    ↓
SQLite Transaction
    ↓
Domain record created
    ↓
SyncQueueItem created
    ↓
UI immediately updated
    ↓
Background Sync
    ↓
Supabase
```

## Sync opportunities

Do not rely on a literal midnight cron job.

Use multiple opportunities:

1. Immediately/opportunistically after a write
2. When the application is opened/resumed
3. When network connectivity becomes available
4. Periodic background work through Android WorkManager
5. Daily reconciliation as a final failsafe

---

# 13. Sync Algorithm

```text
START
  ↓
Read pending SyncQueueItems
  ↓
Batch records
  ↓
Check network
  ↓
No network ─────────→ Retry later
  │
  YES
  ↓
Upsert cloud record
  ↓
Success?
 /      \
NO       YES
│         │
Increment  Mark synced
attempt    │
│          Remove queue item
└──────→ Retry later
```

### Important property

Sync must be **idempotent**.

If the same record is uploaded multiple times:

```text
Purchase UUID = abc-123
```

the cloud must not create:

```text
abc-123
abc-123-copy
abc-123-copy-2
```

Use stable UUIDs and Supabase/PostgreSQL upserts.

---

# 14. Supabase Schema

Supabase is a cloud replica/backup and future synchronization layer.

It should not be required for the basic ledger.

Suggested tables:

```text
merchants
purchases
settlements
settlement_items
```

Cloud IDs should match local UUIDs.

Example:

```sql
CREATE TABLE merchants (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    phone TEXT,
    upi_vpa TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);
```

Equivalent purchase/settlement tables should use the same entity IDs as SQLite.

---

# 15. Sync Conflict Strategy

For the MVP, avoid complicated bidirectional editing.

Preferred model:

```text
Device
  ↓
Local write
  ↓
Cloud upsert
```

Cloud is primarily a backup/replica.

If multi-device editing is introduced later, add:

```text
version
updated_at
device_id
event_id
```

and implement explicit conflict resolution.

Do not silently use last-write-wins for financial events without defining its semantics.

---

# 16. Repository Contracts

The UI must never directly call Drift or Supabase.

Example:

```dart
abstract class MerchantRepository {
  Stream<List<Merchant>> watchActiveMerchants();

  Future<Merchant> createMerchant(CreateMerchantInput input);

  Future<void> updateMerchant(Merchant merchant);

  Future<void> deactivateMerchant(String merchantId);
}
```

```dart
abstract class LedgerRepository {
  Stream<List<Purchase>> watchPurchases(String merchantId);

  Stream<int> watchOutstandingAmount(String merchantId);

  Future<Purchase> addPurchase(CreatePurchaseInput input);
}
```

```dart
abstract class SettlementRepository {
  Future<Settlement> initiateSettlement(String merchantId);

  Future<void> markUpiLaunched(String settlementId);

  Future<void> completeSettlement(
    String settlementId,
    SettlementResult result,
  );

  Future<void> markSettlementFailed(
    String settlementId,
    String reason,
  );
}
```

```dart
abstract class SyncRepository {
  Future<void> syncPendingRecords();

  Future<void> reconcile();

  Stream<SyncStatus> watchSyncStatus();
}
```

---

# 17. Service Abstractions

External integrations must be isolated behind interfaces.

## UPI

```dart
abstract class UpiService {
  Future<UpiLaunchResult> launchPayment({
    required String vpa,
    required String merchantName,
    required int amountPaise,
    required String transactionNote,
  });
}
```

## WhatsApp

```dart
abstract class ReceiptShareService {
  Future<void> shareWhatsAppReceipt({
    required String phone,
    required String message,
  });
}
```

## Connectivity

```dart
abstract class ConnectivityService {
  Stream<bool> get isOnline;
}
```

This makes integrations testable and prevents platform code from leaking into the domain layer.

---

# 18. Suggested Flutter Project Structure

```text
lib/
│
├── main.dart
│
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│       ├── app_theme.dart
│       ├── app_colors.dart
│       └── app_typography.dart
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── utils/
│   └── services/
│
├── database/
│   ├── app_database.dart
│   ├── tables/
│   │   ├── merchants_table.dart
│   │   ├── purchases_table.dart
│   │   ├── settlements_table.dart
│   │   ├── settlement_items_table.dart
│   │   └── sync_queue_table.dart
│   │
│   └── daos/
│       ├── merchant_dao.dart
│       ├── purchase_dao.dart
│       ├── settlement_dao.dart
│       └── sync_queue_dao.dart
│
├── features/
│   │
│   ├── dashboard/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── merchant/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── ledger/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── settlement/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   └── receipt/
│       ├── data/
│       ├── domain/
│       └── presentation/
│
└── shared/
    ├── widgets/
    └── models/
```

---

# 19. Dashboard Requirements

Dashboard must read entirely from local data.

Display:

```text
Total Outstanding
        ↓
Merchant Cards
        ↓
Merchant Balance
        ↓
Last Active
```

Example:

```text
Total Outstanding
₹2,370

┌──────────────────────────────┐
│ Sharma Kirana                │
│ Grocery                      │
│                              │
│ Outstanding       ₹1,240     │
│ Last active       Today      │
└──────────────────────────────┘
```

Global FAB:

```text
+ Add New Tab
```

---

# 20. Ledger Requirements

Header:

```text
Merchant Name
Verified UPI ID
Outstanding Amount
```

Purchases in reverse chronological order.

Example:

```text
₹450
Vegetables
6 Oct

₹120
Bread & Eggs
4 Oct
```

Bottom action area:

```text
[ Add Purchase ]

[ Clear Dues — ₹770 ]
```

---

# 21. Add Purchase

Minimal flow:

```text
Amount
Note / Category
Date
```

Validation:

```text
amount > 0
amount must fit integer paise representation
note can be empty only if product decision permits
date must be valid
merchant must exist
```

On submit:

```text
SQLite transaction
  ├── Insert Purchase
  └── Insert SyncQueueItem
```

UI then observes the database stream.

---

# 22. Add Merchant

Fields:

```text
Merchant Name
Category
Phone (optional)
UPI VPA
```

Categories:

```text
Grocery
Milk
Laundry
Other
```

Optional QR flow:

```text
Scan QR
   ↓
Read UPI URI
   ↓
Parse pa
   ↓
Populate VPA
   ↓
User verifies
   ↓
Save merchant
```

Never blindly trust scanned values. Display the parsed VPA for user confirmation.

---

# 23. Error Handling

Important cases:

### Merchant

- Invalid VPA
- Missing merchant name
- Duplicate merchant
- Invalid phone number

### Purchase

- Invalid amount
- Database failure
- Invalid merchant ID

### UPI

- No UPI application available
- URI construction failure
- User cancellation
- Explicit failure
- Unknown/ambiguous response
- App killed during payment
- Duplicate callback

### WhatsApp

- WhatsApp unavailable
- Invalid phone
- Message URI too long
- Share intent unavailable

### Sync

- Offline
- Supabase unavailable
- Authentication failure
- Validation failure
- Duplicate upload
- Server timeout
- Partial batch failure

---

# 24. Security & Privacy

## Local

Consider encrypted local storage if the threat model requires protection of financial history while the device is unlocked/compromised.

At minimum:

- Never store UPI PIN
- Never store banking credentials
- Never store card details
- Never request SMS permissions
- Avoid unnecessary device permissions

## Cloud

Supabase must use:

- Authentication
- Row Level Security
- Per-user ownership
- HTTPS
- Minimal exposed data
- Explicit deletion strategy

Cloud records should never be readable by another user.

---

# 25. Data Ownership

Every cloud record should eventually be associated with an application user.

A future cloud schema should include:

```text
user_id
```

for all user-owned entities.

Local records can initially operate without authentication if the MVP intentionally supports anonymous local usage.

When account/cloud backup is introduced:

```text
Anonymous Local User
        ↓
Create Account
        ↓
Associate Local UUIDs
        ↓
Upload Pending Records
        ↓
Cloud Backup Active
```

---

# 26. Testing Strategy

## Unit tests

Test:

- balance calculation
- paise/rupee conversion
- UPI URI generation
- UPI result parsing
- settlement state transitions
- receipt generation
- sync queue behavior

## Database tests

Test:

- merchant creation
- purchase creation
- outstanding calculation
- settlement association
- transaction rollback
- migration

## Integration tests

Test:

```text
Add merchant
→ Add purchase
→ Verify outstanding
→ Initiate settlement
→ Simulate success
→ Verify settlement
→ Verify outstanding = 0
```

## Failure tests

Especially:

```text
UPI launched
→ app killed
→ reopen
→ settlement remains recoverable
```

and:

```text
SQLite write succeeds
→ internet unavailable
→ sync queue retains record
→ internet restored
→ record uploads
```

---

# 27. MVP Milestones

## Milestone 1 — Foundation

- Create Flutter project
- Configure Riverpod
- Configure GoRouter
- Configure Drift
- Create database
- Create migrations
- Establish feature structure

## Milestone 2 — Merchant + Ledger

- Add merchant
- List merchants
- Merchant detail
- Add purchase
- Calculate outstanding
- Empty states
- Validation

## Milestone 3 — UPI

- Native Android UPI bridge/service
- URI generation
- Package visibility
- UPI result handling
- Settlement state machine
- Failure handling

## Milestone 4 — Receipt

- Statement formatter
- UTR display
- WhatsApp intent
- Generic share fallback

## Milestone 5 — Sync

- Supabase project
- Auth/user ownership
- Cloud schema
- Outbox queue
- Background sync
- Retry policy
- Daily reconciliation

## Milestone 6 — Hardening

- Integration tests
- Database migration tests
- Payment failure tests
- Offline tests
- Crash recovery
- Performance testing
- Security review
- Play Store permission review

---

# 28. Definition of Done for MVP

The MVP is ready for internal testing when a user can:

```text
1. Open app without internet
2. Add Sharma Kirana
3. Add ₹120 Bread & Eggs
4. Add ₹450 Vegetables
5. See ₹570 outstanding
6. Close/reopen app
7. Still see ₹570
8. Tap Clear Dues
9. Launch a UPI application
10. Return with a payment result
11. Persist settlement state
12. Preserve UTR where available
13. Calculate the updated outstanding correctly
14. Generate an itemized statement
15. Open WhatsApp/share flow
16. Later synchronize records to Supabase
17. Retry failed synchronization safely
```

---

# 29. Architecture Decisions to Preserve

### ADR-001 — Local-first

SQLite/Drift is the operational source of truth for the device.

### ADR-002 — Cloud is asynchronous

Supabase must not block normal ledger operations.

### ADR-003 — Stable IDs

Generate UUIDs locally so offline records can be synchronized safely.

### ADR-004 — Money in paise

All financial values are stored as integer paise.

### ADR-005 — Historical records preserved

Settling a purchase does not delete its historical record.

### ADR-006 — Idempotent sync

Cloud synchronization must tolerate retries and duplicate attempts.

### ADR-007 — No SMS access

No SMS permissions or SMS transaction scraping.

### ADR-008 — Native UPI

UPI is initiated through the native `upi://pay` flow, not a payment gateway.

### ADR-009 — Payment uncertainty

Opening a UPI application is not equivalent to successful payment.

### ADR-010 — Repository abstraction

UI/domain code must not depend directly on SQLite, Supabase, Android intents, or WhatsApp.

---

# 30. Recommended Implementation Order

```text
Database schema
      ↓
Drift database + DAOs
      ↓
Domain entities
      ↓
Repository interfaces
      ↓
Merchant feature
      ↓
Purchase/ledger feature
      ↓
Dashboard
      ↓
Settlement state machine
      ↓
Native UPI integration
      ↓
Receipt/WhatsApp
      ↓
Sync queue
      ↓
Supabase
      ↓
Background reconciliation
      ↓
Testing + hardening
      ↓
UI polish from Google Stitch
```

The database/domain/payment state machine should be implemented before allowing AI coding tools to generate large amounts of UI code.

---

# 31. Important Product/Compliance Caveat

This document intentionally treats UPI integration as a technical launch mechanism rather than a claim that the app's business model is automatically compliant with every applicable Indian regulatory requirement.

Before production launch, review the final payment flow, UPI app integration behavior, data practices, privacy policy, terms, and app-store disclosures against current NPCI, RBI, Google Play, Apple App Store, and applicable Indian legal requirements.

In particular, do not represent the app as a payment processor, payment aggregator, bank, lender, or UPI provider unless the required authorization actually exists.
