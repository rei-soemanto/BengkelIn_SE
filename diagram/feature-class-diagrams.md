# BengkelIn — Per-Feature Class Diagrams

Class diagrams for the iOS app (`BengkelIn_SE/`), split by feature. Each section is an independent, directly-renderable Mermaid `classDiagram` showing that feature's ViewModels, the Repositories/Services they depend on, and the Models/DTOs that flow through them.

**Layers** (identify by class-name suffix / annotation): `*ViewModel` = ViewModel · `*Repository` = Repository · `*Service` = Service · `*Payload`/`*Params`/`*Request`/`*Response` = DTO · `<<interface>>` = Protocol · `<<enumeration>>` = Enum · everything else = Model.

**Arrows**: `..>` depends on / uses · `-->` association · `*--` composition · `..|>` realizes interface.

> All ViewModels are `@MainActor ObservableObject`. **Every member is shown** — `+` = public surface (`@Published` state, computed properties, public methods, `init`/`deinit`), `-` = private implementation (injected Repository/Service dependencies, realtime channels & reader tasks, `CLLocationManager`, and private helper methods). Swift has no `protected`; its default `internal` and `private(set)` members are rendered with the closest UML symbol (`-` for private/internal stored state that isn't part of the API, `+` for publicly-readable members). Repositories/Services are stateless and expose only the public methods listed. **Injected Service/Repository dependencies are shown as plain association arrows with multiplicities (`ViewModel "1" --> "1" AuthService`), not repeated as attributes** — the arrow IS the field, so listing it in the attribute box too would be redundant (a property typed by another class and an association are the same thing in UML). Edge labels are semantic association names (verbs: `reads/updates`, `manages`, `displays`, `tracks`, `contains`, `embeds`, `owns`, `listens`, `publishes via`, `sends`, `returns`, …) describing what the relationship does — not field names. Multiplicity (`1`, `0..1`, `*`) is derived from the field's Swift type (`X`, `X?`, `[X]`). Value/state attributes, model references, enums, and types without their own box (`Task`, `CLLocationManager`, `RealtimeChannelV2`, `Set`) remain in the attribute compartment. See the root `CLAUDE.md` for the layering rules.

---

## 0. Feature Map (Overview)

One box per feature instead of per class — the whole app at a glance, following the order lifecycle. Use this as the intro slide; the per-feature class diagrams (§1–§11) drill into each box. Solid arrows = the main flow; dashed = money/escrow effects that the Postgres triggers enforce server-side.

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
flowchart TB
    subgraph APP["📱 iOS App — SwiftUI · Layered MVVM"]
        direction TB
        A["1 · Auth &amp; Profile"]
        V["2 · Vehicles"]
        B["3 · Bengkel &amp; Location"]
        O["4 · Order Creation &amp; Bidding"]
        M["5 · Mechanics &amp; Roster"]
        C["6 · Chat"]
        T["7 · Live Tracking"]
        D["8 · Completion &amp; Rating"]
        P["9 · Payment / Wallet · Escrow"]
        H["10 · Order History"]
        R["11 · Reports &amp; Disputes"]

        A --> V
        A --> B
        V --> O
        B --> O
        O -->|bid accepted| M
        M --> C
        M --> T
        C --> D
        T --> D
        D --> H
        P -. "hold on broadcast / release" .-> O
        P -. "settle on complete" .-> D
        R -. "dispute → cancel → refund" .-> P
    end
    APP === SB[("☁️ Supabase<br/>Postgres + RLS · Realtime · Storage<br/>Edge Fns: bidding · payment · midtrans-webhook")]

```

---

## Pembagian Presentasi per Anggota (berdasarkan git commit)

Setiap fitur (§1–§11) dipresentasikan oleh **pembuat asli** ViewModel-nya — ditentukan dari *first commit* tiap file di git history (bukan sekadar header "Created by"). Bryan melakukan *port/konsolidasi* lintas-fitur di akhir (lihat `PLAN.md`), jadi penyaji ditetapkan berdasarkan **siapa yang pertama membangun fitur**, bukan jumlah commit total.

| § | Fitur | Penyaji utama | Kontributor / catatan |
|---|-------|---------------|------------------------|
| 1 | Authentication & Profile | **Rei Soemanto** | `AuthViewModel`, `ProfileViewModel` |
| 2 | Vehicles | **Rei Soemanto** | `VehicleViewModel` |
| 3 | Bengkel & Location | **Rei Soemanto** | `BengkelViewModel`; dashboard/port oleh **Jason (DkXenos)** |
| 4 | Order Creation & Bidding | **Bryan** (`OrderViewModel`) + **Eugene** (`CustomerBiddingViewModel`, `BengkelBiddingViewModel`) | inti marketplace |
| 5 | Mechanics & Roster | **Jason (DkXenos)** | pembuat dashboard mekanik awal (kini `MechanicDashboardViewModel`); `AssignMechanicViewModel` oleh **Eugene** |
| 6 | Chat | **Eugene** | `ChatViewModel`, `ChatWatchViewModel` |
| 7 | Live Tracking | **Eugene** | `OrderTrackingViewModel`, `BengkelRouteViewModel` (refinement oleh Bryan) |
| 8 | Completion & Rating | **Bryan** | `OrderCompletionViewModel`, `OrderRatingViewModel` (dibuat **Eugene**) |
| 9 | Payment / Wallet · Escrow | **Eugene** | `PaymentViewModel` |
| 10 | Order History | **Jason (DkXenos)** | `HistoryViewModel` dibuat **Bryan**; per-role history |
| 11 | Reports & Disputes | **Eugene** | `BehaviorReportViewModel` |

**Ringkasan per anggota**

- **Rei Soemanto** — Fondasi/Akun: §1 Auth & Profile, §2 Vehicles, §3 Bengkel & Location.
- **Bryan Fernando Dinata** — Order & Completion: §4 Order Creation & Bidding (sisi Order), §8 Completion & Rating; plus konsolidasi/port lintas-fitur.
- **Jason (DkXenos)** — Mechanics & History: §5 Mechanics & Roster, §10 Order History; plus **Admin dashboard** (`admin/`, deployable terpisah — di luar diagram iOS ini).
- **Amadeus Eugene Dirgantara** — Job Lifecycle & Uang: §4 (Bidding), §6 Chat, §7 Live Tracking, §9 Payment, §11 Reports (dasar §5 Assign & §8 Completion).

> Catatan: §5 grounded ke Jason (pembuat dashboard mekanik awal). §8 ke Bryan & §10 ke Jason adalah penugasan **presentasi** untuk menyeimbangkan beban — secara *first commit*, §8 Completion dibuat Eugene dan `HistoryViewModel` (§10) dibuat Bryan. Tabel mencerminkan **siapa presentasi apa**, bukan murni atribusi git.

---

## 1. Authentication & Profile

Login, sign-up, session, account deletion, and profile/avatar editing. `AuthViewModel` is created once in `ContentView` and owns `appMode` (which dashboard renders).

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
classDiagram
    direction LR

    class AuthService {
        +getCurrentSession() Session
        +currentUID() String
        +cachedSession() Session?
        +authStateChanges() AsyncStream
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phoneNumber)
    }
    class StorageService {
        +uploadAvatar(uid, data) String
        +uploadOrderPhoto(uid, data) String
        +deleteOrderPhotos(urls)
        +uploadChatImage(serviceRequestId, data) String
    }
    class ImageCompressor {
        +compressed(data, maxDimension, quality) Data$
    }
    class AuthServiceError {
        <<enumeration>>
        emailAlreadyRegistered
        +String? errorDescription
    }
    class UserRepository {
        +fetchUser(uid) User
        +updateProfile(uid, payload)
        +updateProfileImageUrl(uid, payload)
        +updateBankDetails(uid, payload)
        +deleteUser(uid)
    }
    class AuthViewModel {
        +SupabaseUser? userSession
        +User? currentUser
        +Bool isLoading
        +Bool isInitializing
        +String? errorMessage
        +String? successMessage
        +AppMode appMode
        -Task? authStateTask
        +init()
        +deinit()
        +loadInitialSession()
        +login(email, password)
        +signUp(email, password, name, phoneNumber)
        +fetchUser()
        +sendPasswordResetEmail()
        +deleteAccount(password)
        +signOut()
    }
    class ProfileViewModel {
        +Bool isLoading
        +String? errorMessage
        +String? successMessage
        +updateProfile(name, phoneNumber) Bool
        +uploadProfileImage(data) Bool
    }
    class User {
        +String id
        +String name
        +String role
        +Double balance
        +Double? heldBalance
        +Double? pendingBalance
        +Int? points
        +Int? pendingPoints
        +String? email
        +String? phoneNumber
        +String? profileImageUrl
        +String? bankName
        +String? bankAccountNumber
        +String? bankAccountName
        +Double availableBalance
        +Int availablePoints
    }
    class AppMode {
        <<enumeration>>
        customer
        bengkel
        mechanic
    }
    class SignUpRequest {
        +String email
        +String password
        +String name
        +String phoneNumber
    }
    class ProfileUpdatePayload {
        +String name
    }
    class ProfileImageUpdatePayload {
        +String profile_image_url
    }
    class BankDetailsUpdatePayload {
        +String bank_name
        +String bank_account_number
        +String bank_account_name
    }

    AuthViewModel "1" --> "1" AuthService : authenticates via
    AuthViewModel "1" --> "1" UserRepository : reads/updates
    AuthViewModel "1" --> "0..1" User : manages
    AuthViewModel "1" --> "1" AppMode : switches
    ProfileViewModel "1" --> "1" AuthService : reads session
    ProfileViewModel "1" --> "1" UserRepository : updates
    ProfileViewModel "1" --> "1" StorageService : uploads via
    ProfileViewModel ..> ImageCompressor : uses
    AuthService ..> SignUpRequest : sends
    AuthService ..> AuthServiceError : throws
    UserRepository ..> User : returns
    UserRepository ..> ProfileUpdatePayload : sends
    UserRepository ..> ProfileImageUpdatePayload : sends
    UserRepository ..> BankDetailsUpdatePayload : sends

```

---

## 2. Vehicles

Customer CRUD over their vehicles (used later when creating an order).

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
classDiagram
    direction LR

    class AuthService {
        +getCurrentSession() Session
        +currentUID() String
        +cachedSession() Session?
        +authStateChanges() AsyncStream
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phoneNumber)
    }
    class VehicleRepository {
        +fetchVehicles(customerId) Vehicle[]
        +insertVehicle(vehicle)
        +updateVehicle(vehicleId, payload)
        +deleteVehicle(vehicleId)
    }
    class VehicleViewModel {
        +Vehicle[] userVehicles
        +Bool isLoading
        +String? errorMessage
        +String? successMessage
        +fetchVehicles()
        +addVehicle(manufacturer, model, year, licensePlate, color) Bool
        +updateVehicle(vehicleId, manufacturer, model, year, licensePlate, color) Bool
        +deleteVehicle(vehicleId) Bool
    }
    class Vehicle {
        +String? id
        +String customerId
        +String manufacturer
        +String model
        +Int year
        +String licensePlate
        +String color
        +Date? createdAt
    }
    class VehicleUpdatePayload {
        +String manufacturer
        +String model
        +Int year
        +String license_plate
        +String color
    }

    VehicleViewModel "1" --> "1" AuthService : reads session
    VehicleViewModel "1" --> "1" VehicleRepository : reads/updates
    VehicleViewModel "1" --> "*" Vehicle : manages
    VehicleRepository ..> Vehicle : returns
    VehicleRepository ..> VehicleUpdatePayload : sends

```

---

## 3. Bengkel (Workshop) Management & Location Picking

Register/edit a workshop, manage its offered services, and the OSM + Photon map/search stack. `BengkelViewModel` realizes `LocationSearchable`.

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
classDiagram
    direction LR

    class AuthService {
        +getCurrentSession() Session
        +currentUID() String
        +cachedSession() Session?
        +authStateChanges() AsyncStream
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phoneNumber)
    }
    class LocationService {
        +searchOSM(query, coordinate) PhotonSearchFeature[]
        +fetchAddress(from) String?
    }
    class BengkelRepository {
        +fetchBengkel(providerUid) Bengkel
        +fetchById(id) Bengkel
        +insertBengkel(bengkel)
        +updateBengkel(bengkelId, payload)
        +updateServices(bengkelId, payload)
        +deleteBengkel(bengkelId)
    }
    class OrderRepository {
        +createOrder(payload) CreatedServiceRequest
        +fetchOrders(customerId) NearbyOrder[]
        +fetchBengkelOrders(bengkelId) NearbyOrder[]
        +fetchMechanicOrders(mechanicId) NearbyOrder[]
        +fetchOrder(id) NearbyOrder
        +fetchActiveOrder(customerId) NearbyOrder?
        +fetchTodaysEarnings(bengkelId) Double
        +updateOrderPrice(id, price)
        +cancelOrder(id)
        +deleteOrder(id)
        +acceptBid(bidId) NearbyOrder
        +markOrderCompleted(reqId, url) NearbyOrder
        +submitRating(reqId, rating)
        +openDispute(reqId, reason, url) NearbyOrder
    }
    class MechanicRepository {
        +fetchRoster() RosterMember[]
        +inviteMechanic(email)
        +removeMechanic(registrationId)
        +fetchAvailableMechanics(requestId) AvailableMechanic[]
        +fetchMyInvites() MechanicInvite[]
        +respondToInvite(registrationId, accept)
    }
    class Bengkel {
        +String? id
        +String providerUid
        +String name
        +String address
        +Double latitude
        +Double longitude
        +String status
        +BengkelService[] offeredServices
        +Double averageRating
        +Int totalReviews
        +Date? createdAt
    }
    class BengkelViewModel {
        +Bengkel? myBengkel
        +Bool isLoading
        +String? errorMessage
        +String? successMessage
        +Double todaysEarnings
        +Bool hasAcceptedMechanic
        +String locationAddress
        +Bool isEditingLocation
        +Bool isFetchingLocation
        +PhotonSearchFeature[] searchResults
        +MKCoordinateRegion region
        -CLLocationManager locationManager
        -Set~AnyCancellable~ cancellables
        -RealtimeChannelV2? realtimeChannel
        -RealtimeChannelV2? earningsChannel
        -Task[] realtimeReaderTasks
        +init()
        +deinit()
        +registerBengkel(name, address) Bool
        +updateBengkel(id, name, address) Bool
        +deleteBengkel(id, password, email) Bool
        +addService(id, type, active) Bool
        +updateService(id, serviceId, type, active) Bool
        +deleteService(id, serviceId) Bool
        +fetchMyBengkel(uid)
        +refreshBengkelQuietly(uid)
        +loadTodaysEarnings()
        +loadMechanicStatus()
        +startWatching(uid)
        +stopWatching()
        +useCurrentLocation()
        +selectSearchResult(result)
        +updateLocationFromMap(coordinate)
        +locationManagerDidChangeAuthorization(manager)
        +locationManager(manager, didUpdateLocations)
        +locationManager(manager, didFailWithError)
        -searchOSM(query)
        -fetchAddress(coordinate)
        -startRealtimeSubscription(uid)
        -startEarningsSubscription(bengkelId)
    }
    class LocationSearchable {
        <<interface>>
        +String locationAddress
        +Bool isEditingLocation
        +Bool isFetchingLocation
        +PhotonSearchFeature[] searchResults
        +MKCoordinateRegion region
        +useCurrentLocation()
        +selectSearchResult(result)
        +updateLocationFromMap(coordinate)
    }
    class BengkelService {
        +String id
        +ServiceType serviceType
        +Bool isActive
    }
    class ServiceType {
        <<enumeration>>
        banGembos
        banPecah
        akiKering
        mogokMesinMati
        gantiBanSerep
        rantaiMotorLepas
        mesinOverheat
        +Int minPrice
        +Bool requiresTireCount
        +String iconName
    }
    class PhotonSearchFeature {
        +UUID id
        +PhotonSearchProperties properties
        +PhotonSearchGeometry geometry
        +eq(lhs, rhs) Bool$
        +hash(into hasher)
    }
    class PhotonSearchProperties {
        +Int? osm_id
        +String? name
        +String? street
        +String? city
        +String? state
    }
    class PhotonSearchGeometry {
        +Double[] coordinates
    }
    class BengkelUpdatePayload {
        +String name
        +String address
        +Double latitude
        +Double longitude
    }
    class BengkelServicesUpdatePayload {
        +BengkelService[] offered_services
    }

    BengkelViewModel ..|> LocationSearchable
    BengkelViewModel "1" --> "1" BengkelRepository : reads/updates
    BengkelViewModel "1" --> "1" LocationService : geocodes via
    BengkelViewModel "1" --> "1" OrderRepository : reads
    BengkelViewModel "1" --> "1" MechanicRepository : reads
    BengkelViewModel "1" --> "1" AuthService : reads session
    BengkelViewModel "1" --> "0..1" Bengkel : manages
    BengkelViewModel "1" --> "*" PhotonSearchFeature : displays
    BengkelRepository ..> Bengkel : returns
    BengkelRepository ..> BengkelUpdatePayload : sends
    BengkelRepository ..> BengkelServicesUpdatePayload : sends
    LocationService ..> PhotonSearchFeature : returns
    PhotonSearchFeature "1" *-- "1" PhotonSearchProperties : embeds
    PhotonSearchFeature "1" *-- "1" PhotonSearchGeometry : embeds
    Bengkel "1" *-- "*" BengkelService : contains
    BengkelService "1" --> "1" ServiceType : references

```

---

## 4. Order Creation & Bidding

The core marketplace loop. The customer composes a request (`OrderViewModel`), broadcasts it and reviews incoming bids (`CustomerBiddingViewModel`); bengkels see nearby open orders and place bids (`BengkelBiddingViewModel`). The `bidding` edge function (`BiddingService`) geo-filters orders and writes bids server-side. Class members here are complete: `+` = public (`@Published` state / public methods), `-` = private implementation state and helpers.

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
classDiagram
    direction LR

    class AuthService {
        +getCurrentSession() Session
        +currentUID() String
        +cachedSession() Session?
        +authStateChanges() AsyncStream
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phoneNumber)
    }
    class StorageService {
        +uploadAvatar(uid, data) String
        +uploadOrderPhoto(uid, data) String
        +deleteOrderPhotos(urls)
        +uploadChatImage(reqId, data) String
    }
    class LocationService {
        +searchOSM(query, coordinate) PhotonSearchFeature[]
        +fetchAddress(from) String?
    }
    class NotificationService {
        +requestAuthorization()
        +notifyNewOrder(title, body)
    }
    class BiddingService {
        +fetchOrdersForMechanic(lat, lon, radius) NearbyOrder[]
        +placeBid(reqId, bengkelId, price, notes) Bid
    }
    class UserRepository {
        +fetchUser(uid) User
        +updateProfile(uid, payload)
        +updateProfileImageUrl(uid, payload)
        +updateBankDetails(uid, payload)
        +deleteUser(uid)
    }
    class VehicleRepository {
        +fetchVehicles(customerId) Vehicle[]
        +insertVehicle(vehicle)
        +updateVehicle(vehicleId, payload)
        +deleteVehicle(vehicleId)
    }
    class BengkelRepository {
        +fetchBengkel(providerUid) Bengkel
        +fetchById(id) Bengkel
        +insertBengkel(bengkel)
        +updateBengkel(bengkelId, payload)
        +updateServices(bengkelId, payload)
        +deleteBengkel(bengkelId)
    }
    class OrderRepository {
        +createOrder(payload) CreatedServiceRequest
        +fetchOrders(customerId) NearbyOrder[]
        +fetchBengkelOrders(bengkelId) NearbyOrder[]
        +fetchMechanicOrders(mechanicId) NearbyOrder[]
        +fetchOrder(id) NearbyOrder
        +fetchActiveOrder(customerId) NearbyOrder?
        +fetchTodaysEarnings(bengkelId) Double
        +updateOrderPrice(id, price)
        +cancelOrder(id)
        +deleteOrder(id)
        +acceptBid(bidId) NearbyOrder
        +markOrderCompleted(reqId, url) NearbyOrder
        +submitRating(reqId, rating)
        +openDispute(reqId, reason, url) NearbyOrder
    }
    class BidRepository {
        +fetchAcceptedBid(serviceRequestId) Bid?
        +fetchBids(serviceRequestId) Bid[]
        +fetchBidsForBengkel(bengkelId) Bid[]
        +updateStatus(bidId, status)
    }
    class MechanicRepository {
        +fetchRoster() RosterMember[]
        +inviteMechanic(email)
        +removeMechanic(registrationId)
        +fetchAvailableMechanics(requestId) AvailableMechanic[]
        +fetchMyInvites() MechanicInvite[]
        +respondToInvite(registrationId, accept)
    }
    class NearbyOrder {
        +String id
        +String customerId
        +String? customerName
        +String? serviceType
        +String? description
        +Bool? isEmergency
        +Double latitude
        +Double longitude
        +Int? price
        +String status
        +Int? tireCount
        +String[]? photoUrls
        +String? vehicleId
        +String? vehicleInfo
        +String? bengkelId
        +String? mechanicId
        +Int? rating
        +Bool? customerCompleted
        +Bool? providerCompleted
        +String? completionPhotoUrl
        +Bool? usePoints
        +Int? pointsUsed
        +Int? pointsEarned
        +String? createdAt
        +String? assignedAt
        +Double? distanceM
    }
    class Bengkel {
        +String? id
        +String providerUid
        +String name
        +String address
        +Double latitude
        +Double longitude
        +String status
        +BengkelService[] offeredServices
        +Double averageRating
        +Int totalReviews
        +Date? createdAt
    }
    class Vehicle {
        +String? id
        +String customerId
        +String manufacturer
        +String model
        +Int year
        +String licensePlate
        +String color
        +Date? createdAt
    }
    class LoadingPhase {
        <<enumeration>>
        idle
        loading(message)
        failed(title, message)
    }
    class LocationSearchable {
        <<interface>>
        +String locationAddress
        +Bool isEditingLocation
        +Bool isFetchingLocation
        +PhotonSearchFeature[] searchResults
        +MKCoordinateRegion region
        +useCurrentLocation()
        +selectSearchResult(result)
        +updateLocationFromMap(coordinate)
    }
    class OrderViewModel {
        +String locationAddress
        +String? selectedService
        +Int estimatedPrice
        +Bool isFetchingLocation
        +Bool isEditingLocation
        +PhotonSearchFeature[] searchResults
        +String? errorMessage
        +Int tireCount
        +Data?[] photosData
        +ServiceType? pendingServiceType
        +Int pendingTireCount
        +String[] pendingPhotoUrls
        +Bool navigateToBidding
        +LoadingPhase loadingPhase
        +Vehicle[] vehicles
        +String? selectedVehicleId
        +String? pendingVehicleId
        +String? pendingVehicleInfo
        +Bool usePoints
        +Int availablePoints
        +Bool showPointsPrompt
        +Bool hasResolvedLocation
        +MKCoordinateRegion region
        +Int maxRedeemablePreview
        +Bool requiresTireCount
        +String[] services
        +CLLocationCoordinate2D defaultCenter$
        -CLLocationManager locationManager
        -Set~AnyCancellable~ cancellables
        +init()
        +selectSearchResult(result)
        +useCurrentLocation()
        +locationManagerDidChangeAuthorization(manager)
        +locationManager(manager, didUpdateLocations)
        +locationManager(manager, didFailWithError)
        +updateLocationFromMap(coordinate)
        +loadVehicles()
        +loadUserPoints()
        +prepareForNewOrder()
        +selectService(service)
        +setTireCount(count)
        +createOrder()
        +retryOrder()
        +beginOrder(usePoints)
        +cancelLoading()
        -searchOSM(query)
        -fallBackToDefaultLocation()
        -fetchAddress(coordinate)
        -calculateEstimate()
        -validateOrder() Bool
    }
    class CustomerBiddingViewModel {
        +Bid[] bids
        +Bid? acceptedBid
        +Bool isLoading
        +Bool isStartingSearch
        +String? errorMessage
        +LoadingPhase loadingPhase
        +Int minPrice
        +Int customerBidPrice
        +Bool isSearching
        +String? serviceRequestId
        +Double balance
        +Bool showRetryPrompt
        +Bool shouldDismiss
        +Int searchSecondsRemaining
        +Int searchTotalSeconds
        +Double searchProgress
        +ServiceType serviceType
        +Double latitude
        +Double longitude
        +Int tireCount
        +String[] photoUrls
        +String? vehicleId
        +String? vehicleInfo
        +Bool usePoints
        -UInt64 searchTimeoutSeconds
        -UInt64 decisionTimeoutSeconds
        -TimeInterval bidDecisionWindowSeconds
        -Task? searchCountdownTask
        -Task? decisionCountdownTask
        -Task? bidExpiryTask
        -RealtimeChannelV2? realtimeChannel
        -Task[] realtimeReaderTasks
        -Set~String~ knownBidIds
        -Bool didLoadBidsOnce
        +init(serviceType, lat, lon, …)
        +init(resuming)
        +deinit()
        +resume()
        +startSearch(price)
        +retrySamePrice()
        +raisePrice()
        +cancel()
        +cancelAndDelete()
        +startRealtimeSubscription()
        +stopRealtimeSubscription()
        +loadReceivedBids()
        +refresh()
        +acceptBid(bid)
        +rejectBid(bid)
        +expireBid(bid)
        +parseISODate(s) Date?$
        -startSearchCountdown()
        -expireSearch()
        -stopSearchingState()
        -scheduleBidExpiry()
        -expireOverdueBids()
    }
    class BengkelBiddingViewModel {
        +NearbyOrder[] orders
        +Bengkel? myBengkel
        +Bid[] myPendingBids
        +Bool isLoading
        +String? errorMessage
        +String? successMessage
        +NearbyOrder? newOrderAlert
        +String? lostBidAlert
        +String? expiredBidAlert
        +NearbyOrder? activeBengkelOrder
        +String? rejectedBidAlert
        +String? orderUnavailableAlert
        +Bid[] myRejectedBids
        +Bool hasMechanics
        -RealtimeChannelV2? realtimeChannel
        -Task[] realtimeReaderTasks
        -Set~String~ knownOrderIds
        -Dictionary~String,String~ bidStatusById
        -Bool didInitialLoad
        -Bool hasStarted
        -String? providerUid
        +deinit()
        +start()
        +reset()
        +refreshOnForeground()
        +startRealtimeSubscription()
        +stopRealtimeSubscription()
        +loadOrders()
        +placeBid(order, price, notes)
        +handleExpiredOrder(order)
        +expireBid(bid)
        +rejectBid(bid)
    }
    class Bid {
        +String id
        +String serviceRequestId
        +String providerUid
        +String bengkelId
        +Int price
        +String? notes
        +String status
        +String? createdAt
        +Bengkel? bengkel
    }
    class ServiceRequestPayload {
        +String customer_id
        +ServiceType service_type
        +String description
        +Double latitude
        +Double longitude
        +Int price
        +Bool is_emergency
        +String status
        +Int tire_count
        +String[]? photo_urls
        +String? vehicle_id
        +String? vehicle_info
        +Bool use_points
    }
    class PlaceBidRequest {
        +String action
        +String serviceRequestId
        +String bengkelId
        +Int price
        +String? notes
    }
    class AcceptBidParams {
        +String p_bid_id
    }
    class CreatedServiceRequest {
        +String id
    }
    class CancelOrderParams {
        +String p_request_id
    }
    class StartSearchPayload {
        +Int price
    }
    class TodaysEarningRow {
        +Int? price
    }
    class BidStatusUpdate {
        +String status
    }
    class OrdersRequest {
        +String action
        +Double latitude
        +Double longitude
        +Double radiusMeters
    }
    class OrdersResponse {
        +NearbyOrder[] orders
    }
    class PlaceBidResponse {
        +Bid bid
    }

    OrderViewModel ..|> LocationSearchable
    OrderViewModel "1" --> "1" LocationService : geocodes via
    OrderViewModel "1" --> "1" StorageService : uploads via
    OrderViewModel "1" --> "1" UserRepository : reads
    OrderViewModel "1" --> "1" VehicleRepository : reads
    OrderViewModel "1" --> "1" AuthService : reads session
    CustomerBiddingViewModel "1" --> "1" OrderRepository : reads/updates
    CustomerBiddingViewModel "1" --> "1" BidRepository : reads/updates
    CustomerBiddingViewModel "1" --> "1" UserRepository : reads
    CustomerBiddingViewModel "1" --> "1" StorageService : deletes photos via
    CustomerBiddingViewModel "1" --> "1" NotificationService : notifies via
    CustomerBiddingViewModel "1" --> "1" AuthService : reads session
    CustomerBiddingViewModel "1" --> "*" Bid : manages
    CustomerBiddingViewModel "1" --> "0..1" Bid : tracks
    BengkelBiddingViewModel "1" --> "1" OrderRepository : reads
    BengkelBiddingViewModel "1" --> "1" BidRepository : reads/updates
    BengkelBiddingViewModel "1" --> "1" BiddingService : places bids via
    BengkelBiddingViewModel "1" --> "1" BengkelRepository : reads
    BengkelBiddingViewModel "1" --> "1" MechanicRepository : reads
    BengkelBiddingViewModel "1" --> "1" NotificationService : notifies via
    BengkelBiddingViewModel "1" --> "1" AuthService : reads session
    BengkelBiddingViewModel "1" --> "*" NearbyOrder : displays
    BengkelBiddingViewModel "1" --> "0..1" NearbyOrder : tracks
    BengkelBiddingViewModel "1" --> "*" Bid : tracks
    BengkelBiddingViewModel "1" --> "0..1" Bengkel : references
    OrderViewModel "1" --> "*" Vehicle : displays
    OrderViewModel "1" --> "1" LoadingPhase : tracks
    CustomerBiddingViewModel "1" --> "1" LoadingPhase : tracks
    OrderRepository ..> ServiceRequestPayload : sends
    OrderRepository ..> NearbyOrder : returns
    OrderRepository ..> AcceptBidParams : sends
    OrderRepository ..> CreatedServiceRequest : returns
    OrderRepository ..> CancelOrderParams : sends
    OrderRepository ..> StartSearchPayload : sends
    OrderRepository ..> TodaysEarningRow : returns
    BidRepository ..> Bid : returns
    BidRepository ..> BidStatusUpdate : sends
    BiddingService ..> PlaceBidRequest : sends
    BiddingService ..> PlaceBidResponse : returns
    BiddingService ..> OrdersRequest : sends
    BiddingService ..> OrdersResponse : returns
    BiddingService ..> NearbyOrder : returns
    BiddingService ..> Bid : returns
    Bid "1" --> "0..1" Bengkel : references

```

> Catatan: `OrderRepository` juga mengirim `MarkCompletedParams`, `RateOrderParams`, dan `OpenDisputeParams` (untuk `markOrderCompleted` / `submitRating` / `openDispute`) — ketiga DTO itu digambar di §8 dan §11 agar diagram ini tidak makin besar. Pembuatan order (`createOrder`) terjadi di `CustomerBiddingViewModel.startSearch()`, bukan di `OrderViewModel` (yang hanya memvalidasi, meng-upload foto, lalu navigasi ke bidding).

---

## 5. Mechanics & Roster

Bengkel-side roster management (invite/remove mechanics, dispatch a mechanic to an accepted job) and mechanic-side invites + assigned jobs. All roster operations go through RPCs.

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
classDiagram
    direction LR

    class AuthService {
        +getCurrentSession() Session
        +currentUID() String
        +cachedSession() Session?
        +authStateChanges() AsyncStream
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phoneNumber)
    }
    class NotificationService {
        +requestAuthorization()
        +notifyNewOrder(title, body)
    }
    class MechanicRepository {
        +fetchRoster() RosterMember[]
        +inviteMechanic(email)
        +removeMechanic(registrationId)
        +fetchAvailableMechanics(requestId) AvailableMechanic[]
        +fetchMyInvites() MechanicInvite[]
        +respondToInvite(registrationId, accept)
    }
    class MechanicAssignmentRepository {
        +assignMechanic(requestId, mechanicId) NearbyOrder
        +fetchAssignedJobs(mechanicId) NearbyOrder[]
    }
    class NearbyOrder {
        +String id
        +String customerId
        +String? customerName
        +String? serviceType
        +String? description
        +Bool? isEmergency
        +Double latitude
        +Double longitude
        +Int? price
        +String status
        +Int? tireCount
        +String[]? photoUrls
        +String? vehicleId
        +String? vehicleInfo
        +String? bengkelId
        +String? mechanicId
        +Int? rating
        +Bool? customerCompleted
        +Bool? providerCompleted
        +String? completionPhotoUrl
        +Bool? usePoints
        +Int? pointsUsed
        +Int? pointsEarned
        +String? createdAt
        +String? assignedAt
        +Double? distanceM
    }
    class BengkelRosterViewModel {
        +RosterMember[] roster
        +String inviteEmail
        +Bool isLoading
        +Bool isInviting
        +String? errorMessage
        +String? successMessage
        +RosterMember[] pendingMembers
        +RosterMember[] acceptedMembers
        +fetchRoster()
        +invite() Bool
        +remove(member)
    }
    class MechanicInviteViewModel {
        +MechanicInvite[] invites
        +Bool isLoading
        +String? errorMessage
        +MechanicInvite[] pendingInvites
        +Bool hasPendingInvites
        +fetchInvites()
        +respond(invite, accept) Bool
    }
    class AssignMechanicViewModel {
        +AvailableMechanic[] availableMechanics
        +Bool isLoading
        +Bool isAssigning
        +String? errorMessage
        +fetchAvailableMechanics(reqId)
        +assign(reqId, mechanicId) Bool
    }
    class MechanicDashboardViewModel {
        +NearbyOrder[] jobs
        +NearbyOrder? newAssignmentAlert
        +Bool isLoading
        +String? errorMessage
        -RealtimeChannelV2? channel
        -RealtimeChannelV2? broadcastChannel
        -Task[] realtimeReaderTasks
        -Dictionary~String,String~ knownAssignments
        -Bool didInitialLoad
        -Bool hasStarted
        -String? myUid
        +deinit()
        +start()
        +reset()
        +refreshOnForeground()
        +stop()
        -loadJobs()
        -subscribe()
        -startReconcilePoll()
        -subscribeMechanicBroadcast(uid)
        -handleAssigned(message)
        -handleReassignedAway(message)
    }
    class MechanicJobsViewModel {
        +NearbyOrder[] jobs
        +Bool isLoading
        +String? errorMessage
        +fetchJobs()
    }
    class RosterMember {
        +String id
        +String registrationId
        +String mechanicId
        +String mechanicName
        +String? mechanicEmail
        +String status
        +String? createdAt
        +Bool isPending
        +Bool isAccepted
    }
    class MechanicInvite {
        +String id
        +String registrationId
        +String bengkelId
        +String bengkelName
        +String status
        +String? createdAt
        +Bool isPending
    }
    class AvailableMechanic {
        +String id
        +String mechanicId
        +String mechanicName
        +Bool busy
        +Bool isCurrent
    }
    class AssignMechanicParams {
        +String p_request_id
        +String p_mechanic_id
    }
    class RespondInviteParams {
        +String p_registration_id
        +Bool p_accept
    }
    class InviteMechanicParams {
        +String p_email
    }
    class RemoveMechanicParams {
        +String p_registration_id
    }
    class AvailableMechanicsParams {
        +String p_request_id
    }

    BengkelRosterViewModel "1" --> "1" MechanicRepository : reads/updates
    BengkelRosterViewModel "1" --> "*" RosterMember : manages
    MechanicInviteViewModel "1" --> "1" MechanicRepository : reads/updates
    MechanicInviteViewModel "1" --> "*" MechanicInvite : manages
    AssignMechanicViewModel "1" --> "1" MechanicRepository : reads
    AssignMechanicViewModel "1" --> "1" MechanicAssignmentRepository : assigns via
    AssignMechanicViewModel "1" --> "*" AvailableMechanic : displays
    MechanicDashboardViewModel "1" --> "1" MechanicAssignmentRepository : reads
    MechanicDashboardViewModel "1" --> "1" AuthService : reads session
    MechanicDashboardViewModel "1" --> "1" NotificationService : notifies via
    MechanicDashboardViewModel "1" --> "*" NearbyOrder : displays
    MechanicDashboardViewModel "1" --> "0..1" NearbyOrder : tracks
    MechanicJobsViewModel "1" --> "1" MechanicAssignmentRepository : reads
    MechanicJobsViewModel "1" --> "1" AuthService : reads session
    MechanicJobsViewModel "1" --> "*" NearbyOrder : displays
    MechanicRepository ..> RosterMember : returns
    MechanicRepository ..> MechanicInvite : returns
    MechanicRepository ..> AvailableMechanic : returns
    MechanicRepository ..> RespondInviteParams : sends
    MechanicRepository ..> InviteMechanicParams : sends
    MechanicRepository ..> RemoveMechanicParams : sends
    MechanicRepository ..> AvailableMechanicsParams : sends
    MechanicAssignmentRepository ..> AssignMechanicParams : sends
    MechanicAssignmentRepository ..> NearbyOrder : returns

```

---

## 6. Chat

Realtime per-order chat with text + image messages, an unread watcher, and a lock state (chat closes when the order ends). `ChatReadCursor`/`ChatPresence` are local helpers.

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
classDiagram
    direction LR

    class AuthService {
        +getCurrentSession() Session
        +currentUID() String
        +cachedSession() Session?
        +authStateChanges() AsyncStream
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phoneNumber)
    }
    class StorageService {
        +uploadAvatar(uid, data) String
        +uploadOrderPhoto(uid, data) String
        +deleteOrderPhotos(urls)
        +uploadChatImage(reqId, data) String
    }
    class NotificationService {
        +requestAuthorization()
        +notifyNewOrder(title, body)
    }
    class OrderRepository {
        +createOrder(payload) CreatedServiceRequest
        +fetchOrders(customerId) NearbyOrder[]
        +fetchBengkelOrders(bengkelId) NearbyOrder[]
        +fetchMechanicOrders(mechanicId) NearbyOrder[]
        +fetchOrder(id) NearbyOrder
        +fetchActiveOrder(customerId) NearbyOrder?
        +fetchTodaysEarnings(bengkelId) Double
        +updateOrderPrice(id, price)
        +cancelOrder(id)
        +deleteOrder(id)
        +acceptBid(bidId) NearbyOrder
        +markOrderCompleted(reqId, url) NearbyOrder
        +submitRating(reqId, rating)
        +openDispute(reqId, reason, url) NearbyOrder
    }
    class ChatRepository {
        +fetchMessages(serviceRequestId) ChatMessage[]
        +sendMessage(payload)
    }
    class ChatViewModel {
        +String serviceRequestId
        +String currentUserId
        +ChatMessage[] messages
        +String draft
        +Bool isSending
        +Bool isLocked
        +String? errorMessage
        -RealtimeChannelV2? realtimeChannel
        -Task[] realtimeReaderTasks
        +init(serviceRequestId)
        +deinit()
        +start()
        +loadMessages()
        +loadLockState()
        +startRealtimeSubscription()
        +stopRealtimeSubscription()
        +sendText()
        +sendImage(data)
        -send(content, imageUrl) Bool
    }
    class ChatWatchViewModel {
        +Int unreadCount
        -String serviceRequestId
        -String counterpartName
        -ChatReadCursor cursor
        -String currentUserId
        -RealtimeChannelV2? channel
        -Task[] realtimeReaderTasks
        -Set~String~ notifiedIds
        -Bool didLoadOnce
        +init(serviceRequestId, counterpartName)
        +deinit()
        +start()
        +stop()
        +markAllRead()
        -subscribe()
        -reload()
        -notificationBody(message) String
    }
    class ImageCompressor {
        +compressed(data, maxDimension, quality) Data$
    }
    class ChatReadCursor {
        +String serviceRequestId
        +Date lastReadAt
        -String key
        +markRead(at)
        +unreadCount(incoming) Int
        +date(of message) Date$
    }
    class ChatPresence {
        +ChatPresence shared$
        +String? activeServiceRequestId
        -init()
    }
    class ChatMessage {
        +String id
        +String serviceRequestId
        +String senderId
        +String? content
        +String? imageUrl
        +String? createdAt
    }
    class ChatMessagePayload {
        +String service_request_id
        +String sender_id
        +String? content
        +String? image_url
    }

    ChatViewModel "1" --> "1" ChatRepository : reads/updates
    ChatViewModel "1" --> "1" OrderRepository : reads
    ChatViewModel "1" --> "1" StorageService : uploads via
    ChatViewModel ..> ImageCompressor : uses
    ChatViewModel "1" --> "1" AuthService : reads session
    ChatViewModel "1" --> "*" ChatMessage : manages
    ChatWatchViewModel "1" --> "1" ChatRepository : listens
    ChatWatchViewModel "1" --> "1" NotificationService : notifies via
    ChatWatchViewModel "1" --> "1" AuthService : reads session
    ChatWatchViewModel "1" *-- "1" ChatReadCursor : owns
    ChatWatchViewModel ..> ChatPresence : reads
    ChatRepository ..> ChatMessage : returns
    ChatRepository ..> ChatMessagePayload : sends

```

---

## 7. Live Location Tracking

The mover (provider/mechanic) publishes GPS to `order_locations`; the customer publishes to `customer_locations`; the other side subscribes. `BengkelRouteViewModel` drives the provider/mechanic route map; `OrderTrackingViewModel` the customer tracking map. These VMs own a `CLLocationManager`. `RouteLocationStore` is a small observable holder for the three live coordinates the route map renders (me / customer / handler), owned by `BengkelRouteViewModel`.

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
classDiagram
    direction LR

    class AuthService {
        +getCurrentSession() Session
        +currentUID() String
        +cachedSession() Session?
        +authStateChanges() AsyncStream
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phoneNumber)
    }
    class StorageService {
        +uploadAvatar(uid, data) String
        +uploadOrderPhoto(uid, data) String
        +deleteOrderPhotos(urls)
        +uploadChatImage(reqId, data) String
    }
    class NotificationService {
        +requestAuthorization()
        +notifyNewOrder(title, body)
    }
    class BengkelRepository {
        +fetchBengkel(providerUid) Bengkel
        +fetchById(id) Bengkel
        +insertBengkel(bengkel)
        +updateBengkel(bengkelId, payload)
        +updateServices(bengkelId, payload)
        +deleteBengkel(bengkelId)
    }
    class OrderRepository {
        +createOrder(payload) CreatedServiceRequest
        +fetchOrders(customerId) NearbyOrder[]
        +fetchBengkelOrders(bengkelId) NearbyOrder[]
        +fetchMechanicOrders(mechanicId) NearbyOrder[]
        +fetchOrder(id) NearbyOrder
        +fetchActiveOrder(customerId) NearbyOrder?
        +fetchTodaysEarnings(bengkelId) Double
        +updateOrderPrice(id, price)
        +cancelOrder(id)
        +deleteOrder(id)
        +acceptBid(bidId) NearbyOrder
        +markOrderCompleted(reqId, url) NearbyOrder
        +submitRating(reqId, rating)
        +openDispute(reqId, reason, url) NearbyOrder
    }
    class OrderLocationRepository {
        +upsertLocation(payload)
        +fetchLocation(reqId) OrderLocation?
        +upsertCustomerLocation(payload)
        +fetchCustomerLocation(reqId) CustomerLocation?
    }
    class OrderTrackingViewModel {
        +CLLocationCoordinate2D? providerCoordinate
        +String? lastUpdated
        +NearbyOrder? order
        +Bool isLive
        +String? errorMessage
        +String status
        +Bool alreadyRated
        -Bool iInitiatedCancel
        -RealtimeChannelV2? channel
        -String? serviceRequestId
        -Task[] realtimeReaderTasks
        +deinit()
        +start(reqId)
        +stop()
        +openDispute(reason) Bool
        +notifyBengkelNear()
        -notifyOnCancellation(previous, updated)
        -notifyOnAssignment(previous, updated)
        -apply(location)
    }
    class LocationPublishViewModel {
        +Bool isPublishing
        +String? errorMessage
        -CLLocationManager locationManager
        -String? serviceRequestId
        -CLLocationCoordinate2D? customerCoordinate
        -Date? lastPublishedAt
        -RealtimeChannelV2? statusChannel
        -Task? statusReaderTask
        +init()
        +deinit()
        +start(reqId, coordinate)
        +stop()
        +locationManagerDidChangeAuthorization(manager)
        +locationManager(manager, didUpdateLocations)
        +locationManager(manager, didFailWithError)
        -observeOrderStatus(requestId)
        -interval(forDistance) TimeInterval
        -publish(coordinate, requestId)
    }
    class CustomerLocationPublishViewModel {
        +Bool isPublishing
        +String? errorMessage
        +CLLocationCoordinate2D? currentCoordinate
        -CLLocationManager locationManager
        -String? serviceRequestId
        -Date? lastPublishedAt
        -TimeInterval minInterval
        +init()
        +start(reqId)
        +stop()
        +locationManagerDidChangeAuthorization(manager)
        +locationManager(manager, didUpdateLocations)
        +locationManager(manager, didFailWithError)
        -publish(coordinate, requestId)
    }
    class BengkelRouteViewModel {
        +NearbyOrder? order
        +String? myUid
        +Bool reassignedAway
        +RouteLocationStore locationStore
        +Bool isPaused
        +CLLocationCoordinate2D? bengkelCoordinate
        +CLLocationCoordinate2D? customerLiveCoordinate
        +CLLocationCoordinate2D? assigneeCoordinate
        +String status
        +Bool selfAssigned
        +Bool amAssignee
        +Bool viewerIsProvider
        +Bool viewerIsAssignee
        +String handlerLabel
        -Bool wasAssignee
        -CLLocationManager locationManager
        -Bool iInitiatedCancel
        -String? serviceRequestId
        -CLLocationCoordinate2D? customerCoordinate
        -String? providerUid
        -CLLocationCoordinate2D? shopCoordinate
        -Date? lastPublishedAt
        -RealtimeChannelV2? channel
        -Task[] realtimeReaderTasks
        -NSObjectProtocol? reassignObserver
        -String? mechanicId
        -Bool amProvider
        -Bool monitoringMechanic
        +init()
        +deinit()
        +start(order)
        +refreshOrder()
        +refreshAfterAssignment()
        +reportIssue(reason, photo) Bool
        +stop()
        +locationManagerDidChangeAuthorization(manager)
        +locationManager(manager, didUpdateLocations)
        +locationManager(manager, didFailWithError)
        -resolveBengkelIfNeeded()
        -reconfigureForRole()
        -refreshAssigneeFromOrderLocations()
        -notifyOnCancellation(previous, updated)
        -stopChannel()
        -interval(forDistance) TimeInterval
        -publishCurrentGPSIfPossible()
        -publish(coordinate, requestId)
    }
    class RouteLocationStore {
        +CLLocationCoordinate2D? me
        +CLLocationCoordinate2D? customer
        +CLLocationCoordinate2D? handler
    }
    class OrderLocation {
        +String id
        +String serviceRequestId
        +String? providerUid
        +Double latitude
        +Double longitude
        +String? updatedAt
    }
    class CustomerLocation {
        +String id
        +String serviceRequestId
        +String? customerId
        +Double latitude
        +Double longitude
        +String? updatedAt
    }
    class OrderLocationPayload {
        +String service_request_id
        +String provider_uid
        +Double latitude
        +Double longitude
    }
    class CustomerLocationPayload {
        +String service_request_id
        +String customer_id
        +Double latitude
        +Double longitude
    }

    OrderTrackingViewModel "1" --> "1" OrderLocationRepository : listens
    OrderTrackingViewModel "1" --> "1" OrderRepository : reads
    OrderTrackingViewModel "1" --> "1" NotificationService : notifies via
    LocationPublishViewModel "1" --> "1" OrderLocationRepository : publishes via
    LocationPublishViewModel "1" --> "1" OrderRepository : reads
    LocationPublishViewModel "1" --> "1" AuthService : reads session
    CustomerLocationPublishViewModel "1" --> "1" OrderLocationRepository : publishes via
    CustomerLocationPublishViewModel "1" --> "1" AuthService : reads session
    BengkelRouteViewModel "1" --> "1" OrderRepository : reads/updates
    BengkelRouteViewModel "1" --> "1" BengkelRepository : reads
    BengkelRouteViewModel "1" --> "1" OrderLocationRepository : publishes via
    BengkelRouteViewModel "1" --> "1" StorageService : uploads via
    BengkelRouteViewModel "1" --> "1" AuthService : reads session
    BengkelRouteViewModel "1" --> "1" NotificationService : notifies via
    BengkelRouteViewModel "1" *-- "1" RouteLocationStore : owns
    OrderLocationRepository ..> OrderLocation : returns
    OrderLocationRepository ..> CustomerLocation : returns
    OrderLocationRepository ..> OrderLocationPayload : sends
    OrderLocationRepository ..> CustomerLocationPayload : sends

```

---

## 8. Order Completion & Rating

Dual-confirm completion with a mandatory provider proof photo (`mark_order_completed` RPC), then a write-once customer rating (`rate_order` RPC) that recomputes the bengkel's average. `OrderCompletionViewModel` watches the order over a realtime channel (`order-completion-<reqId>`) and fires a local notification when the counterpart marks their side done. Class members here are complete: `+` = public (`@Published`/computed state and public methods), `-` = private implementation state and helpers.

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
classDiagram
    direction LR

    class AuthService {
        +getCurrentSession() Session
        +currentUID() String
        +cachedSession() Session?
        +authStateChanges() AsyncStream
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phoneNumber)
    }
    class StorageService {
        +uploadAvatar(uid, data) String
        +uploadOrderPhoto(uid, data) String
        +deleteOrderPhotos(urls)
        +uploadChatImage(reqId, data) String
    }
    class NotificationService {
        +requestAuthorization()
        +notifyNewOrder(title, body)
    }
    class OrderRepository {
        +createOrder(payload) CreatedServiceRequest
        +fetchOrders(customerId) NearbyOrder[]
        +fetchBengkelOrders(bengkelId) NearbyOrder[]
        +fetchMechanicOrders(mechanicId) NearbyOrder[]
        +fetchOrder(id) NearbyOrder
        +fetchActiveOrder(customerId) NearbyOrder?
        +fetchTodaysEarnings(bengkelId) Double
        +updateOrderPrice(id, price)
        +cancelOrder(id)
        +deleteOrder(id)
        +acceptBid(bidId) NearbyOrder
        +markOrderCompleted(reqId, url) NearbyOrder
        +submitRating(reqId, rating)
        +openDispute(reqId, reason, url) NearbyOrder
    }
    class NearbyOrder {
        +String id
        +String customerId
        +String? customerName
        +String? serviceType
        +String? description
        +Bool? isEmergency
        +Double latitude
        +Double longitude
        +Int? price
        +String status
        +Int? tireCount
        +String[]? photoUrls
        +String? vehicleId
        +String? vehicleInfo
        +String? bengkelId
        +String? mechanicId
        +Int? rating
        +Bool? customerCompleted
        +Bool? providerCompleted
        +String? completionPhotoUrl
        +Bool? usePoints
        +Int? pointsUsed
        +Int? pointsEarned
        +String? createdAt
        +String? assignedAt
        +Double? distanceM
    }
    class OrderCompletionViewModel {
        +String requestId
        +Bool isCustomer
        +NearbyOrder? order
        +Bool isLoading
        +String? errorMessage
        +String status
        +Bool isFinished
        +Bool mySideCompleted
        -RealtimeChannelV2? realtimeChannel
        -Task[] realtimeReaderTasks
        -Bool hasLoadedOnce
        +init(requestId, isCustomer)
        +deinit()
        +start()
        +refresh()
        +startRealtimeSubscription()
        +stopRealtimeSubscription()
        +markCompleted(photoData)
        -notifyOnCounterpartCompletion(previous, updated)
    }
    class OrderRatingViewModel {
        +Bool isSubmitting
        +String? errorMessage
        +submit(reqId, rating) Bool
    }
    class MarkCompletedParams {
        +String p_request_id
        +String? p_completion_photo_url
    }
    class RateOrderParams {
        +String p_request_id
        +Int p_rating
    }

    OrderCompletionViewModel "1" --> "1" OrderRepository : reads/updates
    OrderCompletionViewModel "1" --> "1" StorageService : uploads via
    OrderCompletionViewModel "1" --> "1" AuthService : reads session
    OrderCompletionViewModel "1" --> "1" NotificationService : notifies via
    OrderCompletionViewModel "1" --> "0..1" NearbyOrder : tracks
    OrderRatingViewModel "1" --> "1" OrderRepository : updates
    OrderRepository ..> MarkCompletedParams : sends
    OrderRepository ..> RateOrderParams : sends
    OrderRepository ..> NearbyOrder : returns

```

---

## 9. Payment / Wallet (Top-up & Withdrawal)

Wallet balance + points, Midtrans Snap top-up (via the `payment` edge function → `PaymentService`), bank-detail management, and withdrawals (`request_withdrawal` RPC, backed by *available* balance). Settlement happens server-side via the `midtrans-webhook` — never on the client.

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
classDiagram
    direction LR

    class AuthService {
        +getCurrentSession() Session
        +currentUID() String
        +cachedSession() Session?
        +authStateChanges() AsyncStream
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phoneNumber)
    }
    class PaymentService {
        +createTopup(amount) CreateTopupResponse
    }
    class UserRepository {
        +fetchUser(uid) User
        +updateProfile(uid, payload)
        +updateProfileImageUrl(uid, payload)
        +updateBankDetails(uid, payload)
        +deleteUser(uid)
    }
    class TopupRepository {
        +fetchTopups(userId) Topup[]
    }
    class WithdrawalRepository {
        +fetchWithdrawals(userId) Withdrawal[]
        +requestWithdrawal(amount)
    }
    class PaymentViewModel {
        +Double balance
        +Double heldBalance
        +Int points
        +Int pendingPoints
        +Topup[] topups
        +Withdrawal[] withdrawals
        +Bool isLoading
        +String? errorMessage
        +String? successMessage
        +String bankName
        +String bankAccountNumber
        +String bankAccountName
        +PaymentTarget? paymentTarget
        +String? currentOrderId
        +Int[] presetAmounts
        +Int minTopupAmount
        +Int maxTopupAmount
        +Bool hasBankDetails
        +Double availableBalance
        -RealtimeChannelV2? realtimeChannel
        -Task[] realtimeReaderTasks
        -Set~String~ knownSuccessTopupIds
        -Bool didLoadTopupsOnce
        +deinit()
        +start()
        +startRealtimeSubscription()
        +stop()
        +refresh()
        +startTopup(amount)
        +resumeTopup(topup)
        +paymentFlowFinished()
        +saveBankDetails(name, number, accName) Bool
        +requestWithdrawal(amount) Bool
        -detectSuccessfulTopups(fetched)
    }
    class Topup {
        +String? id
        +String userId
        +String orderId
        +Double grossAmount
        +String status
        +String? paymentType
        +String? redirectUrl
        +String? snapToken
        +Date? createdAt
        +Date? updatedAt
    }
    class Withdrawal {
        +String? id
        +String userId
        +Double amount
        +String? bankName
        +String? bankAccountNumber
        +String? bankAccountName
        +String status
        +String? notes
        +Date? createdAt
        +Date? updatedAt
    }
    class IndonesianBank {
        +String id
        +String name
        +Int[] accountLengths
        +String lengthDescription
        +IndonesianBank[] all$
        +isValidAccountNumber(acct) Bool
        +named(name) IndonesianBank?$
    }
    class CreateTopupRequest {
        +String action
        +Int amount
    }
    class CreateTopupResponse {
        +String order_id
        +String redirect_url
        +String token
    }
    class BankDetailsUpdatePayload {
        +String bank_name
        +String bank_account_number
        +String bank_account_name
    }
    class RequestWithdrawalParams {
        +Double p_amount
    }
    class PaymentTarget {
        +UUID id
        +URL url
    }

    PaymentViewModel "1" --> "1" PaymentService : creates topup via
    PaymentViewModel "1" --> "1" TopupRepository : reads
    PaymentViewModel "1" --> "1" WithdrawalRepository : reads/updates
    PaymentViewModel "1" --> "1" UserRepository : reads/updates
    PaymentViewModel "1" --> "1" AuthService : reads session
    PaymentViewModel "1" --> "*" Topup : displays
    PaymentViewModel "1" --> "*" Withdrawal : displays
    PaymentViewModel "1" --> "0..1" PaymentTarget : tracks
    PaymentService ..> CreateTopupRequest : sends
    PaymentService ..> CreateTopupResponse : returns
    TopupRepository ..> Topup : returns
    WithdrawalRepository ..> Withdrawal : returns
    WithdrawalRepository ..> RequestWithdrawalParams : sends
    UserRepository ..> BankDetailsUpdatePayload : sends

```

---

## 10. Order History

Per-role history tabs (customer / bengkel / mechanic), each loading completed/past orders and surfacing detail, re-tracking, and "already reported" state. Class members here are complete: `+` = public (`@Published` state / public methods), `-` = private implementation state and helpers.

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
classDiagram
    direction LR

    class AuthService {
        +getCurrentSession() Session
        +currentUID() String
        +cachedSession() Session?
        +authStateChanges() AsyncStream
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phoneNumber)
    }
    class BengkelRepository {
        +fetchBengkel(providerUid) Bengkel
        +fetchById(id) Bengkel
        +insertBengkel(bengkel)
        +updateBengkel(bengkelId, payload)
        +updateServices(bengkelId, payload)
        +deleteBengkel(bengkelId)
    }
    class OrderRepository {
        +createOrder(payload) CreatedServiceRequest
        +fetchOrders(customerId) NearbyOrder[]
        +fetchBengkelOrders(bengkelId) NearbyOrder[]
        +fetchMechanicOrders(mechanicId) NearbyOrder[]
        +fetchOrder(id) NearbyOrder
        +fetchActiveOrder(customerId) NearbyOrder?
        +fetchTodaysEarnings(bengkelId) Double
        +updateOrderPrice(id, price)
        +cancelOrder(id)
        +deleteOrder(id)
        +acceptBid(bidId) NearbyOrder
        +markOrderCompleted(reqId, url) NearbyOrder
        +submitRating(reqId, rating)
        +openDispute(reqId, reason, url) NearbyOrder
    }
    class BehaviorReportRepository {
        +submit(reqId, reporterId, reason)
        +fetchReportedRequestIds(reporterId) String[]
    }
    class NearbyOrder {
        +String id
        +String customerId
        +String? customerName
        +String? serviceType
        +String? description
        +Bool? isEmergency
        +Double latitude
        +Double longitude
        +Int? price
        +String status
        +Int? tireCount
        +String[]? photoUrls
        +String? vehicleId
        +String? vehicleInfo
        +String? bengkelId
        +String? mechanicId
        +Int? rating
        +Bool? customerCompleted
        +Bool? providerCompleted
        +String? completionPhotoUrl
        +Bool? usePoints
        +Int? pointsUsed
        +Int? pointsEarned
        +String? createdAt
        +String? assignedAt
        +Double? distanceM
    }
    class HistoryViewModel {
        +NearbyOrder[] orders
        +Bool isLoading
        +String? errorMessage
        +NearbyOrder? detailOrder
        +NearbyOrder? biddingOrder
        +Bid? trackingBid
        +CLLocationCoordinate2D? trackingCoordinate
        +Set~String~ reportedOrderIds
        +loadOrders()
        +select(order)
        +markReported(orderId)
        -openTracking(order)
        -isOrderedBefore(lhs, rhs) Bool$
        -priority(status) Int$
    }
    class BengkelHistoryViewModel {
        +NearbyOrder[] orders
        +Bool isLoading
        +String? errorMessage
        +NearbyOrder? detailOrder
        +Set~String~ reportedOrderIds
        -RealtimeChannelV2? channel
        -String? bengkelId
        -Task[] realtimeReaderTasks
        +loadOrders()
        +select(order)
        +markReported(orderId)
        +deinit()
        -startRealtimeIfNeeded()
        -reload()
        -isOrderedBefore(lhs, rhs) Bool$
        -priority(status) Int$
    }
    class MechanicHistoryViewModel {
        +NearbyOrder[] orders
        +Bool isLoading
        +String? errorMessage
        +NearbyOrder? detailOrder
        +Set~String~ reportedOrderIds
        -String? mechanicId
        -NSObjectProtocol? ordersChangedObserver
        -NSObjectProtocol? reassignObserver
        +init()
        +deinit()
        +loadOrders()
        +select(order)
        +markReported(orderId)
        -reload()
        -isOrderedBefore(lhs, rhs) Bool$
        -priority(status) Int$
    }
    class BidRepository {
        +fetchAcceptedBid(serviceRequestId) Bid?
        +fetchBids(serviceRequestId) Bid[]
        +fetchBidsForBengkel(bengkelId) Bid[]
        +updateStatus(bidId, status)
    }
    class Bid {
        +String id
        +String serviceRequestId
        +String providerUid
        +String bengkelId
        +Int price
        +String? notes
        +String status
        +String? createdAt
        +Bengkel? bengkel
    }

    HistoryViewModel "1" --> "1" OrderRepository : reads
    HistoryViewModel "1" --> "1" BidRepository : reads
    HistoryViewModel "1" --> "1" BehaviorReportRepository : reads
    HistoryViewModel "1" --> "1" AuthService : reads session
    HistoryViewModel "1" --> "*" NearbyOrder : displays
    HistoryViewModel "1" --> "0..1" NearbyOrder : shows detail of
    HistoryViewModel "1" --> "0..1" NearbyOrder : resumes bidding for
    HistoryViewModel "1" --> "0..1" Bid : tracks
    BengkelHistoryViewModel "1" --> "1" OrderRepository : reads
    BengkelHistoryViewModel "1" --> "1" BengkelRepository : reads
    BengkelHistoryViewModel "1" --> "1" BehaviorReportRepository : reads
    BengkelHistoryViewModel "1" --> "1" AuthService : reads session
    BengkelHistoryViewModel "1" --> "*" NearbyOrder : displays
    BengkelHistoryViewModel "1" --> "0..1" NearbyOrder : shows detail of
    MechanicHistoryViewModel "1" --> "1" OrderRepository : reads
    MechanicHistoryViewModel "1" --> "1" BehaviorReportRepository : reads
    MechanicHistoryViewModel "1" --> "1" AuthService : reads session
    MechanicHistoryViewModel "1" --> "*" NearbyOrder : displays
    MechanicHistoryViewModel "1" --> "0..1" NearbyOrder : shows detail of
    OrderRepository ..> NearbyOrder : returns
    BidRepository ..> Bid : returns

```

---

## 11. Behavior Reports & Disputes

Report the counterparty's behavior on an order (one report per reporter per order). A dispute on an in-progress order is filed via `OrderRepository.openDispute` (which cancels → escrow refunds); the report itself goes through `BehaviorReportRepository`.

```mermaid
---
config:
  layout: elk
  elk:
    nodePlacementStrategy: LINEAR_SEGMENTS
    mergeEdges: false
---
classDiagram
    direction LR

    class AuthService {
        +getCurrentSession() Session
        +currentUID() String
        +cachedSession() Session?
        +authStateChanges() AsyncStream
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phoneNumber)
    }
    class OrderRepository {
        +createOrder(payload) CreatedServiceRequest
        +fetchOrders(customerId) NearbyOrder[]
        +fetchBengkelOrders(bengkelId) NearbyOrder[]
        +fetchMechanicOrders(mechanicId) NearbyOrder[]
        +fetchOrder(id) NearbyOrder
        +fetchActiveOrder(customerId) NearbyOrder?
        +fetchTodaysEarnings(bengkelId) Double
        +updateOrderPrice(id, price)
        +cancelOrder(id)
        +deleteOrder(id)
        +acceptBid(bidId) NearbyOrder
        +markOrderCompleted(reqId, url) NearbyOrder
        +submitRating(reqId, rating)
        +openDispute(reqId, reason, url) NearbyOrder
    }
    class BehaviorReportRepository {
        +submit(reqId, reporterId, reason)
        +fetchReportedRequestIds(reporterId) String[]
    }
    class BehaviorReportViewModel {
        +Bool isSubmitting
        +String? errorMessage
        +submit(reqId, reason) Bool
    }
    class BehaviorReportPayload {
        +String service_request_id
        +String reporter_id
        +String reason
    }
    class OpenDisputeParams {
        +String p_request_id
        +String p_reason
        +String? p_proof_url
    }
    class ReportedRequestRow {
        +String service_request_id
    }

    BehaviorReportViewModel "1" --> "1" BehaviorReportRepository : submits via
    BehaviorReportViewModel "1" --> "1" AuthService : reads session
    BehaviorReportRepository ..> BehaviorReportPayload : sends
    BehaviorReportRepository ..> ReportedRequestRow : returns
    OrderRepository ..> OpenDisputeParams : sends

```

---

### Shared types referenced across features

`NearbyOrder` (the `service_requests` row) and `AuthService` appear in almost every feature — `NearbyOrder` is the central "order" entity that bidding, mechanics, tracking, completion, and history all revolve around. `Bengkel`/`BengkelService`/`ServiceType` are detailed in **§3**; `Bid` in **§4**. `ImageCompressor` (static JPEG downscaler) appears in **§1** and **§6**, the two features that compress before upload.

**Deliberately omitted** (View-layer only, no ViewModel/Repository touches them): `NetworkMonitor` (a `Services/` ObservableObject publishing `isConnected`, consumed directly by `ContentView` for the offline banner) and `NearbyMechanic` (a model decoded only by the `MechanicCard` view component).
