# TrackIt backend: changes needed for sync

> **Status:** Option A (sections 0–3) is implemented in
> `E:\Django\trackit_backend` (uncommitted, 14 tests passing on SQLite). It
> still needs `python manage.py migrate` on the deployed database. Deleting an
> already-deleted row returns 404, which the app treats as success.

Written against `E:\Django\trackit_backend` (Django 6, DRF, SimpleJWT,
`PageNumberPagination` with `PAGE_SIZE=100`). All changes are additive and
backwards compatible: until they land, the app falls back to full pulls and
skips duplicate detection.

## 0. Blocker: the app and backend disagree on expense endpoints

The app syncs expenses with `transactions/`, `categories/` and `events/`
(fields `txn_date`, `note`, `type`, `category` as UUID, `subcategory`, `event`,
`payment_method`, `attachment_url`). The backend only has
`/api/finance/expenses/` with `amount`, `category` (6 fixed choices),
`timestamp`, `description`, and no categories, events, income type or
subcategories. So expense/category/event sync currently 404s. Pick one:

- **A (recommended):** build the blueprint on the backend: `Category`,
  `Subcategory`, `Event` models and a `Transaction` model/endpoints under
  `/api/transactions/`, `/api/categories/`, `/api/events/`.
- **B:** point the app at `finance/expenses/` and drop the blueprint fields.

Workouts (`fitness/workouts/`) and groups (`groups/groups/`,
`groups/group-expenses/`, `groups/settlements/`) already match.

## 1. `client_id` (idempotent creates)

The app sends a UUID `client_id` on every push.

- Add `client_id = models.UUIDField(null=True, blank=True)` to `Expense`/
  `Transaction`, `Workout`, `Group`, `GroupExpense`, `Settlement`, with
  `UniqueConstraint(fields=['user', 'client_id'])` (for group models use the
  creating user, e.g. `created_by`).
- Add it to each serializer's `fields` and return it in responses.
- On create, if a row with the same `(user, client_id)` exists, return it
  (200) instead of inserting a duplicate.

## 2. `updated_at` and `updated_after`

- Add `updated_at = models.DateTimeField(auto_now=True, db_index=True)` to the
  same models and serializers. Existing rows need a migration default (use
  `created_at`).
- Support `GET <list>/?updated_after=<ISO 8601 UTC>` returning rows with
  `updated_at > updated_after`. Easiest as a shared `get_queryset` mixin:

```python
class UpdatedAfterMixin:
    def filter_updated_after(self, qs):
        since = parse_datetime(self.request.query_params.get("updated_after", ""))
        return qs.filter(updated_at__gt=since) if since else qs
```

Note `PUT`/`PATCH` bump `updated_at` automatically via `auto_now`; bulk
`queryset.update()` calls do not, so set it explicitly there.

## 3. Soft-delete tombstones

Needed for `Expense`/`Transaction` and `Workout` (the only things the app
deletes today):

- Add `is_deleted = BooleanField(default=False)`.
- Override `perform_destroy` to set `is_deleted=True` and save (this bumps
  `updated_at`) instead of deleting. Repeat deletes return 204.
- `get_queryset`: exclude `is_deleted=True` normally, but **include** them when
  `updated_after` is present, and serialize `is_deleted`.
- Optional cleanup job that hard-deletes tombstones older than ~90 days.

The app removes any pulled row with `is_deleted: true`, and treats 404/410 on
its queued deletes as success.

## 4. Already fine

- Token refresh exists at `POST /api/auth/token/refresh/` (7-day refresh,
  1-day access, no rotation). The app doesn't call it yet; that's an app-side
  task.
- Pagination returns `next`/`results`; the app follows `next`.

## 5. Routines, budgets, group edits and deletes

Implemented in `E:\Django\trackit_backend` (needs `python manage.py migrate`:
`finance 0005`, `fitness 0004`, `groups 0003`).

- **Routines** (`/api/fitness/routines/`): `client_id`, `updated_at`,
  `is_deleted`; `routine_exercises` are written nested on `POST`/`PUT` (a
  `PUT` replaces them).
- **Budgets** (`/api/budgets/`): `id` is the app's UUID. `POST` upserts by
  `id`, or by category + month if another device already set that slot, and
  answers with the row's id (the app adopts it). Soft-deleted.
- **Groups, group expenses, settlements**: soft-deleted, and `PUT` updates
  them (group expense `PUT` replaces splits). Only a group's owner may
  delete it (403 otherwise). Balances ignore deleted rows, and a deleted
  group's expenses/settlements drop out of their lists.

## 6. Open items

- Conflicts are last-write-wins on the server's `updated_at`.
- Removing a member from a group isn't supported yet.
