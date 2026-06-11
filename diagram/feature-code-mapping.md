# BengkelIn — Diagram → Code Mapping (presentation cheat-sheet)

For each feature (§1–§11) this maps every box in the per-feature class diagram
(`feature-class-diagrams.md`) to its **exact file + line** in `BengkelIn_SE/`.
Use it to say "this class on the slide *is* this line of code."

All paths are under `BengkelIn_SE/`. Line numbers are the **declaration line**
(class/struct/enum/func). Layer legend: **VM** = ViewModel, **Repo** = Repository,
**Svc** = Service, **DTO** = payload struct, **Model** = domain struct.

> Shared classes (`AuthService`, `StorageService`, `NotificationService`,
> `NearbyOrder`, `OrderRepository`, `LoadingPhase`) appear in several diagrams.
> They are defined **once** — listed in full the first time, then referenced.

---

## Shared / cross-feature classes (defined once)

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `AuthService` | Svc | `Services/AuthService.swift` | 21 |
| `AuthServiceError` (enum) | Svc | `Services/AuthService.swift` | 11 |
| `StorageService` | Svc | `Services/StorageService.swift` | 11 |
| `NotificationService` | Svc | `Services/NotificationService.swift` | 11 |
| `LocationService` | Svc | `Services/LocationService.swift` | 11 |
| `ImageCompressor` (enum) | Svc | `Services/ImageCompressor.swift` | 10 |
| `OrderRepository` | Repo | `Repositories/OrderRepository.swift` | 11 |
| `NearbyOrder` | Model | `Models/NearbyOrder.swift` | 10 |
| `LoadingPhase` (enum) | enum | `Views/Components/LoadingOverlay.swift` | 10 |
| `LocationSearchable` (interface) | Protocol | `Protocols/LocationSearchable.swift` | 11 |
| `PhotonSearchFeature` / `Properties` / `Geometry` | Model | `Models/PhotonSearchResponse.swift` | 14 / 32 / 40 |

`OrderRepository` methods (cited across §4/§6/§7/§8/§10/§11):
`createOrder` 12 · `fetchOrders` 21 · `fetchTodaysEarnings` 30 · `fetchBengkelOrders` 43 ·
`fetchMechanicOrders` 52 · `fetchOrder` 61 · `deleteOrder` 70 · `updateOrderPrice` 77 ·
`cancelOrder` 84 · `openDispute` 93 · `submitRating` 103 · `markOrderCompleted` 112 ·
`fetchActiveOrder` 122 · `acceptBid` 135 — all in `Repositories/OrderRepository.swift`.

---

## §1 · Authentication & Profilea

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `AuthViewModel` | VM | `ViewModels/AuthViewModel.swift` | 19 |
| `AppMode` (enum) | enum | `ViewModels/AuthViewModel.swift` | 12 |
| `ProfileViewModel` | VM | `ViewModels/ProfileViewModel.swift` | 13 |
| `UserRepository` | Repo | `Repositories/UserRepository.swift` | 11 |
| `User` | Model | `Models/User.swift` | 10 |
| `SignUpRequest` | DTO | `Models/DTOs/AuthDTOs.swift` | 10 |
| `ProfileUpdatePayload` | DTO | `Models/DTOs/AuthDTOs.swift` | 17 |
| `ProfileImageUpdatePayload` | DTO | `Models/DTOs/AuthDTOs.swift` | 21 |
| `BankDetailsUpdatePayload` | DTO | `Models/DTOs/WithdrawalDTOs.swift` | 10 |

**Key methods to point at**
`AuthViewModel`: `login` 70 · `signUp` 86 · `fetchUser` 111 · `deleteAccount` 151 · `signOut` 173.
`ProfileViewModel`: `updateProfile` 22 · `uploadProfileImage` 53.
`UserRepository`: `fetchUser` 12 · `updateProfile` 21 · `updateProfileImageUrl` 28 · `updateBankDetails` 35 · `deleteUser` 42.
`AuthService`: `signIn` 46 · `signUp` 50 · `signOut` 64 · `resetPassword` 68.

---

## §2 · Vehicles

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `VehicleViewModel` | VM | `ViewModels/VehicleViewModel.swift` | 13 |
| `VehicleRepository` | Repo | `Repositories/VehicleRepository.swift` | 11 |
| `Vehicle` | Model | `Models/Vehicle.swift` | 10 |
| `VehicleUpdatePayload` | DTO | `Models/DTOs/VehicleDTOs.swift` | 10 |

**Key methods**
`VehicleViewModel`: `fetchVehicles` 22 · `addVehicle` 34 · `updateVehicle` 70 · `deleteVehicle` 99.
`VehicleRepository`: `fetchVehicles` 12 · `insertVehicle` 20 · `updateVehicle` 26 · `deleteVehicle` 33.

---

## §3 · Bengkel Management & Location Picking

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `BengkelViewModel` (realizes `LocationSearchable`) | VM | `ViewModels/BengkelViewModel.swift` | 15 |
| `BengkelRepository` | Repo | `Repositories/BengkelRepository.swift` | 11 |
| `Bengkel` | Model | `Models/Bengkel.swift` | 10 |
| `BengkelService` | Model | `Models/BengkelService.swift` | 46 |
| `ServiceType` (enum) | enum | `Models/BengkelService.swift` | 10 |
| `BengkelUpdatePayload` | DTO | `Models/DTOs/BengkelDTOs.swift` | 10 |
| `BengkelServicesUpdatePayload` | DTO | `Models/DTOs/BengkelDTOs.swift` | 17 |

**Key methods**
`BengkelViewModel`: `registerBengkel` 154 · `updateBengkel` 321 · `deleteBengkel` 345 ·
`addService` 365 · `updateService` 399 · `deleteService` 427 · `loadTodaysEarnings` 230 ·
`startWatching` 214 · realtime sub `startRealtimeSubscription` 238 / earnings 261.
`LocationSearchable` impl: `useCurrentLocation` 90 · `selectSearchResult` 73 · `updateLocationFromMap` 135 · `searchOSM` 62.
`BengkelRepository`: `fetchBengkel` 12 · `fetchById` 21 · `insertBengkel` 30 · `updateBengkel` 36 · `updateServices` 43 · `deleteBengkel` 50.
`LocationService`: `searchOSM` 12 · `fetchAddress` 23.

---

## §4 · Order Creation & Bidding (core marketplace)

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `OrderViewModel` (realizes `LocationSearchable`) | VM | `ViewModels/OrderViewModel.swift` | 15 |
| `CustomerBiddingViewModel` | VM | `ViewModels/CustomerBiddingViewModel.swift` | 13 |
| `BengkelBiddingViewModel` | VM | `ViewModels/BengkelBiddingViewModel.swift` | 13 |
| `BiddingService` (edge fn) | Svc | `Services/BiddingService.swift` | 11 |
| `BidRepository` | Repo | `Repositories/BidRepository.swift` | 11 |
| `Bid` | Model | `Models/Bid.swift` | 10 |
| `ServiceRequestPayload` | DTO | `Models/DTOs/OrderDTOs.swift` | 10 |
| `CreatedServiceRequest` | DTO | `Models/DTOs/OrderDTOs.swift` | 26 |
| `AcceptBidParams` | DTO | `Models/DTOs/OrderDTOs.swift` | 44 |
| `CancelOrderParams` | DTO | `Models/DTOs/OrderDTOs.swift` | 48 |
| `StartSearchPayload` | DTO | `Models/DTOs/OrderDTOs.swift` | 52 |
| `TodaysEarningRow` | DTO | `Models/DTOs/OrderDTOs.swift` | 36 |
| `BidStatusUpdate` | DTO | `Models/DTOs/OrderDTOs.swift` | 40 |
| `OrdersRequest` / `OrdersResponse` | DTO | `Models/DTOs/OrderDTOs.swift` | 61 / 68 |
| `PlaceBidRequest` / `PlaceBidResponse` | DTO | `Models/DTOs/OrderDTOs.swift` | 72 / 80 |

**Key methods**
`OrderViewModel` (compose + validate + upload, *then* navigate): `selectService` 234 ·
`setTireCount` 241 · `calculateEstimate` 252 · `createOrder` 261 · `validateOrder` 270 ·
`beginOrder` 299 · `loadVehicles` 182 · `loadUserPoints` 190.
`CustomerBiddingViewModel` (**this is where the order is actually created** — `startSearch`):
`startSearch` 120 · `acceptBid` 369 · `rejectBid` 388 · `raisePrice` 223 · realtime 282/308 ·
search countdown 184 · bid expiry 413/429.
`BengkelBiddingViewModel`: `loadOrders` 162 · `placeBid` 255 · realtime sub 108 · `handleExpiredOrder` 296.
`BiddingService`: `fetchOrdersForMechanic` 12 · `placeBid` 27.
`BidRepository`: `fetchAcceptedBid` 12 · `fetchBids` 23 · `fetchBidsForBengkel` 32 · `updateStatus` 40.

> Note (matches the diagram's caption): `createOrder()` on `OrderViewModel:261` only
> validates/uploads; the real DB insert happens in `CustomerBiddingViewModel.startSearch():120`.

---

## §5 · Mechanics & Roster

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `BengkelRosterViewModel` | VM | `ViewModels/BengkelRosterViewModel.swift` | 13 |
| `MechanicInviteViewModel` | VM | `ViewModels/MechanicInviteViewModel.swift` | 13 |
| `AssignMechanicViewModel` | VM | `ViewModels/AssignMechanicViewModel.swift` | 13 |
| `MechanicDashboardViewModel` | VM | `ViewModels/MechanicDashboardViewModel.swift` | 13 |
| `MechanicJobsViewModel` | VM | `ViewModels/MechanicJobsViewModel.swift` | 13 |
| `MechanicRepository` | Repo | `Repositories/MechanicRepository.swift` | 11 |
| `MechanicAssignmentRepository` | Repo | `Repositories/MechanicAssignmentRepository.swift` | 11 |
| `RosterMember` | Model | `Models/MechanicRegistration.swift` | 10 |
| `MechanicInvite` | Model | `Models/MechanicRegistration.swift` | 32 |
| `AvailableMechanic` | Model | `Models/MechanicRegistration.swift` | 51 |
| `InviteMechanicParams` | DTO | `Models/DTOs/MechanicDTOs.swift` | 10 |
| `RespondInviteParams` | DTO | `Models/DTOs/MechanicDTOs.swift` | 14 |
| `RemoveMechanicParams` | DTO | `Models/DTOs/MechanicDTOs.swift` | 19 |
| `AssignMechanicParams` | DTO | `Models/DTOs/MechanicAssignmentDTOs.swift` | 10 |
| `AvailableMechanicsParams` | DTO | `Models/DTOs/MechanicAssignmentDTOs.swift` | 15 |

**Key methods**
`BengkelRosterViewModel`: `fetchRoster` 26 · `invite` 40 · `remove` 65.
`MechanicInviteViewModel`: `fetchInvites` 23 · `respond` 37.
`AssignMechanicViewModel`: `fetchAvailableMechanics` 22 · `assign` 36.
`MechanicDashboardViewModel`: `start` 39 · `loadJobs` 82 · `subscribe` 113 · `handleAssigned` 160 · `handleReassignedAway` 164.
`MechanicRepository`: `fetchRoster` 12 · `inviteMechanic` 18 · `removeMechanic` 26 · `fetchAvailableMechanics` 34 · `fetchMyInvites` 43 · `respondToInvite` 49.
`MechanicAssignmentRepository`: `assignMechanic` 14 · `fetchAssignedJobs` 24.

---

## §6 · Chat

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `ChatViewModel` | VM | `ViewModels/ChatViewModel.swift` | 13 |
| `ChatWatchViewModel` | VM | `ViewModels/ChatWatchViewModel.swift` | 13 |
| `ChatRepository` | Repo | `Repositories/ChatRepository.swift` | 11 |
| `ChatReadCursor` | Svc/helper | `Services/ChatReadCursor.swift` | 10 |
| `ChatPresence` | Svc/helper | `Services/ChatPresence.swift` | 11 |
| `ChatMessage` | Model | `Models/ChatMessage.swift` | 10 |
| `ChatMessagePayload` | DTO | `Models/DTOs/ChatDTOs.swift` | 10 |

**Key methods**
`ChatViewModel`: `start` 43 · `loadMessages` 52 · `loadLockState` 62 · realtime sub 70 · `sendText` 110 · `sendImage` 118 · `send` 135.
`ChatWatchViewModel`: `start` 45 · `subscribe` 68 · `reload` 86 · `markAllRead` 63 · `notificationBody` 111.
`ChatRepository`: `fetchMessages` 12 · `sendMessage` 21.
`ChatReadCursor`: `markRead` 20 · `unreadCount` 24 · `date(of:)` 29.

---

## §7 · Live Location Tracking

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `OrderTrackingViewModel` (customer map) | VM | `ViewModels/OrderTrackingViewModel.swift` | 14 |
| `BengkelRouteViewModel` (provider/mechanic map) | VM | `ViewModels/BengkelRouteViewModel.swift` | 21 |
| `RouteLocationStore` | VM-owned holder | `ViewModels/BengkelRouteViewModel.swift` | 14 |
| `LocationPublishViewModel` | VM | `ViewModels/LocationPublishViewModel.swift` | 14 |
| `CustomerLocationPublishViewModel` | VM | `ViewModels/CustomerLocationPublishViewModel.swift` | 14 |
| `OrderLocationRepository` | Repo | `Repositories/OrderLocationRepository.swift` | 11 |
| `OrderLocation` | Model | `Models/OrderLocation.swift` | 10 |
| `CustomerLocation` | Model | `Models/CustomerLocation.swift` | 10 |
| `OrderLocationPayload` | DTO | `Models/DTOs/OrderDTOs.swift` | 84 |
| `CustomerLocationPayload` | DTO | `Models/DTOs/OrderDTOs.swift` | 91 |

**Key methods**
`OrderTrackingViewModel`: `start` 41 · `stop` 99 · `openDispute` 109 · `apply(location)` 149.
`BengkelRouteViewModel`: `start` 102 · `reconfigureForRole` 187 · `reportIssue` 234 · CLLocation publish 309.
`LocationPublishViewModel`: `start` 40 · `observeOrderStatus` 58 · `publish` 138.
`CustomerLocationPublishViewModel`: `start` 38 · `publish` 74.
`OrderLocationRepository`: `upsertLocation` 12 · `fetchLocation` 18 · `upsertCustomerLocation` 28 · `fetchCustomerLocation` 34.

---

## §8 · Order Completion & Rating

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `OrderCompletionViewModel` | VM | `ViewModels/OrderCompletionViewModel.swift` | 13 |
| `OrderRatingViewModel` | VM | `ViewModels/OrderRatingViewModel.swift` | 13 |
| `MarkCompletedParams` | DTO | `Models/DTOs/ChatDTOs.swift` | 17 |
| `RateOrderParams` | DTO | `Models/DTOs/OrderDTOs.swift` | 56 |

**Key methods**
`OrderCompletionViewModel`: `start` 49 · `refresh` 55 · `notifyOnCounterpartCompletion` 67 · realtime sub 89 · `markCompleted` 115.
`OrderRatingViewModel`: `submit` 19.
`OrderRepository` (the RPCs): `markOrderCompleted` 112 · `submitRating` 103.

---

## §9 · Payment / Wallet · Escrow

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `PaymentViewModel` | VM | `ViewModels/PaymentViewModel.swift` | 18 |
| `PaymentService` (edge fn) | Svc | `Services/PaymentService.swift` | 11 |
| `TopupRepository` | Repo | `Repositories/TopupRepository.swift` | 11 |
| `WithdrawalRepository` | Repo | `Repositories/WithdrawalRepository.swift` | 11 |
| `Topup` | Model | `Models/Topup.swift` | 10 |
| `Withdrawal` | Model | `Models/Withdrawal.swift` | 10 |
| `IndonesianBank` | Model | `Models/Bank.swift` | 10 |
| `CreateTopupRequest` / `CreateTopupResponse` | DTO | `Models/DTOs/PaymentDTOs.swift` | 10 / 15 |
| `BankDetailsUpdatePayload` | DTO | `Models/DTOs/WithdrawalDTOs.swift` | 10 |
| `RequestWithdrawalParams` | DTO | `Models/DTOs/WithdrawalDTOs.swift` | 16 |

**Key methods**
`PaymentViewModel`: `start` 70 · realtime sub 75 · `refresh` 121 · `detectSuccessfulTopups` 151 ·
`startTopup` 167 · `saveBankDetails` 194 · `requestWithdrawal` 219 · `resumeTopup` 250.
`PaymentService`: `createTopup` 12.
`TopupRepository`: `fetchTopups` 12. `WithdrawalRepository`: `fetchWithdrawals` 12 · `requestWithdrawal` 21.

> The escrow state machine is **server-side** (Postgres trigger `handle_order_balance`),
> not in iOS — the app only changes order status. Point at the SQL in
> `supabase/schema/payment.sql` / `orders.sql` if asked where the money moves.

---

## §10 · Order History (per role)

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `HistoryViewModel` (customer) | VM | `ViewModels/HistoryViewModel.swift` | 14 |
| `BengkelHistoryViewModel` | VM | `ViewModels/BengkelHistoryViewModel.swift` | 13 |
| `MechanicHistoryViewModel` | VM | `ViewModels/MechanicHistoryViewModel.swift` | 13 |

**Key methods**
`HistoryViewModel`: `loadOrders` 30 · `select` 56 · `openTracking` 66.
`BengkelHistoryViewModel`: `loadOrders` 37 · realtime 66 · `select` 91.
`MechanicHistoryViewModel`: `loadOrders` 46 · `select` 69.
All three read via `OrderRepository.fetchOrders` 21 / `fetchBengkelOrders` 43 / `fetchMechanicOrders` 52.

---

## §11 · Behavior Reports & Disputes

| Diagram box | Layer | File | Line |
|---|---|---|---|
| `BehaviorReportViewModel` | VM | `ViewModels/BehaviorReportViewModel.swift` | 13 |
| `BehaviorReportRepository` | Repo | `Repositories/BehaviorReportRepository.swift` | 11 |
| `BehaviorReportPayload` | DTO | `Models/DTOs/OrderDTOs.swift` | 98 |
| `ReportedRequestRow` | DTO | `Models/DTOs/OrderDTOs.swift` | 104 |
| `OpenDisputeParams` | DTO | `Models/DTOs/OrderDTOs.swift` | 30 |

**Key methods**
`BehaviorReportViewModel`: `submit` 20.
`BehaviorReportRepository`: `submit` 12 · `fetchReportedRequestIds` 22.
Dispute path: `OrderRepository.openDispute` 93 (called from `OrderTrackingViewModel.openDispute` 109
and `BengkelRouteViewModel.reportIssue` 234) → trigger cancels + refunds server-side.

---

## PPT code-snippet picker — exact line ranges to paste per slide

Each row is **one self-contained, slide-sized snippet** (the shaded `start–end`
range is what to screenshot/paste). Each pair shows the **layer boundary**: a
ViewModel method (orchestration + state) and the Repository/Service method it calls
(the only layer that touches Supabase). Pick the VM snippet for the main slide; add
the Repo/Service snippet as the "and here's where it hits the backend" follow-up.

| § | Snippet (what it proves) | File | **Lines** |
|---|---|---|---|
| 1 | `AuthViewModel.login` — VM: `isLoading`→try/catch→`fetchUser` | `ViewModels/AuthViewModel.swift` | **70–84** |
| 1 | ↳ `UserRepository.fetchUser` — Repo: `supabase.from("users")` | `Repositories/UserRepository.swift` | **12–19** |
| 2 | `VehicleViewModel.addVehicle` — VM builds Model, calls Repo, re-fetches | `ViewModels/VehicleViewModel.swift` | **44–68** |
| 2 | ↳ `VehicleRepository` (full CRUD, 4 tiny methods) | `Repositories/VehicleRepository.swift` | **11–34** |
| 3 | `BengkelViewModel.addService` — VM mutates Model + sends DTO | `ViewModels/BengkelViewModel.swift` | **365–397** |
| 3 | ↳ `BengkelRepository.updateServices` — Repo update | `Repositories/BengkelRepository.swift` | **43–48** |
| 4 | `BengkelBiddingViewModel.placeBid` — guards + edge-fn call (core) | `ViewModels/BengkelBiddingViewModel.swift` | **276–294** |
| 4 | ↳ `BiddingService.placeBid` — Svc invokes `bidding` **edge function** | `Services/BiddingService.swift` | **26–40** |
| 5 | `AssignMechanicViewModel.assign` — VM (whole tiny VM is 12–51) | `ViewModels/AssignMechanicViewModel.swift` | **35–50** |
| 5 | ↳ `MechanicAssignmentRepository.assignMechanic` — RPC | `Repositories/MechanicAssignmentRepository.swift` | **14–23** |
| 6 | `ChatViewModel.startRealtimeSubscription` — **realtime channel** (the signature slide) | `ViewModels/ChatViewModel.swift` | **70–99** |
| 6 | ↳ `ChatRepository` (fetch + send) | `Repositories/ChatRepository.swift` | **11–29** |
| 7 | `OrderTrackingViewModel.start` — subscribe to `order_locations` + `service_requests` (larger — give it a full slide) | `ViewModels/OrderTrackingViewModel.swift` | **41–97** |
| 7 | ↳ `OrderLocationRepository.upsertLocation` — publish GPS | `Repositories/OrderLocationRepository.swift` | **12–16** |
| 8 | `OrderCompletionViewModel.markCompleted` — upload proof photo **then** RPC | `ViewModels/OrderCompletionViewModel.swift` | **115–131** |
| 8 | ↳ `OrderRepository.markOrderCompleted` — `mark_order_completed` RPC | `Repositories/OrderRepository.swift` | **111–120** |
| 9 | `PaymentViewModel.startTopup` — VM validates, calls edge fn, opens Snap URL | `ViewModels/PaymentViewModel.swift` | **167–192** |
| 9 | ↳ `PaymentService.createTopup` — Svc invokes `payment` edge function | `Services/PaymentService.swift` | **12–** (whole method) |
| 10 | `HistoryViewModel.loadOrders` — session→Repo→sort | `ViewModels/HistoryViewModel.swift` | **30–50** |
| 10 | ↳ `OrderRepository.fetchOrders` | `Repositories/OrderRepository.swift` | **21–28** |
| 11 | `BehaviorReportViewModel.submit` — full VM incl. duplicate-report handling | `ViewModels/BehaviorReportViewModel.swift` | **12–43** |
| 11 | ↳ `OrderRepository.openDispute` — `open_dispute` RPC (dispute path) | `Repositories/OrderRepository.swift` | **93–101** |

**One "architecture" slide (use before the feature walkthrough):** put
`AuthViewModel.login` (70–84) and `UserRepository.fetchUser` (12–19) **side by side** —
left box = ViewModel (state + orchestration, never touches `supabase`), right box =
Repository (the only `supabase.from(...)` caller). That single pairing is your whole
Layered-MVVM thesis in two snippets.

**Best single "wow" snippet:** `ChatViewModel.startRealtimeSubscription` (70–99) — it
shows the live `supabase.channel(...)` + `postgresChange` stream pattern that the
CLAUDE.md calls "realtime is pervasive." Same shape recurs in §7 tracking (41–97).

> Trimming tip: the VM snippets all follow `isLoading = true` → `do { … repo call … }`
> `catch { errorMessage = error.localizedDescription }` → `isLoading = false`. If a range
> is one or two lines too tall for a slide, cut the validation `guard`s at the top, not
> the `do/catch` — the do/catch is the part that proves the layering.

---

### How to present each slide in one breath
"On the diagram, **`<ClassName>`** maps to **`<File>:<line>`**. The ViewModel's
`@Published` state is the top of the file; the public methods on the box are the
`func`s I just listed — each one calls down into the Repository/Service shown by the
arrow, which is the only layer allowed to touch Supabase."
