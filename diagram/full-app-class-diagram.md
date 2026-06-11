# BengkelIn — Full-App Class Diagram

One comprehensive class diagram of the **entire iOS app's logic layers** (`BengkelIn_SE/`): every Enum, Model, Protocol, DTO, Repository, Service, and ViewModel, wired with their real relationships. **Every member is shown** — this is the unified superset of the per-feature diagrams in [`feature-class-diagrams.md`](feature-class-diagrams.md), so the two stay in lock-step with each other and with the codebase.

SwiftUI `View` structs are intentionally excluded — in a class diagram they would just be ~70 leaf nodes pointing at the ViewModels below. Also intentionally excluded (app/presentation plumbing, not logic layers): the app entry pair `BengkelInApp` + `AppDelegate` (`BengkelInApp.swift` — the delegate only wires `UNUserNotificationCenter` foreground banners), the `Extensions/` map helper (`MKCoordinateRegion.fitting`, used only by tracking Views), and view-local helper types (`OSMTileOverlay`, `Rupiah`, `DashboardRoute`). For a per-feature, presentation-friendly breakdown (each renders small and clean), see [`feature-class-diagrams.md`](feature-class-diagrams.md).

> **Layout compatibility:** this diagram is written **without `namespace` blocks on purpose**, so it renders in **both** the default (dagre) layout **and** the "adaptive" / **ELK** layout. The ELK layout engine does **not** support class-diagram `namespace` boxes — using them is what throws an error when you switch layouts. It is rendered in plain **black & white**; the layer of each class is read from its **name suffix / annotation** (see legend), so no color is needed.

**Layers** (identify by class-name suffix / annotation): `<<enumeration>>` = Enum · `<<interface>>` = Protocol · `<<extension>>` = Swift extension (the `Notification.Name` keys used as cross-ViewModel signals) · `*ViewModel` = ViewModel · `*Repository` = Repository · `*Service` = Service · `*Payload`/`*Params`/`*Request`/`*Response`/`*Row`/`*Update` = DTO · everything else = Model.

**Members**: `+` = public surface (`@Published` state, computed properties, public methods, `init`/`deinit`) · `-` = private implementation (realtime channels & reader `Task`s, `CLLocationManager`, private helpers) · `$` = static. Swift's `private(set)` members are publicly *readable*, so they carry `+` (the restricted setter has no UML symbol). **Injected Service/Repository dependencies are association arrows with multiplicities (`ViewModel "1" --> "1" AuthService`), not repeated as attributes** — the arrow *is* the field. Edge labels are semantic association names (verbs: `reads/updates`, `manages`, `displays`, `tracks`, `contains`, `embeds`, `owns`, `listens`, `publishes via`, `sends`, `returns`, …), not field names; multiplicity (`1`, `0..1`, `*`) is derived from the field's Swift type (`X`, `X?`, `[X]`).

**Arrows**: `..>` depends on / uses · `-->` association (incl. injected dependency) · `*--` composition · `..|>` realizes interface.

```mermaid
---
config:
  theme: base
  themeVariables:
    primaryColor: '#ffffff'
    primaryBorderColor: '#000000'
    primaryTextColor: '#000000'
    lineColor: '#000000'
    textColor: '#000000'
---
classDiagram
    direction TB

    %% ============================================================
    %% ENUMS
    %% ============================================================
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
    class AppMode {
        <<enumeration>>
        customer
        bengkel
        mechanic
    }
    class AuthServiceError {
        <<enumeration>>
        emailAlreadyRegistered
        +String? errorDescription
    }
    class LoadingPhase {
        <<enumeration>>
        idle
        loading(message)
        failed(title, message)
    }

    %% ============================================================
    %% PROTOCOL
    %% ============================================================
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

    %% ============================================================
    %% MODELS (domain entities)
    %% ============================================================
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
    class BengkelService {
        +String id
        +ServiceType serviceType
        +Bool isActive
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
    class ChatMessage {
        +String id
        +String serviceRequestId
        +String senderId
        +String? content
        +String? imageUrl
        +String? createdAt
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
    class NearbyMechanic {
        +String id
        +String providerUid
        +String name
        +String address
        +Double latitude
        +Double longitude
        +Double averageRating
        +Int totalReviews
        +BengkelService[]? offeredServices
        +Double distanceM
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
    class IndonesianBank {
        +String id
        +String name
        +Int[] accountLengths
        +String lengthDescription
        +IndonesianBank[] all$
        +named(name) IndonesianBank?$
        +isValidAccountNumber(acct) Bool
    }
    class PhotonSearchResponse {
        +PhotonSearchFeature[] features
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
    class RouteLocationStore {
        +CLLocationCoordinate2D? me
        +CLLocationCoordinate2D? customer
        +CLLocationCoordinate2D? handler
    }
    class PaymentTarget {
        +UUID id
        +URL url
    }
    class OrderRouteState {
        +OrderRouteState shared$
        +Bool isActive
        -Set~String~ activeIds
        +enter(id)
        +leave(id)
    }

    %% ============================================================
    %% DTOs  (Encodable payloads / Decodable responses)
    %% ============================================================
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
    class VehicleUpdatePayload {
        +String manufacturer
        +String model
        +Int year
        +String license_plate
        +String color
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
    class CreatedServiceRequest {
        +String id
    }
    class AcceptBidParams {
        +String p_bid_id
    }
    class CancelOrderParams {
        +String p_request_id
    }
    class StartSearchPayload {
        +Int price
    }
    class BidStatusUpdate {
        +String status
    }
    class TodaysEarningRow {
        +Int? price
    }
    class MarkCompletedParams {
        +String p_request_id
        +String? p_completion_photo_url
    }
    class RateOrderParams {
        +String p_request_id
        +Int p_rating
    }
    class OpenDisputeParams {
        +String p_request_id
        +String p_reason
        +String? p_proof_url
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
    class PlaceBidRequest {
        +String action
        +String serviceRequestId
        +String bengkelId
        +Int price
        +String? notes
    }
    class PlaceBidResponse {
        +Bid bid
    }
    class ChatMessagePayload {
        +String service_request_id
        +String sender_id
        +String? content
        +String? image_url
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
    class BehaviorReportPayload {
        +String service_request_id
        +String reporter_id
        +String reason
    }
    class ReportedRequestRow {
        +String service_request_id
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
    class RequestWithdrawalParams {
        +Double p_amount
    }
    class AssignMechanicParams {
        +String p_request_id
        +String p_mechanic_id
    }
    class AvailableMechanicsParams {
        +String p_request_id
    }
    class InviteMechanicParams {
        +String p_email
    }
    class RespondInviteParams {
        +String p_registration_id
        +Bool p_accept
    }
    class RemoveMechanicParams {
        +String p_registration_id
    }

    %% ============================================================
    %% REPOSITORIES  (Supabase DB / RPC)
    %% ============================================================
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
    class ChatRepository {
        +fetchMessages(serviceRequestId) ChatMessage[]
        +sendMessage(payload)
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
    class OrderLocationRepository {
        +upsertLocation(payload)
        +fetchLocation(reqId) OrderLocation?
        +upsertCustomerLocation(payload)
        +fetchCustomerLocation(reqId) CustomerLocation?
    }
    class BehaviorReportRepository {
        +submit(reqId, reporterId, reason)
        +fetchReportedRequestIds(reporterId) String[]
    }
    class TopupRepository {
        +fetchTopups(userId) Topup[]
    }
    class WithdrawalRepository {
        +fetchWithdrawals(userId) Withdrawal[]
        +requestWithdrawal(amount)
    }

    %% ============================================================
    %% SERVICES  (Auth SDK / Storage / external APIs / system / helpers)
    %% ============================================================
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
    class LocationService {
        +searchOSM(query, coordinate) PhotonSearchFeature[]
        +fetchAddress(from) String?
    }
    class PaymentService {
        +createTopup(amount) CreateTopupResponse
    }
    class BiddingService {
        +fetchOrdersForMechanic(lat, lon, radius) NearbyOrder[]
        +placeBid(reqId, bengkelId, price, notes) Bid
    }
    class NotificationService {
        +requestAuthorization()
        +notifyNewOrder(title, body)
    }
    class NetworkMonitor {
        +Bool isConnected
        -NWPathMonitor monitor
        -DispatchQueue queue
        +init()
        +deinit()
        +recheck()
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
    class MechanicNotifications["Notification.Name (extension)"] {
        <<extension>>
        +mechanicReassignedAway$
        +mechanicOrdersChanged$
    }

    %% ============================================================
    %% VIEWMODELS  (ObservableObject, @MainActor)
    %% ============================================================
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
    class BehaviorReportViewModel {
        +Bool isSubmitting
        +String? errorMessage
        +submit(reqId, reason) Bool
    }

    %% ============================================================
    %% MODEL STRUCTURAL RELATIONSHIPS
    %% ============================================================
    Bengkel "1" *-- "*" BengkelService : contains
    BengkelService "1" --> "1" ServiceType : references
    NearbyMechanic "1" *-- "*" BengkelService : contains
    Bid "1" --> "0..1" Bengkel : references
    PhotonSearchResponse "1" *-- "*" PhotonSearchFeature : contains
    PhotonSearchFeature "1" *-- "1" PhotonSearchProperties : embeds
    PhotonSearchFeature "1" *-- "1" PhotonSearchGeometry : embeds

    %% ============================================================
    %% PROTOCOL REALIZATION
    %% ============================================================
    BengkelViewModel ..|> LocationSearchable
    OrderViewModel ..|> LocationSearchable

    %% ============================================================
    %% VIEWMODEL -> REPOSITORY / SERVICE WIRING  (injected deps, role-named)
    %% ============================================================
    AuthViewModel "1" --> "1" AuthService : authenticates via
    AuthViewModel "1" --> "1" UserRepository : reads/updates
    ProfileViewModel "1" --> "1" AuthService : reads session
    ProfileViewModel "1" --> "1" UserRepository : updates
    ProfileViewModel "1" --> "1" StorageService : uploads via
    ProfileViewModel ..> ImageCompressor : uses
    VehicleViewModel "1" --> "1" AuthService : reads session
    VehicleViewModel "1" --> "1" VehicleRepository : reads/updates
    BengkelViewModel "1" --> "1" BengkelRepository : reads/updates
    BengkelViewModel "1" --> "1" LocationService : geocodes via
    BengkelViewModel "1" --> "1" OrderRepository : reads
    BengkelViewModel "1" --> "1" MechanicRepository : reads
    BengkelViewModel "1" --> "1" AuthService : reads session
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
    BengkelBiddingViewModel "1" --> "1" OrderRepository : reads
    BengkelBiddingViewModel "1" --> "1" BidRepository : reads/updates
    BengkelBiddingViewModel "1" --> "1" BiddingService : places bids via
    BengkelBiddingViewModel "1" --> "1" BengkelRepository : reads
    BengkelBiddingViewModel "1" --> "1" MechanicRepository : reads
    BengkelBiddingViewModel "1" --> "1" NotificationService : notifies via
    BengkelBiddingViewModel "1" --> "1" AuthService : reads session
    BengkelRosterViewModel "1" --> "1" MechanicRepository : reads/updates
    MechanicInviteViewModel "1" --> "1" MechanicRepository : reads/updates
    AssignMechanicViewModel "1" --> "1" MechanicRepository : reads
    AssignMechanicViewModel "1" --> "1" MechanicAssignmentRepository : assigns via
    MechanicDashboardViewModel "1" --> "1" MechanicAssignmentRepository : reads
    MechanicDashboardViewModel "1" --> "1" AuthService : reads session
    MechanicDashboardViewModel "1" --> "1" NotificationService : notifies via
    MechanicJobsViewModel "1" --> "1" MechanicAssignmentRepository : reads
    MechanicJobsViewModel "1" --> "1" AuthService : reads session
    ChatViewModel "1" --> "1" ChatRepository : reads/updates
    ChatViewModel "1" --> "1" OrderRepository : reads
    ChatViewModel "1" --> "1" StorageService : uploads via
    ChatViewModel "1" --> "1" AuthService : reads session
    ChatViewModel ..> ImageCompressor : uses
    ChatWatchViewModel "1" --> "1" ChatRepository : listens
    ChatWatchViewModel "1" --> "1" NotificationService : notifies via
    ChatWatchViewModel "1" --> "1" AuthService : reads session
    ChatWatchViewModel "1" *-- "1" ChatReadCursor : owns
    ChatWatchViewModel ..> ChatPresence : reads
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
    OrderCompletionViewModel "1" --> "1" OrderRepository : reads/updates
    OrderCompletionViewModel "1" --> "1" StorageService : uploads via
    OrderCompletionViewModel "1" --> "1" AuthService : reads session
    OrderCompletionViewModel "1" --> "1" NotificationService : notifies via
    OrderRatingViewModel "1" --> "1" OrderRepository : updates
    HistoryViewModel "1" --> "1" OrderRepository : reads
    HistoryViewModel "1" --> "1" BidRepository : reads
    HistoryViewModel "1" --> "1" BehaviorReportRepository : reads
    HistoryViewModel "1" --> "1" AuthService : reads session
    BengkelHistoryViewModel "1" --> "1" OrderRepository : reads
    BengkelHistoryViewModel "1" --> "1" BengkelRepository : reads
    BengkelHistoryViewModel "1" --> "1" BehaviorReportRepository : reads
    BengkelHistoryViewModel "1" --> "1" AuthService : reads session
    MechanicHistoryViewModel "1" --> "1" OrderRepository : reads
    MechanicHistoryViewModel "1" --> "1" BehaviorReportRepository : reads
    MechanicHistoryViewModel "1" --> "1" AuthService : reads session
    PaymentViewModel "1" --> "1" PaymentService : creates topup via
    PaymentViewModel "1" --> "1" TopupRepository : reads
    PaymentViewModel "1" --> "1" WithdrawalRepository : reads/updates
    PaymentViewModel "1" --> "1" UserRepository : reads/updates
    PaymentViewModel "1" --> "1" AuthService : reads session
    BehaviorReportViewModel "1" --> "1" BehaviorReportRepository : submits via
    BehaviorReportViewModel "1" --> "1" AuthService : reads session

    %% ============================================================
    %% VIEWMODEL -> MODEL  (state held)
    %% ============================================================
    AuthViewModel "1" --> "0..1" User : manages
    AuthViewModel "1" --> "1" AppMode : switches
    VehicleViewModel "1" --> "*" Vehicle : manages
    BengkelViewModel "1" --> "0..1" Bengkel : manages
    BengkelViewModel "1" --> "*" PhotonSearchFeature : displays
    OrderViewModel "1" --> "*" Vehicle : displays
    OrderViewModel "1" --> "*" PhotonSearchFeature : displays
    OrderViewModel "1" --> "1" LoadingPhase : tracks
    OrderViewModel "1" --> "0..1" ServiceType : tracks
    CustomerBiddingViewModel "1" --> "*" Bid : manages
    CustomerBiddingViewModel "1" --> "0..1" Bid : tracks
    CustomerBiddingViewModel "1" --> "1" LoadingPhase : tracks
    CustomerBiddingViewModel "1" --> "1" ServiceType : tracks
    BengkelBiddingViewModel "1" --> "*" NearbyOrder : displays
    BengkelBiddingViewModel "1" --> "0..1" NearbyOrder : tracks
    BengkelBiddingViewModel "1" --> "0..1" NearbyOrder : alerts
    BengkelBiddingViewModel "1" --> "*" Bid : tracks
    BengkelBiddingViewModel "1" --> "0..1" Bengkel : references
    BengkelRosterViewModel "1" --> "*" RosterMember : manages
    MechanicInviteViewModel "1" --> "*" MechanicInvite : manages
    AssignMechanicViewModel "1" --> "*" AvailableMechanic : displays
    MechanicDashboardViewModel "1" --> "*" NearbyOrder : displays
    MechanicDashboardViewModel "1" --> "0..1" NearbyOrder : tracks
    MechanicJobsViewModel "1" --> "*" NearbyOrder : displays
    ChatViewModel "1" --> "*" ChatMessage : manages
    OrderTrackingViewModel "1" --> "0..1" NearbyOrder : tracks
    BengkelRouteViewModel "1" --> "0..1" NearbyOrder : tracks
    BengkelRouteViewModel "1" *-- "1" RouteLocationStore : owns
    OrderCompletionViewModel "1" --> "0..1" NearbyOrder : tracks
    HistoryViewModel "1" --> "*" NearbyOrder : displays
    HistoryViewModel "1" --> "0..1" NearbyOrder : shows detail of
    HistoryViewModel "1" --> "0..1" NearbyOrder : resumes bidding for
    HistoryViewModel "1" --> "0..1" Bid : tracks
    BengkelHistoryViewModel "1" --> "*" NearbyOrder : displays
    BengkelHistoryViewModel "1" --> "0..1" NearbyOrder : shows detail of
    MechanicHistoryViewModel "1" --> "*" NearbyOrder : displays
    MechanicHistoryViewModel "1" --> "0..1" NearbyOrder : shows detail of
    PaymentViewModel "1" --> "*" Topup : displays
    PaymentViewModel "1" --> "*" Withdrawal : displays
    PaymentViewModel "1" --> "0..1" PaymentTarget : tracks

    %% ============================================================
    %% REPOSITORY / SERVICE -> DTO / MODEL  (returns / sends / uses)
    %% ============================================================
    UserRepository ..> User : returns
    UserRepository ..> ProfileUpdatePayload : sends
    UserRepository ..> ProfileImageUpdatePayload : sends
    UserRepository ..> BankDetailsUpdatePayload : sends
    VehicleRepository ..> Vehicle : returns
    VehicleRepository ..> VehicleUpdatePayload : sends
    BengkelRepository ..> Bengkel : returns
    BengkelRepository ..> BengkelUpdatePayload : sends
    BengkelRepository ..> BengkelServicesUpdatePayload : sends
    OrderRepository ..> NearbyOrder : returns
    OrderRepository ..> ServiceRequestPayload : sends
    OrderRepository ..> CreatedServiceRequest : returns
    OrderRepository ..> AcceptBidParams : sends
    OrderRepository ..> MarkCompletedParams : sends
    OrderRepository ..> RateOrderParams : sends
    OrderRepository ..> OpenDisputeParams : sends
    OrderRepository ..> CancelOrderParams : sends
    OrderRepository ..> StartSearchPayload : sends
    OrderRepository ..> TodaysEarningRow : returns
    BidRepository ..> Bid : returns
    BidRepository ..> BidStatusUpdate : sends
    ChatRepository ..> ChatMessage : returns
    ChatRepository ..> ChatMessagePayload : sends
    MechanicRepository ..> RosterMember : returns
    MechanicRepository ..> MechanicInvite : returns
    MechanicRepository ..> AvailableMechanic : returns
    MechanicRepository ..> InviteMechanicParams : sends
    MechanicRepository ..> RemoveMechanicParams : sends
    MechanicRepository ..> RespondInviteParams : sends
    MechanicRepository ..> AvailableMechanicsParams : sends
    MechanicAssignmentRepository ..> NearbyOrder : returns
    MechanicAssignmentRepository ..> AssignMechanicParams : sends
    OrderLocationRepository ..> OrderLocation : returns
    OrderLocationRepository ..> CustomerLocation : returns
    OrderLocationRepository ..> OrderLocationPayload : sends
    OrderLocationRepository ..> CustomerLocationPayload : sends
    BehaviorReportRepository ..> BehaviorReportPayload : sends
    BehaviorReportRepository ..> ReportedRequestRow : returns
    TopupRepository ..> Topup : returns
    WithdrawalRepository ..> Withdrawal : returns
    WithdrawalRepository ..> RequestWithdrawalParams : sends
    AuthService ..> SignUpRequest : sends
    AuthService ..> AuthServiceError : throws
    LocationService ..> PhotonSearchResponse : decodes
    LocationService ..> PhotonSearchFeature : returns
    PaymentService ..> CreateTopupRequest : sends
    PaymentService ..> CreateTopupResponse : returns
    BiddingService ..> OrdersRequest : sends
    BiddingService ..> OrdersResponse : returns
    BiddingService ..> PlaceBidRequest : sends
    BiddingService ..> PlaceBidResponse : returns
    BiddingService ..> NearbyOrder : returns
    BiddingService ..> Bid : returns
    ChatReadCursor ..> ChatMessage : reads

    %% ============================================================
    %% CROSS-VIEWMODEL SIGNALS  (NotificationCenter keys)
    %% ============================================================
    MechanicDashboardViewModel ..> MechanicNotifications : posts
    MechanicHistoryViewModel ..> MechanicNotifications : observes
    BengkelRouteViewModel ..> MechanicNotifications : observes
```

## How to read it

- **Layer = name suffix / annotation** (no color): `<<enumeration>>`/`<<interface>>` mark Enums/Protocol; `*ViewModel`, `*Repository`, `*Service` name their layer; `*Payload`/`*Params`/`*Request`/`*Response`/`*Row`/`*Update` are DTOs; everything else is a Model. The ELK/adaptive layout naturally clusters nodes that are wired together.
- **The MVVM rule made literal:** every ViewModel reaches the backend only through Repositories and Services (the role-named `-->` arrows are the injected fields) — none touches `supabase.from(...)` directly. The one sanctioned exception is realtime channel setup, which lives inside the ViewModels as `RealtimeChannelV2?` state (no separate class node).
- **`NearbyOrder`** (the `service_requests` row) is the hub entity — bidding, mechanics, tracking, completion, and history all revolve around it. **`AuthService`** is the other ubiquitous node, injected into almost every ViewModel.
- **Arrow directions:** `-->` from a ViewModel = an injected Repository/Service dependency (verb label says what it does: `reads`, `updates`, `places bids via`, …) or, to a Model, the state it holds (`manages`/`displays`/`tracks` with multiplicity from the field type); `..>` into a DTO/Model = that Repository/Service `sends`/`returns` it; `*--` = structural composition (`contains`/`embeds`/`owns`); `..|>` = protocol realization.
- **Two View-layer types are included** because they hold cross-cutting app state even though they live outside `ViewModels/`: `OrderRouteState` (a shared `ObservableObject` in `ContentView.swift` gating the tracking route) and `NetworkMonitor` (the offline-banner publisher). `NearbyMechanic` (decoded by a map card) and `PhotonSearchResponse` (the geocoder envelope) round out the model set.

> **If you want the grouped namespace boxes back** (the version with `namespace Models { ... }` etc.), it only renders under the **default (dagre)** layout — keep the layout on default, don't switch to adaptive/ELK. This flat version is the one to use for adaptive.
