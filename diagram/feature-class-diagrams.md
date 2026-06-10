# BengkelIn — Per-Feature Class Diagrams

Class diagrams for the iOS app (`BengkelIn_SE/`), split by feature. Each section is an independent, directly-renderable Mermaid `classDiagram` showing that feature's ViewModels, the Repositories/Services they depend on, and the Models/DTOs that flow through them.

**Layers** (identify by class-name suffix / annotation): `*ViewModel` = ViewModel · `*Repository` = Repository · `*Service` = Service · `*Payload`/`*Params`/`*Request`/`*Response` = DTO · `<<interface>>` = Protocol · `<<enumeration>>` = Enum · everything else = Model.

**Arrows**: `..>` depends on / uses · `-->` association · `*--` composition · `..|>` realizes interface.

> All ViewModels are `@MainActor ObservableObject`; properties shown are `@Published` state. Repositories/Services are stateless. See the root `CLAUDE.md` for the layering rules.

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
        +updatePhoneNumber(phone)
    }
    class StorageService {
        +uploadAvatar(uid, data) String
        +uploadOrderPhoto(uid, data) String
        +deleteOrderPhotos(urls)
        +uploadChatImage(reqId, data) String
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
        +AppMode appMode
        +Bool isLoading
        +Bool isInitializing
        +String? errorMessage
        +String? successMessage
        +loadInitialSession()
        +login(email, password)
        +signUp(email, password, name, phone)
        +fetchUser()
        +sendPasswordResetEmail()
        +deleteAccount(password)
        +signOut()
    }
    class ProfileViewModel {
        +Bool isLoading
        +String? errorMessage
        +String? successMessage
        +updateProfile(name, phone) Bool
        +uploadProfileImage(data) Bool
    }
    class User {
        +String id
        +String name
        +String role
        +Double balance
        +Double? heldBalance
        +Int? points
        +String? email
        +String? phoneNumber
        +String? profileImageUrl
        +Double availableBalance
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

    AuthViewModel ..> AuthService
    AuthViewModel ..> UserRepository
    AuthViewModel --> User
    AuthViewModel --> AppMode
    ProfileViewModel ..> AuthService
    ProfileViewModel ..> UserRepository
    ProfileViewModel ..> StorageService
    AuthService ..> SignUpRequest
    UserRepository ..> User
    UserRepository ..> ProfileUpdatePayload
    UserRepository ..> ProfileImageUpdatePayload

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
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phone)
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
        +addVehicle(manufacturer, model, year, plate, color) Bool
        +updateVehicle(id, ...) Bool
        +deleteVehicle(id) Bool
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

    VehicleViewModel ..> AuthService
    VehicleViewModel ..> VehicleRepository
    VehicleViewModel --> Vehicle
    VehicleRepository ..> Vehicle
    VehicleRepository ..> VehicleUpdatePayload

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
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phone)
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
    }
    class BengkelViewModel {
        +Bengkel? myBengkel
        +Double todaysEarnings
        +Bool hasAcceptedMechanic
        +String locationAddress
        +Bool isEditingLocation
        +Bool isFetchingLocation
        +PhotonSearchFeature[] searchResults
        +MKCoordinateRegion region
        +registerBengkel(name, address) Bool
        +updateBengkel(id, name, address) Bool
        +deleteBengkel(id, password, email) Bool
        +addService(id, type, active) Bool
        +updateService(id, serviceId, type, active) Bool
        +deleteService(id, serviceId) Bool
        +loadTodaysEarnings()
        +useCurrentLocation()
        +selectSearchResult(result)
        +updateLocationFromMap(coordinate)
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
    }
    class PhotonSearchFeature {
        +UUID id
        +PhotonSearchProperties properties
        +PhotonSearchGeometry geometry
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
    BengkelViewModel ..> BengkelRepository
    BengkelViewModel ..> LocationService
    BengkelViewModel ..> OrderRepository
    BengkelViewModel ..> MechanicRepository
    BengkelViewModel ..> AuthService
    BengkelViewModel --> Bengkel
    BengkelRepository ..> Bengkel
    BengkelRepository ..> BengkelUpdatePayload
    BengkelRepository ..> BengkelServicesUpdatePayload
    LocationService ..> PhotonSearchFeature
    Bengkel "1" *-- "*" BengkelService : offers
    BengkelService --> ServiceType

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
        +updatePhoneNumber(phone)
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
        +CLLocationCoordinate2D defaultCenter
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
        +init(serviceType, latitude, longitude, tireCount, photoUrls, vehicleId, vehicleInfo, usePoints)
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
        +parseISODate(s) Date?
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

    OrderViewModel ..> OrderRepository
    OrderViewModel ..> LocationService
    OrderViewModel ..> StorageService
    OrderViewModel ..> UserRepository
    OrderViewModel ..> VehicleRepository
    OrderViewModel ..> AuthService
    CustomerBiddingViewModel ..> OrderRepository
    CustomerBiddingViewModel ..> BidRepository
    CustomerBiddingViewModel ..> UserRepository
    CustomerBiddingViewModel ..> StorageService
    CustomerBiddingViewModel ..> NotificationService
    CustomerBiddingViewModel ..> AuthService
    CustomerBiddingViewModel --> Bid
    BengkelBiddingViewModel ..> OrderRepository
    BengkelBiddingViewModel ..> BidRepository
    BengkelBiddingViewModel ..> BiddingService
    BengkelBiddingViewModel ..> BengkelRepository
    BengkelBiddingViewModel ..> MechanicRepository
    BengkelBiddingViewModel ..> NotificationService
    BengkelBiddingViewModel ..> AuthService
    BengkelBiddingViewModel --> NearbyOrder
    OrderRepository ..> ServiceRequestPayload
    OrderRepository ..> NearbyOrder
    OrderRepository ..> AcceptBidParams
    BidRepository ..> Bid
    BiddingService ..> PlaceBidRequest
    BiddingService ..> NearbyOrder
    Bid --> "0..1" Bengkel : bengkel

```

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
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phone)
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
        +String? serviceType
        +String? description
        +Double latitude
        +Double longitude
        +Int? price
        +String status
        +Int? tireCount
        +String[]? photoUrls
        +String? vehicleId
        +String? bengkelId
        +String? mechanicId
        +Int? rating
        +Bool? customerCompleted
        +Bool? providerCompleted
        +String? completionPhotoUrl
        +Double? distanceM
    }
    class BengkelRosterViewModel {
        +RosterMember[] roster
        +String inviteEmail
        +Bool isInviting
        +fetchRoster()
        +invite() Bool
        +remove(member)
    }
    class MechanicInviteViewModel {
        +MechanicInvite[] invites
        +Bool hasPendingInvites
        +fetchInvites()
        +respond(invite, accept) Bool
    }
    class AssignMechanicViewModel {
        +AvailableMechanic[] availableMechanics
        +Bool isAssigning
        +fetchAvailableMechanics(reqId)
        +assign(reqId, mechanicId) Bool
    }
    class MechanicDashboardViewModel {
        +NearbyOrder[] jobs
        +NearbyOrder? newAssignmentAlert
        +start()
        +refreshOnForeground()
        +stop()
    }
    class MechanicJobsViewModel {
        +NearbyOrder[] jobs
        +Bool isLoading
        +fetchJobs()
    }
    class RosterMember {
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
        +String registrationId
        +String bengkelId
        +String bengkelName
        +String status
        +String? createdAt
        +Bool isPending
    }
    class AvailableMechanic {
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

    BengkelRosterViewModel ..> MechanicRepository
    MechanicInviteViewModel ..> MechanicRepository
    AssignMechanicViewModel ..> MechanicRepository
    AssignMechanicViewModel ..> MechanicAssignmentRepository
    MechanicDashboardViewModel ..> MechanicAssignmentRepository
    MechanicDashboardViewModel ..> AuthService
    MechanicDashboardViewModel ..> NotificationService
    MechanicJobsViewModel ..> MechanicAssignmentRepository
    MechanicJobsViewModel ..> AuthService
    MechanicRepository ..> RosterMember
    MechanicRepository ..> MechanicInvite
    MechanicRepository ..> AvailableMechanic
    MechanicRepository ..> RespondInviteParams
    MechanicAssignmentRepository ..> AssignMechanicParams
    MechanicAssignmentRepository ..> NearbyOrder

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
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phone)
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
        +ChatMessage[] messages
        +String draft
        +Bool isSending
        +Bool isLocked
        +String? errorMessage
        +start()
        +loadMessages()
        +sendText()
        +sendImage(data)
    }
    class ChatWatchViewModel {
        +Int unreadCount
        +start()
        +stop()
        +markAllRead()
    }
    class ChatReadCursor {
        +String serviceRequestId
        +Date lastReadAt
        +markRead(at)
        +unreadCount(incoming) Int
    }
    class ChatPresence {
        +String? activeServiceRequestId
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

    ChatViewModel ..> ChatRepository
    ChatViewModel ..> OrderRepository
    ChatViewModel ..> StorageService
    ChatViewModel ..> AuthService
    ChatViewModel --> ChatMessage
    ChatWatchViewModel ..> ChatRepository
    ChatWatchViewModel ..> NotificationService
    ChatWatchViewModel ..> AuthService
    ChatWatchViewModel ..> ChatReadCursor
    ChatWatchViewModel ..> ChatPresence
    ChatRepository ..> ChatMessage
    ChatRepository ..> ChatMessagePayload

```

---

## 7. Live Location Tracking

The mover (provider/mechanic) publishes GPS to `order_locations`; the customer publishes to `customer_locations`; the other side subscribes. `BengkelRouteViewModel` drives the provider/mechanic route map; `OrderTrackingViewModel` the customer tracking map. These VMs own a `CLLocationManager`.

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
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phone)
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
        +NearbyOrder? order
        +Bool isLive
        +String? lastUpdated
        +start(reqId)
        +openDispute(reason) Bool
        +stop()
    }
    class LocationPublishViewModel {
        +Bool isPublishing
        +String? errorMessage
        +start(reqId, coordinate)
        +stop()
    }
    class CustomerLocationPublishViewModel {
        +Bool isPublishing
        +CLLocationCoordinate2D? currentCoordinate
        +start(reqId)
        +stop()
    }
    class BengkelRouteViewModel {
        +NearbyOrder? order
        +String? myUid
        +Bool reassignedAway
        +start(order)
        +refreshOrder()
        +reportIssue(reason, photo) Bool
        +stop()
    }
    class OrderLocation {
        +String serviceRequestId
        +String? providerUid
        +Double latitude
        +Double longitude
        +String? updatedAt
    }
    class CustomerLocation {
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

    OrderTrackingViewModel ..> OrderLocationRepository
    OrderTrackingViewModel ..> OrderRepository
    OrderTrackingViewModel ..> NotificationService
    LocationPublishViewModel ..> OrderLocationRepository
    LocationPublishViewModel ..> OrderRepository
    LocationPublishViewModel ..> AuthService
    CustomerLocationPublishViewModel ..> OrderLocationRepository
    CustomerLocationPublishViewModel ..> AuthService
    BengkelRouteViewModel ..> OrderRepository
    BengkelRouteViewModel ..> BengkelRepository
    BengkelRouteViewModel ..> OrderLocationRepository
    BengkelRouteViewModel ..> StorageService
    BengkelRouteViewModel ..> AuthService
    BengkelRouteViewModel ..> NotificationService
    OrderLocationRepository ..> OrderLocation
    OrderLocationRepository ..> CustomerLocation
    OrderLocationRepository ..> OrderLocationPayload
    OrderLocationRepository ..> CustomerLocationPayload

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
        +updatePhoneNumber(phone)
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

    OrderCompletionViewModel ..> OrderRepository
    OrderCompletionViewModel ..> StorageService
    OrderCompletionViewModel ..> AuthService
    OrderCompletionViewModel ..> NotificationService
    OrderCompletionViewModel --> NearbyOrder
    OrderRatingViewModel ..> OrderRepository
    OrderRepository ..> MarkCompletedParams
    OrderRepository ..> RateOrderParams
    OrderRepository ..> NearbyOrder

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
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phone)
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
        +String bankName
        +String bankAccountNumber
        +String bankAccountName
        +start()
        +startTopup(amount)
        +saveBankDetails(name, number, accName) Bool
        +requestWithdrawal(amount) Bool
    }
    class Topup {
        +String? id
        +String userId
        +String orderId
        +Double grossAmount
        +String status
        +String? snapToken
        +String? redirectUrl
    }
    class Withdrawal {
        +String? id
        +String userId
        +Double amount
        +String status
        +String? bankName
        +String? bankAccountNumber
    }
    class IndonesianBank {
        +String id
        +String name
        +Int[] accountLengths
        +isValidAccountNumber(acct) Bool
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

    PaymentViewModel ..> PaymentService
    PaymentViewModel ..> TopupRepository
    PaymentViewModel ..> WithdrawalRepository
    PaymentViewModel ..> UserRepository
    PaymentViewModel ..> AuthService
    PaymentViewModel --> Topup
    PaymentViewModel --> Withdrawal
    PaymentService ..> CreateTopupResponse
    TopupRepository ..> Topup
    WithdrawalRepository ..> Withdrawal
    WithdrawalRepository ..> RequestWithdrawalParams
    UserRepository ..> BankDetailsUpdatePayload

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
        +updatePhoneNumber(phone)
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
        -isOrderedBefore(lhs, rhs) Bool
        -priority(status) Int
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
        -isOrderedBefore(lhs, rhs) Bool
        -priority(status) Int
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
        -isOrderedBefore(lhs, rhs) Bool
        -priority(status) Int
    }
    class BidRepository {
        +fetchAcceptedBid(serviceRequestId) Bid?
        +fetchBids(serviceRequestId) Bid[]
        +fetchBidsForBengkel(bengkelId) Bid[]
        +updateStatus(bidId, status)
    }

    HistoryViewModel ..> OrderRepository
    HistoryViewModel ..> BidRepository
    HistoryViewModel ..> BehaviorReportRepository
    HistoryViewModel ..> AuthService
    HistoryViewModel --> NearbyOrder
    BengkelHistoryViewModel ..> OrderRepository
    BengkelHistoryViewModel ..> BengkelRepository
    BengkelHistoryViewModel ..> BehaviorReportRepository
    BengkelHistoryViewModel ..> AuthService
    MechanicHistoryViewModel ..> OrderRepository
    MechanicHistoryViewModel ..> BehaviorReportRepository
    MechanicHistoryViewModel ..> AuthService
    OrderRepository ..> NearbyOrder

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
        +signIn(email, password) Session
        +signUp(request)
        +signOut()
        +resetPassword(email)
        +updatePhoneNumber(phone)
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

    BehaviorReportViewModel ..> BehaviorReportRepository
    BehaviorReportViewModel ..> AuthService
    BehaviorReportRepository ..> BehaviorReportPayload
    BehaviorReportRepository ..> ReportedRequestRow
    OrderRepository ..> OpenDisputeParams

```

---

### Shared types referenced across features

`NearbyOrder` (the `service_requests` row) and `AuthService` appear in almost every feature — `NearbyOrder` is the central "order" entity that bidding, mechanics, tracking, completion, and history all revolve around. `Bengkel`/`BengkelService`/`ServiceType` are detailed in **§3**; `Bid` in **§4**.
