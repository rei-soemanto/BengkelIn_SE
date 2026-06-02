# BengkelIn — Parallel-Work Contracts

_The shared seams four feature branches build against. Edit this file by PR; if a
contract must change, announce it so the other three can react. Companion to
`../split-decision.md`._

Tiers / owners (see split-decision.md): **Bryan** = Money, **Eugene** = Marketplace/Bidding,
**Rei** = Mechanic (assignment + roster + chat + tracking), **Jason** = Closeout
(completion + ratings + complaints) + this prep PR.

---

## 1. `service_requests` lifecycle (the spine everyone shares)

Status is lowercase text. One owner transitions each edge; everyone else reads.

```
            (Eugene: create, bengkel_id = NULL, broadcast)
   ┌──────────────┐  accept_bid (Eugene)         ┌───────────┐
   │   pending    │ ───────────────────────────▶ │ accepted  │
   └──────────────┘  sets bengkel_id + price      └───────────┘
        │ cancel (Eugene/Customer)                      │ assign mechanic (Rei: sets mechanic_id)
        ▼                                                ▼
   ┌──────────────┐                               ┌──────────────┐
   │  cancelled   │ ◀──── open_dispute (Jason) ─── │ in_progress  │
   └──────────────┘       (from in_progress)       └──────────────┘
                                                          │ mark_order_completed (Jason: dual-confirm + proof)
                                                          ▼
                                                   ┌──────────────┐   rate_order (Jason)
                                                   │  completed   │ ──────────────────▶ (rating recompute)
                                                   └──────────────┘
```

- `pending` → `accepted`: **Eugene** only, via `accept_bid` RPC (sets `bengkel_id`, `estimated_price`).
- `accepted` → `in_progress`: **Rei**, when a mechanic is assigned (sets `mechanic_id`).
- `in_progress` → `completed`: **Jason**, via `mark_order_completed` (dual-confirm + proof).
- `* → cancelled`: `pending` cancel = Eugene/customer; `in_progress` dispute = Jason (`open_dispute`).
- Everyone may **read** any field. Nobody writes a transition they don't own. All transitions go through SECURITY DEFINER RPCs, never a raw client `update`.

`bengkel_id` is now **nullable** (bidding broadcast). The customer's offered price reuses
`estimated_price` (no separate `price` column). New bidding columns/flags that Closeout needs
(`customer_completed`, `provider_completed`, `completion_photo_url`, `rating`, `review`) are
added by Jason's migration, not here.

## 2. Shared-column ownership (who may WRITE)

| Column(s) | Table | Writer | Via |
|-----------|-------|--------|-----|
| `balance`, `held_balance`, `pending_balance` | `users` | **Bryan** | balance trigger + topup/withdraw RPCs |
| `status`, `bengkel_id`, `estimated_price` (on accept) | `service_requests` | **Eugene** | `accept_bid` |
| `mechanic_id`, `status` (→in_progress) | `service_requests` | **Rei** | assignment RPC |
| `status` (→completed/cancelled), `*_completed`, `completion_photo_url` | `service_requests` | **Jason** | `mark_order_completed`, `open_dispute` |
| `rating`, `review`; `bengkels.average_rating` | `service_requests` / `bengkels` | **Jason** | `rate_order` + recompute trigger |

The escrow columns (`held_balance`, `pending_balance`) exist as of this prep PR (default 0).
**Money MOVEMENT is unimplemented** — `accept_bid` only *gates* on `balance - held_balance`.
The hold-on-create / settle-on-complete / refund-on-cancel triggers are Bryan's work.

## 3. RPC signatures (the cross-tier API)

| RPC | Owner | Signature → returns | Notes |
|-----|-------|---------------------|-------|
| `accept_bid` | Eugene | `(p_bid_id uuid) → service_requests` | atomic; balance-gated; auto-rejects sibling bids |
| `nearby_service_requests` | Eugene | `(p_lat, p_lon, p_radius_m=5000) → setof` | open orders for a bengkel feed |
| `nearby_bengkels` | Eugene | `(p_lat, p_lon, p_radius_m=5000) → setof` | verified bengkels near a customer |
| `assign_mechanic` _(TBD)_ | Rei | `(p_request_id uuid, p_mechanic_id uuid?) → service_requests` | null `p_mechanic_id` ⇒ "Self" |
| `mark_order_completed` _(TBD)_ | Jason | `(p_request_id uuid, p_photo_url text?) → service_requests` | dual-confirm gate + mandatory provider proof |
| `rate_order` _(TBD)_ | Jason | `(p_request_id uuid, p_rating int, p_review text?) → service_requests` | write-once; fires rating recompute |
| `open_dispute` _(TBD)_ | Jason | `(p_request_id uuid, p_reason text, p_proof_url text?)` | unwind + audit row |
| `settle_topup`, `request_withdrawal` _(TBD)_ | Bryan | see MbengkelIn reference | Midtrans webhook + payout |

`_(TBD)_` = not yet written; each owner authors theirs as a new migration. Adapt from
MbengkelIn's RPCs (`MbengkelIn-Eugene/supabase/migrations/`) but re-align to BengkelIn's
lowercase status values and `double precision` money, and re-thread the **mechanic** actor.

## 4. Bids table (Eugene)

`bids(id, service_request_id, provider_uid, bengkel_id, price double, notes, status text, created_at)`,
unique on `(service_request_id, provider_uid)`. Status text:
`pending | accepted | rejected | autorejected | expired`. Realtime-published. See the
`20260602120000_bidding_and_escrow_foundation.sql` migration.

## 5. Shared Swift shell files — edit by small additive PR, coordinate first

These are the only client files multiple people touch; new files are conflict-free
(Xcode 16 synchronized groups), but these are shared:

- `ContentView.swift` — the 4-tab `TabView` + role switcher. Adding/replacing a tab → announce.
- `Views/Pages/Dashboard/DashboardView.swift` — per-role dashboards. Add your entry-point card in your section.
- `Models/User.swift` — Bryan adds `heldBalance` / `pendingBalance` Swift fields when wiring the money tier.
- `Models/ServiceRequest.swift` — make `bengkelId` optional (bidding); add Closeout flags. Coordinate: Eugene + Jason.

## 6. Backend deploy

Schema/functions deploy to Supabase project `ipxwpxozreksmuiztwcy` via the **Supabase MCP**
(wired in `.mcp.json`) or `supabase db push` / `supabase functions deploy`. All schema changes
are committed as `supabase/migrations/*.sql` — **no more dashboard-only edits.**

## 7. Status of this prep PR

- ✅ `.mcp.json` (Supabase MCP), `supabase/` baseline, bidding+escrow migration (DRAFT — verify vs live schema), bidding edge function (DRAFT), this file.
- ⏳ **Not yet:** introspect + verify + apply the migration; deploy the function; create the Xcode Unit-Test target (do this in Xcode: File ▸ New ▸ Target ▸ Unit Testing Bundle — it's the one unavoidable `.pbxproj` edit, land it on `main`); the per-tier `_(TBD)_` RPCs.
