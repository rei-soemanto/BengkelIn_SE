# BengkelIn — Parity-Port Plan (Bryan & Eugene)

_Authoritative plan. Supersedes the ALP-root `split-decision.md` /
`bryan-eugene-split-decision.md` / `finish-plan.md`. Companion: `CONTRACTS.md`._

## Strategy

1. **Reach MbengkelIn parity (iOS only — no watch) by porting each person's OWN
   MbengkelIn implementation into BengkelIn.** Split follows MbengkelIn git authorship
   so everyone ports code they wrote.
2. **Combine the two backends:** bring MbengkelIn's Supabase schema + logic into
   BengkelIn's project (`tednrjmhtusdglsembzu`), reconciled to BengkelIn's conventions.
3. **Mechanics LAST** — added only after parity. This is the one true differentiator
   (a bengkel assigns a mechanic / "Self" to an accepted job; chat, tracking, and
   completion re-thread onto that mechanic). Everything before it is parity.
4. **Workflow:** commit directly to `main`, sequentially (no feature branches);
   pull-before / push-after on shared files.

## Ownership — from MbengkelIn authorship (dominant author per ViewModel)

| BengkelIn feature to port | MbengkelIn source (author) | Owner |
|---|---|---|
| Bidding — customer + bengkel | `CustomerBiddingViewModel`, `BengkelBiddingViewModel` (Bryan) | **Bryan** |
| Order creation | `OrderViewModel` (Bryan) | **Bryan** |
| Customer order history | `HistoryViewModel` (Bryan) | **Bryan** |
| Wallet / top-up (Midtrans) | `PaymentViewModel` + `PaymentService` + `payment`/`midtrans-webhook` fns (Eugene) | **Eugene** |
| Withdrawals | `PaymentViewModel` + `request_withdrawal` (Eugene) | **Eugene** |
| Completion + proof photo | `OrderCompletionViewModel` (Eugene) | **Eugene** |
| Reviews / ratings | `OrderRatingViewModel` (Eugene) | **Eugene** |
| Chat | `ChatViewModel` (Eugene) | **Eugene** |
| Live tracking | `OrderTrackingViewModel`, `LocationPublishViewModel`, `BengkelRouteViewModel` (Eugene) | **Eugene** |
| Disputes / behavior reports | `BehaviorReportViewModel` (Eugene) | **Eugene** |
| Bengkel order history | `BengkelHistoryViewModel` (Eugene) | **Eugene** |

> **Load imbalance (flagged):** by feature *count* Eugene carries more, but several are
> small (reviews, disputes, chat were 1–2 commits each) while Bryan's bidding is the
> single heaviest piece. If you want it evener without much cross-porting, the cleanest
> rebalance is **Bryan also takes Reviews + Customer History** (small, adjacent to his
> order/bidding flow). Default below keeps strict authorship; say the word to rebalance.

## Phase 0 — Combine the migrations (backend parity)  ·  shared, do FIRST

Goal: BengkelIn's DB gains MbengkelIn's full backend, **adapted** (not copied) to
BengkelIn's conventions. Authored as new `supabase/migrations/*.sql`, applied via the
Supabase MCP. Mapping rules for every ported object:

- **Status values:** MbengkelIn `To Do / On Progress / Done / Cancelled` → BengkelIn
  lowercase `pending / accepted / in_progress / completed / cancelled`.
- **Money type:** MbengkelIn `bigint price` → BengkelIn `numeric` (`estimated_price`,
  `bids.price`); balances stay `double precision`.
- **Service types:** keep BengkelIn's text `service_type` (already converted from enum).

Already in place (done): `bids`, `accept_bid`, `nearby_*`, `bidding` fn, `held_balance`/
`pending_balance` columns, `service_requests.vehicle_id`, realtime on `bids`/`service_requests`.

Still to combine (the MbengkelIn delta), grouped by who owns the matching feature:

- **Eugene (money/closeout/comms schema):**
  - `service_requests` columns: `customer_completed`, `provider_completed`,
    `completion_photo_url`, `completed_at`, `rating`, `review`.
  - `users` columns: `bank_name`, `bank_account_number`, `bank_account_name`.
  - New tables: `topups`, `withdrawals`, `chat_messages`, `order_locations`,
    `order_disputes`, `behavior_reports`.
  - RPCs/triggers (rewritten to BengkelIn status/money): `increment_user_balance`,
    `settle_topup`, `request_withdrawal`/`reject_withdrawal`, `mark_order_completed`
    (dual-confirm + proof + settle), `rate_order` + bengkel-rating recompute trigger,
    `open_dispute`, and the **balance hold/settle/refund trigger** on `service_requests`.
  - Edge functions: `payment`, `midtrans-webhook`, `_shared/midtrans.ts` (deploy; set
    `MIDTRANS_SERVER_KEY` sandbox secret + register webhook URL).
  - Realtime publications + RLS for the new tables (chat, locations, topups, withdrawals).
- **Bryan (order/bidding schema):**
  - `service_requests` columns his flow needs for parity: `tire_count`, `photo_urls`
    (jsonb), `vehicle_info`. (`bengkel_id` nullable + bidding already done.)

Coordinate: one shared DB — author migrations sequentially, don't both alter the same
object at once.

## Phase 1 — iOS feature port (parity)  ·  Bryan ∥ Eugene

Each owner ports their MbengkelIn VMs/views into BengkelIn (Repository/Service/DTO +
`@MainActor` VM + `isLoading`/`errorMessage` conventions, realtime via the sanctioned
channel pattern). Reuse backend pattern; rewrite Swift to BengkelIn types.

- **Bryan:**
  1. **Bidding** — *data layer + both ViewModels already on `main`*; remaining = the
     bidding **Views** (customer broadcast/offers, bengkel nearby-feed/place-bid) +
     dashboard entry points. Decide retire-vs-keep the old direct-request flow.
  2. **Order creation** parity (port `OrderViewModel` logic into the broadcast flow).
  3. **Customer order History** tab (replace the History placeholder).
- **Eugene:**
  1. **Wallet/Payments** — `Topup`, `PaymentViewModel`, top-up (Snap WebView), replace
     `PaymentPlaceholderView`; **Withdrawals** + bank-details.
  2. **Completion + proof** (entry from the mechanic/bengkel job screen).
  3. **Reviews** (rating sheet + aggregate display).
  4. **Chat** (room/list, image messages).
  5. **Live tracking** (publish VM + tracking map).
  6. **Disputes / behavior reports** (file-with-evidence + status).
  7. **Bengkel order history**.

## Phase 2 — Mechanics (LAST — the differentiator)

- `assign_mechanic(request_id, mechanic_id?)` RPC: `accepted → in_progress`, set
  `mechanic_id` (null = "Self"); builds on Rei/Jason's existing roster
  (`mechanic_registrations`).
- Re-thread **chat, live tracking, completion** onto the assigned **mechanic** actor
  (not the bengkel) — this is where sequences/classes diverge from MbengkelIn.
- Mechanic active-job / task screens; finish roster wiring.

## Status / already done
- Bidding backend (hardened) + data layer + both bidding VMs on `main`.
- `service_requests` reconciled (`vehicle_id`, `service_type→text`, `bengkel_id` nullable);
  escrow columns (`held_balance`/`pending_balance`) added.

## Risks
- **UI similarity:** 7 of 17 shared View files are byte-identical-except-header (copied
  scaffold); porting more MbengkelIn views *increases* similarity. The mechanics layer +
  a later visual-differentiation pass (distinct design system, renamed/restructured
  components) is the mitigation. Track explicitly.
- **Migration mapping correctness:** status-value + money-type rewrites must be verified
  against the live schema (introspect via MCP before each apply).
- **Load imbalance** Bryan vs Eugene (see note above).

## Definition of done
Full loop: top-up → broadcast → bid → accept → (assign mechanic) → chat + track →
complete + proof → pay → review; complaint → refund. Then reconcile the Integrated Doc.
