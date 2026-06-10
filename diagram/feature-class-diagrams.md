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
    class ImageCompressor {
        +compressed(data, maxDimension, quality) Data$
    }
    class AuthServiceError {
        <<enumeration>>
        emailAlreadyRegistered
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

    AuthViewModel ..> AuthService
    AuthViewModel ..> UserRepository
    AuthViewModel --> User
    AuthViewModel --> AppMode
    ProfileViewModel ..> AuthService
    ProfileViewModel ..> UserRepository
    ProfileViewModel ..> StorageService
    ProfileViewModel ..> ImageCompressor
    AuthService ..> SignUpRequest
    AuthService ..> AuthServiceError
    UserRepository ..> User
    UserRepository ..> ProfileUpdatePayload
    UserRepository ..> ProfileImageUpdatePayload
    UserRepository ..> BankDetailsUpdatePayload

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
        +cachedSession() Session?
        +authStateChanges() AsyncStream
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
        +Date? createdAt
    }
    class BengkelViewModel {
        +Bengkel? myBengkel
        +Double todaysEarnings
        +Bool hasAcceptedMechanic
        +Bool isLoading
        +String? errorMessage
        +String? successMessage
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
        -AuthService authService
        -LocationService locationService
        -OrderRepository orderRepository
        -StorageService storageService
        -UserRepository userRepository
        -VehicleRepository vehicleRepository
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
        -AuthService authService
        -UserRepository userRepository
        -OrderRepository orderRepository
        -BidRepository bidRepository
        -StorageService storageService
        -NotificationService notificationService
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
        -AuthService authService
        -OrderRepository orderRepository
        -BengkelRepository bengkelRepository
        -BidRepository bidRepository
        -BiddingService biddingService
        -MechanicRepository mechanicRepository
        -NotificationService notificationService
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
    OrderViewModel --> Vehicle
    OrderViewModel --> LoadingPhase
    CustomerBiddingViewModel --> LoadingPhase
    OrderRepository ..> ServiceRequestPayload
    OrderRepository ..> NearbyOrder
    OrderRepository ..> AcceptBidParams
    OrderRepository ..> CreatedServiceRequest
    OrderRepository ..> CancelOrderParams
    OrderRepository ..> StartSearchPayload
    OrderRepository ..> TodaysEarningRow
    BidRepository ..> Bid
    BidRepository ..> BidStatusUpdate
    BiddingService ..> PlaceBidRequest
    BiddingService ..> PlaceBidResponse
    BiddingService ..> OrdersRequest
    BiddingService ..> OrdersResponse
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
        +cachedSession() Session?
        +authStateChanges() AsyncStream
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
        +RosterMember[] pendingMembers
        +RosterMember[] acceptedMembers
        +String inviteEmail
        +Bool isInviting
        +Bool isLoading
        +String? errorMessage
        +String? successMessage
        +fetchRoster()
        +invite() Bool
        +remove(member)
    }
    class MechanicInviteViewModel {
        +MechanicInvite[] invites
        +MechanicInvite[] pendingInvites
        +Bool isLoading
        +String? errorMessage
        +Bool hasPendingInvites
        +fetchInvites()
        +respond(invite, accept) Bool
    }
    class AssignMechanicViewModel {
        +AvailableMechanic[] availableMechanics
        +Bool isAssigning
        +Bool isLoading
        +String? errorMessage
        +fetchAvailableMechanics(reqId)
        +assign(reqId, mechanicId) Bool
    }
    class MechanicDashboardViewModel {
        +NearbyOrder[] jobs
        +NearbyOrder? newAssignmentAlert
        +Bool isLoading
        +String? errorMessage
        +start()
        +reset()
        +refreshOnForeground()
        +stop()
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

    BengkelRosterViewModel ..> MechanicRepository
    BengkelRosterViewModel --> RosterMember
    MechanicInviteViewModel ..> MechanicRepository
    MechanicInviteViewModel --> MechanicInvite
    AssignMechanicViewModel ..> MechanicRepository
    AssignMechanicViewModel ..> MechanicAssignmentRepository
    AssignMechanicViewModel --> AvailableMechanic
    MechanicDashboardViewModel ..> MechanicAssignmentRepository
    MechanicDashboardViewModel ..> AuthService
    MechanicDashboardViewModel ..> NotificationService
    MechanicDashboardViewModel --> NearbyOrder
    MechanicJobsViewModel ..> MechanicAssignmentRepository
    MechanicJobsViewModel ..> AuthService
    MechanicJobsViewModel --> NearbyOrder
    MechanicRepository ..> RosterMember
    MechanicRepository ..> MechanicInvite
    MechanicRepository ..> AvailableMechanic
    MechanicRepository ..> RespondInviteParams
    MechanicRepository ..> InviteMechanicParams
    MechanicRepository ..> RemoveMechanicParams
    MechanicRepository ..> AvailableMechanicsParams
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
        +start()
        +loadMessages()
        +loadLockState()
        +startRealtimeSubscription()
        +stopRealtimeSubscription()
        +sendText()
        +sendImage(data)
    }
    class ChatWatchViewModel {
        +Int unreadCount
        +start()
        +stop()
        +markAllRead()
    }
    class ImageCompressor {
        +compressed(data, maxDimension, quality) Data$
    }
    class ChatReadCursor {
        +String serviceRequestId
        +Date lastReadAt
        +markRead(at)
        +unreadCount(incoming) Int
        +date(of message) Date$
    }
    class ChatPresence {
        +ChatPresence shared$
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
    ChatViewModel ..> ImageCompressor
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
        +String status
        +Bool alreadyRated
        +String? errorMessage
        +start(reqId)
        +openDispute(reason) Bool
        +notifyBengkelNear()
        +stop()
    }
    class LocationPublishViewModel {
        +Bool isPublishing
        +String? errorMessage
        +start(reqId, coordinate)
        +stop()
        +locationManagerDidChangeAuthorization(manager)
        +locationManager(manager, didUpdateLocations)
        +locationManager(manager, didFailWithError)
    }
    class CustomerLocationPublishViewModel {
        +Bool isPublishing
        +CLLocationCoordinate2D? currentCoordinate
        +String? errorMessage
        +start(reqId)
        +stop()
        +locationManagerDidChangeAuthorization(manager)
        +locationManager(manager, didUpdateLocations)
        +locationManager(manager, didFailWithError)
    }
    class BengkelRouteViewModel {
        +NearbyOrder? order
        +String? myUid
        +Bool reassignedAway
        +RouteLocationStore locationStore
        +Bool isPaused
        +String status
        +Bool selfAssigned
        +Bool amAssignee
        +Bool viewerIsProvider
        +Bool viewerIsAssignee
        +String handlerLabel
        +CLLocationCoordinate2D? bengkelCoordinate
        +CLLocationCoordinate2D? customerLiveCoordinate
        +CLLocationCoordinate2D? assigneeCoordinate
        +start(order)
        +refreshOrder()
        +refreshAfterAssignment()
        +reportIssue(reason, photo) Bool
        +stop()
        +locationManagerDidChangeAuthorization(manager)
        +locationManager(manager, didUpdateLocations)
        +locationManager(manager, didFailWithError)
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
    BengkelRouteViewModel "1" *-- "1" RouteLocationStore : locationStore
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
        -AuthService authService
        -OrderRepository orderRepository
        -StorageService storageService
        -NotificationService notificationService
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
        -OrderRepository orderRepository
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
        +cachedSession() Session?
        +authStateChanges() AsyncStream
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
        +Double availableBalance
        +Int points
        +Int pendingPoints
        +Topup[] topups
        +Withdrawal[] withdrawals
        +String bankName
        +String bankAccountNumber
        +String bankAccountName
        +Bool hasBankDetails
        +Int[] presetAmounts
        +Int minTopupAmount
        +Int maxTopupAmount
        +Bool isLoading
        +String? errorMessage
        +String? successMessage
        +PaymentTarget? paymentTarget
        +String? currentOrderId
        +start()
        +startRealtimeSubscription()
        +stop()
        +refresh()
        +startTopup(amount)
        +resumeTopup(topup)
        +paymentFlowFinished()
        +saveBankDetails(name, number, accName) Bool
        +requestWithdrawal(amount) Bool
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

    PaymentViewModel ..> PaymentService
    PaymentViewModel ..> TopupRepository
    PaymentViewModel ..> WithdrawalRepository
    PaymentViewModel ..> UserRepository
    PaymentViewModel ..> AuthService
    PaymentViewModel --> Topup
    PaymentViewModel --> Withdrawal
    PaymentViewModel --> PaymentTarget
    PaymentService ..> CreateTopupRequest
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
        -AuthService authService
        -OrderRepository orderRepository
        -BidRepository bidRepository
        -BehaviorReportRepository behaviorReportRepository
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
        -BengkelRepository bengkelRepository
        -OrderRepository orderRepository
        -BehaviorReportRepository behaviorReportRepository
        -AuthService authService
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
        -OrderRepository orderRepository
        -BehaviorReportRepository behaviorReportRepository
        -AuthService authService
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

    HistoryViewModel ..> OrderRepository
    HistoryViewModel ..> BidRepository
    HistoryViewModel ..> BehaviorReportRepository
    HistoryViewModel ..> AuthService
    HistoryViewModel --> NearbyOrder
    BengkelHistoryViewModel ..> OrderRepository
    BengkelHistoryViewModel ..> BengkelRepository
    BengkelHistoryViewModel ..> BehaviorReportRepository
    BengkelHistoryViewModel ..> AuthService
    BengkelHistoryViewModel --> NearbyOrder
    MechanicHistoryViewModel ..> OrderRepository
    MechanicHistoryViewModel ..> BehaviorReportRepository
    MechanicHistoryViewModel ..> AuthService
    MechanicHistoryViewModel --> NearbyOrder
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
        +cachedSession() Session?
        +authStateChanges() AsyncStream
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

`NearbyOrder` (the `service_requests` row) and `AuthService` appear in almost every feature — `NearbyOrder` is the central "order" entity that bidding, mechanics, tracking, completion, and history all revolve around. `Bengkel`/`BengkelService`/`ServiceType` are detailed in **§3**; `Bid` in **§4**. `ImageCompressor` (static JPEG downscaler) appears in **§1** and **§6**, the two features that compress before upload.

**Deliberately omitted** (View-layer only, no ViewModel/Repository touches them): `NetworkMonitor` (a `Services/` ObservableObject publishing `isConnected`, consumed directly by `ContentView` for the offline banner) and `NearbyMechanic` (a model decoded only by the `MechanicCard` view component).
