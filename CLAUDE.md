# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

**BengkelIn** is a roadside-assistance marketplace: vehicle owners broadcast an emergency service request, nearby workshops ("bengkel") **bid** on it, the customer accepts a bid, the bengkel dispatches a **mechanic** (or handles it "Self"), and the two sides chat + live-track until the job is completed with a proof photo and paid out of an in-app wallet. Money moves through a **server-side escrow** the client cannot bypass.

This is a **single git repo containing three deployables that share one Supabase project** (`tednrjmhtusdglsembzu`):

| Path | What | Stack | Has its own guidance |
|------|------|-------|----------------------|
| `BengkelIn_SE/` | The iOS app (this CLAUDE.md's main subject) | SwiftUI, layered MVVM | — |
| `admin/` | Web admin dashboard for the same data | Next.js 16 (App Router/RSC), React 19, TS, shadcn/ui, pnpm | **`admin/CLAUDE.md` + `admin/AGENTS.md` — read those before touching `admin/`** |
| `supabase/` | The shared backend | Postgres migrations + Deno edge functions | — |

The Xcode project (`BengkelIn_SE.xcodeproj`) is iOS-only, with one third-party dependency: `supabase-swift`, wired through Xcode's package manager (no SPM manifest, CocoaPods, or fastlane). `build/` is local Xcode output (gitignored); `admin/node_modules/` is pnpm output.

---

## Commands

### iOS app
```sh
open BengkelIn_SE.xcodeproj                                  # develop in Xcode (scheme: BengkelIn_SE)

xcodebuild -project BengkelIn_SE.xcodeproj -scheme BengkelIn_SE \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Tests live in the BengkelIn_SETests target (XCTest, pure unit tests on Models/DTOs — no network):
xcodebuild -project BengkelIn_SE.xcodeproj -scheme BengkelIn_SE \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# A single test class or method:
xcodebuild ... test -only-testing:BengkelIn_SETests/NearbyOrderTests
xcodebuild ... test -only-testing:BengkelIn_SETests/UserAndCurrencyTests/testAvailableBalance
```
Pick a simulator that exists with `xcrun simctl list devices`. There is no lint config and no CI for the iOS target.

**Info.plist**: bengkel registration + live tracking need `NSLocationWhenInUseUsageDescription`.

### Live-tracking simulation
`scripts/sim-route.sh` replays `simulation/route.gpx` into the booted simulator (drives the GPS so the tracking/route maps move); `scripts/restart-all.sh` is a convenience reset. Use these to exercise the location-publish / tracking features.

### Admin web (`admin/`) — see `admin/CLAUDE.md` first
```sh
pnpm dev      # next dev          pnpm build  # prod build + the real typecheck
pnpm start    # serve prod        pnpm lint   # eslint
```

### Supabase backend (`supabase/`)
`supabase/migrations/` holds exactly **8 baseline migrations** (`20260610*`): the first 7 are verbatim copies of `supabase/schema/`, the 8th adds what introspection can't capture (storage buckets+policies, realtime publication + `REPLICA IDENTITY FULL`, function grants). Together they rebuild the entire backend on an empty project with one `supabase db push`. The older 2026-06-02/03 migration trail was retired (recoverable via git history) — never resurrect it; it assumed a pre-existing base schema and cannot run on a fresh project. **To read/understand the backend, prefer `supabase/schema/`** — clean, feature-grouped source-of-truth SQL introspected from the live DB (`schema.sql` tables/RLS, plus `account/bidding/orders/mechanics/payment/admin.sql`); it is **not** tracked by the migration CLI, so schema changes need a new timestamp-prefixed migration **and** a matching edit to the `schema/` (and baseline) copy. Edge functions are in `supabase/functions/{bidding,payment,midtrans-webhook}/index.ts` (`midtrans-webhook` must be deployed with `--no-verify-jwt`). Apply migrations / deploy functions via the **Supabase MCP tools** (or the `supabase` CLI against project `tednrjmhtusdglsembzu`). `config.toml` carries only `project_id`. Two settings live outside the repo and must be re-done on any new project: dashboard Auth → "Confirm email" is intentionally OFF (the iOS signup flow has no confirmation UX, and Supabase's built-in mailer is rate-limited to ~2/hour), and secrets (`MIDTRANS_SERVER_KEY`) are set per-project via `supabase secrets set`.

---

## iOS architecture — Layered MVVM

```
View (SwiftUI) → ViewModel → { Repository (DB) | Service (SDK/API) } → Supabase / external
                     │
              Models + DTOs (pure data)
```

| Layer | Folder | Role |
|-------|--------|------|
| **Model** | `Models/` | Domain structs matching DB rows (`Codable + Identifiable`, `CodingKeys` for snake_case) |
| **DTO** | `Models/DTOs/` | Insert/update/RPC/edge-fn payloads + decode responses. **Field names are snake_case to match columns/params directly** (no CodingKeys). RPC param DTOs use the `p_` prefix the SQL expects |
| **Protocol** | `Protocols/` | `LocationSearchable` — the map+search contract |
| **Repository** | `Repositories/` | Stateless single-table Supabase CRUD (`supabase.from("table")`) + that table's RPCs. One per table |
| **Service** | `Services/` | Stateless non-table work: Auth SDK, Storage, Photon geocoding, the `bidding`/`payment` **edge functions**, local notifications (`UNUserNotificationCenter` — **no APNs/remote push**), network monitor |
| **ViewModel** | `ViewModels/` | `@MainActor ObservableObject`, `@Published` state, orchestrates repos+services |
| **View** | `Views/Pages`, `Views/Components` | SwiftUI screens (Pages) and reusable pieces (Components) |

**Load-bearing rules** (these are the conventions that aren't obvious from any single file):
1. **ViewModels never call `supabase.from(...)` / Auth / Storage directly** — always through a Repository or Service. **The one sanctioned exception is realtime**: a ViewModel sets up its own `supabase.channel(...)` (there is no Repository wrapper for channels). Tear channels down in `stop()`/`deinit`.
2. **No inline `Encodable` structs in ViewModels** — every payload is a named DTO in `Models/DTOs/`.
3. **Repositories and Services are stateless** (no `@Published`); they take params and return/throw. ViewModels own all state and error handling (`catch → errorMessage = error.localizedDescription`).
4. **ViewModels are `@MainActor`**; mutating ops set `isLoading`, clear `errorMessage`, return `Bool` for success, and re-fetch after writes. Location VMs additionally subclass `NSObject` for `CLLocationManagerDelegate`.
5. **User PK = `auth.user.id` UUID, lowercased** everywhere: `session.user.id.uuidString.lowercased()`. Get the session via `AuthService.getCurrentSession()`, never `supabase.auth.session`.

The global `supabase` client (URL + **publishable** key, hard-coded) lives at the top of [`BengkelIn_SE/BengkelInApp.swift`](BengkelIn_SE/BengkelInApp.swift) and is imported directly by every Repository/Service. `ContentView` owns the single `@StateObject AuthViewModel` and gates on `userSession`; `AuthViewModel.appMode` (`.customer | .bengkel | .mechanic`) drives which dashboard renders, switchable in-app for accounts that qualify.

### Realtime is pervasive
Most flows are live. Channels are named per order or per user, e.g. `bids-updates-<reqId>`, `order-tracking-<reqId>`, `chat-<reqId>`, `mechanic-jobs-<uid>`, `payment-updates-<uid>`, `bengkel-status-<uid>`. Migrations set `REPLICA IDENTITY FULL` so updates carry full rows. Follow the existing channel pattern (subscribe in `start()`, read changes in a `Task`, tear down on stop) when adding watchers.

### Location / map stack
OpenStreetMap tiles + **Photon** (`photon.komoot.io`) geocoding via `LocationService` — **no MapKit search, no Google Maps**. `LocationSearchable` ViewModels (`BengkelViewModel`, `OrderViewModel`) own a `CLLocationManager`, debounce address input for live search, and take **coordinates from `region.center`** (the typed address string is stored as-is). Live tracking publishes the mover's GPS to `order_locations` (provider/mechanic side) and `customer_locations` (customer side); the other party subscribes.

---

## The money model (read before touching anything financial)

Wallet balances live on `users`: `balance` (real, withdrawable), `held_balance` (customer funds reserved for an open order), `pending_balance` (provider funds earmarked but not yet released). **Available balance = `balance − held_balance`** (mirrored by `User.availableBalance`); withdrawals draw only from available.

A Postgres **escrow trigger (`handle_order_balance` on `service_requests`)** is the state machine — the client never moves money, it only changes order status:

| Order transition (status) | Escrow effect |
|---|---|
| created → `pending` (broadcasting) | customer `held_balance += estimated_price` |
| price raised while `pending` | adjust hold by the delta |
| bid accepted → `accepted` | provider `pending_balance += estimated_price` (customer hold stays) |
| → `completed` | settle both: clear customer hold, release provider pending into real `balance` |
| → `cancelled` (incl. dispute) | unwind both reservations — nobody is charged (refund) |

Supporting RPCs: `accept_bid` (frees this order's own hold before the affordability check so escrow doesn't double-count), `mark_order_completed` (**dual-confirm**: needs both `customer_completed` and `provider_completed`, plus a **mandatory provider proof photo**), `rate_order` (write-once after completion → recomputes bengkel rating), `open_dispute` (records reason/proof, cancels → trigger refunds). Points (`points`/`pending_points`) and a platform fee are credited on completion, separate from cash.

**Security invariant — do not break it:** money-crediting functions are not client-callable. `settle_topup` and `reject_withdrawal` are **service_role only**; trigger functions are revoked from `anon`/`authenticated`; only the `midtrans-webhook` edge function (server-side, after Midtrans confirms a Snap payment) settles top-ups. Never expose a balance-mutating path to the client.

### Order lifecycle (the end-to-end loop)
`top-up → broadcast request → bengkels bid → customer accepts → bengkel assigns mechanic (or "Self") → chat + live-track → complete + proof photo → escrow settles → review`; a complaint opens a dispute → cancel → refund. Service-request `status` is lowercase `pending / accepted / in_progress / completed / cancelled` (`in_progress` once a mechanic is assigned). `PLAN.md` is the original port plan and remains a useful map of who built what.

---

## Backend surface (shared Supabase project)

**Tables**: `users`, `vehicles`, `bengkels` (JSONB `offered_services`), `service_requests` (the "order"), `bids`, `chat_messages`, `order_locations`, `customer_locations`, `topups`, `withdrawals`, `behavior_reports`. RPC-backed (no direct iOS `.from`): `mechanic_registrations` (the bengkel↔mechanic roster) and `order_disputes`. Server-side only: `platform_revenue` (fee ledger written by the escrow engine on completion; read by the admin revenue RPCs — never touched by iOS). **Vouchers were removed** (in the retired 2026-06 migration trail, before the baseline) — ignore any older mention of `vouchers`/`user_vouchers`/`mechanic_invitations`/`mechanic_resignations`.

**Storage buckets**: `avatars` (`{uid}/profile.jpg`), `order-photos`, `chat-images`.

**User-facing RPCs** (authenticated): `bengkel_roster`, `invite_mechanic`, `remove_mechanic`, `respond_mechanic_invite`, `my_mechanic_invites`, `available_mechanics`, `assign_mechanic`, `accept_bid`, `cancel_order`, `open_dispute`, `rate_order`, `mark_order_completed`, `request_withdrawal`.

**Restricted** (never grant to clients): `settle_topup`, `reject_withdrawal` (service_role); `handle_order_balance`, `recompute_bengkel_rating` (trigger-only); `increment_user_balance` (definer-internal).

**Edge functions** (`supabase/functions/`): `bidding` (actions `ordersForMechanic`, `placeBid` — geo-filters open orders / writes bids server-side; called by `BiddingService`), `payment` (action `createTopup` — returns a Midtrans Snap `redirect_url` + token; called by `PaymentService`), `midtrans-webhook` (Midtrans → `settle_topup`; not called by the app).

---

## iOS conventions cheat-sheet

- **Model**: all properties `var` (mutated after fetch); `id`/`createdAt` optional for inserts; `CodingKeys` map camelCase↔snake_case.
- **DTO**: `let` fields, **snake_case** (or `p_`-prefixed for RPC params); lean insert DTOs when the model has many server-managed fields.
- **Repository**: `async throws`; `.single().execute().value` for one row, `.execute().value` for arrays; RPCs via `supabase.rpc("name", params: dto)`.
- **Service**: same statelessness, but for non-table work (Auth/Storage/Photon/edge functions/local notifications).
- **ViewModel**: `@StateObject` when the View creates it, `@ObservedObject` when injected (`AuthViewModel` is created once in `ContentView`).
- **UI**: `Color(.systemGray6)` cards / `Color(.systemBackground)` backgrounds; 12pt card radius, 16pt buttons; `.primary` text/dark buttons. UI copy mixes English + Bahasa Indonesia — match the surrounding screen.
- **File header**: `//  FileName.swift / //  BengkelIn_SE / //  Created by <Author> on DD/MM/YY.`
