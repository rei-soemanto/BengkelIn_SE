# BengkelIn — Full-App Class Diagram

One comprehensive class diagram of the **entire iOS app's logic layers** (`BengkelIn_SE/`): every Enum, Model, Protocol, DTO, Repository, Service, and ViewModel, wired with their real relationships. **Every member is shown** — this is the unified superset of the per-feature diagrams in [`feature-class-diagrams.md`](feature-class-diagrams.md), so the two stay in lock-step with each other and with the codebase.

SwiftUI `View` structs are intentionally excluded — in a class diagram they would just be ~70 leaf nodes pointing at the ViewModels below. For a per-feature, presentation-friendly breakdown (each renders small and clean), see [`feature-class-diagrams.md`](feature-class-diagrams.md).

> **Layout compatibility:** this diagram is written **without `namespace` blocks on purpose**, so it renders in **both** the default (dagre) layout **and** the "adaptive" / **ELK** layout. The ELK layout engine does **not** support class-diagram `namespace` boxes — using them is what throws an error when you switch layouts. It is rendered in plain **black & white**; the layer of each class is read from its **name suffix / annotation** (see legend), so no color is needed.

**Layers** (identify by class-name suffix / annotation): `<<enumeration>>` = Enum · `<<interface>>` = Protocol · `*ViewModel` = ViewModel · `*Repository` = Repository · `*Service` = Service · `*Payload`/`*Params`/`*Request`/`*Response`/`*Row`/`*Update` = DTO · everything else = Model.

**Members**: `+` = public surface (`@Published` state, computed properties, public methods, `init`/`deinit`) · `-` = private implementation (injected deps are shown as role-named association arrows instead, realtime channels & reader `Task`s, `CLLocationManager`, private helpers) · `$` = static. **Injected Service/Repository dependencies are role-named association arrows (`ViewModel --> AuthService : authService`), not repeated as attributes** — the arrow *is* the field.

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
    Bengkel "1" *-- "*" BengkelService : offers
    BengkelService --> ServiceType
    NearbyMechanic --> "*" BengkelService
    Bid --> "0..1" Bengkel : bengkel
    PhotonSearchResponse "1" *-- "*" PhotonSearchFeature
    PhotonSearchFeature "1" *-- "1" PhotonSearchProperties : properties
    PhotonSearchFeature "1" *-- "1" PhotonSearchGeometry : geometry

    %% ============================================================
    %% PROTOCOL REALIZATION
    %% ============================================================
    BengkelViewModel ..|> LocationSearchable
    OrderViewModel ..|> LocationSearchable

    %% ============================================================
    %% VIEWMODEL -> REPOSITORY / SERVICE WIRING  (injected deps, role-named)
    %% ============================================================
    AuthViewModel --> AuthService : authService
    AuthViewModel --> UserRepository : userRepository
    ProfileViewModel --> AuthService : authService
    ProfileViewModel --> UserRepository : userRepository
    ProfileViewModel --> StorageService : storageService
    ProfileViewModel ..> ImageCompressor
    VehicleViewModel --> AuthService : authService
    VehicleViewModel --> VehicleRepository : vehicleRepository
    BengkelViewModel --> BengkelRepository : bengkelRepository
    BengkelViewModel --> LocationService : locationService
    BengkelViewModel --> OrderRepository : orderRepository
    BengkelViewModel --> MechanicRepository : mechanicRepository
    BengkelViewModel --> AuthService : authService
    OrderViewModel --> OrderRepository : orderRepository
    OrderViewModel --> LocationService : locationService
    OrderViewModel --> StorageService : storageService
    OrderViewModel --> UserRepository : userRepository
    OrderViewModel --> VehicleRepository : vehicleRepository
    OrderViewModel --> AuthService : authService
    CustomerBiddingViewModel --> OrderRepository : orderRepository
    CustomerBiddingViewModel --> BidRepository : bidRepository
    CustomerBiddingViewModel --> UserRepository : userRepository
    CustomerBiddingViewModel --> StorageService : storageService
    CustomerBiddingViewModel --> NotificationService : notificationService
    CustomerBiddingViewModel --> AuthService : authService
    BengkelBiddingViewModel --> OrderRepository : orderRepository
    BengkelBiddingViewModel --> BidRepository : bidRepository
    BengkelBiddingViewModel --> BiddingService : biddingService
    BengkelBiddingViewModel --> BengkelRepository : bengkelRepository
    BengkelBiddingViewModel --> MechanicRepository : mechanicRepository
    BengkelBiddingViewModel --> NotificationService : notificationService
    BengkelBiddingViewModel --> AuthService : authService
    BengkelRosterViewModel --> MechanicRepository : mechanicRepository
    MechanicInviteViewModel --> MechanicRepository : mechanicRepository
    AssignMechanicViewModel --> MechanicRepository : mechanicRepository
    AssignMechanicViewModel --> MechanicAssignmentRepository : assignmentRepository
    MechanicDashboardViewModel --> MechanicAssignmentRepository : assignmentRepository
    MechanicDashboardViewModel --> AuthService : authService
    MechanicDashboardViewModel --> NotificationService : notificationService
    MechanicJobsViewModel --> MechanicAssignmentRepository : assignmentRepository
    MechanicJobsViewModel --> AuthService : authService
    ChatViewModel --> ChatRepository : chatRepository
    ChatViewModel --> OrderRepository : orderRepository
    ChatViewModel --> StorageService : storageService
    ChatViewModel --> AuthService : authService
    ChatViewModel ..> ImageCompressor
    ChatWatchViewModel --> ChatRepository : chatRepository
    ChatWatchViewModel --> NotificationService : notificationService
    ChatWatchViewModel --> AuthService : authService
    ChatWatchViewModel ..> ChatReadCursor
    ChatWatchViewModel ..> ChatPresence
    OrderTrackingViewModel --> OrderLocationRepository : locationRepository
    OrderTrackingViewModel --> OrderRepository : orderRepository
    OrderTrackingViewModel --> NotificationService : notificationService
    LocationPublishViewModel --> OrderLocationRepository : repository
    LocationPublishViewModel --> OrderRepository : orderRepository
    LocationPublishViewModel --> AuthService : authService
    CustomerLocationPublishViewModel --> OrderLocationRepository : repository
    CustomerLocationPublishViewModel --> AuthService : authService
    BengkelRouteViewModel --> OrderRepository : orderRepository
    BengkelRouteViewModel --> BengkelRepository : bengkelRepository
    BengkelRouteViewModel --> OrderLocationRepository : locationRepository
    BengkelRouteViewModel --> StorageService : storageService
    BengkelRouteViewModel --> AuthService : authService
    BengkelRouteViewModel --> NotificationService : notificationService
    OrderCompletionViewModel --> OrderRepository : orderRepository
    OrderCompletionViewModel --> StorageService : storageService
    OrderCompletionViewModel --> AuthService : authService
    OrderCompletionViewModel --> NotificationService : notificationService
    OrderRatingViewModel --> OrderRepository : orderRepository
    HistoryViewModel --> OrderRepository : orderRepository
    HistoryViewModel --> BidRepository : bidRepository
    HistoryViewModel --> BehaviorReportRepository : behaviorReportRepository
    HistoryViewModel --> AuthService : authService
    BengkelHistoryViewModel --> OrderRepository : orderRepository
    BengkelHistoryViewModel --> BengkelRepository : bengkelRepository
    BengkelHistoryViewModel --> BehaviorReportRepository : behaviorReportRepository
    BengkelHistoryViewModel --> AuthService : authService
    MechanicHistoryViewModel --> OrderRepository : orderRepository
    MechanicHistoryViewModel --> BehaviorReportRepository : behaviorReportRepository
    MechanicHistoryViewModel --> AuthService : authService
    PaymentViewModel --> PaymentService : paymentService
    PaymentViewModel --> TopupRepository : topupRepository
    PaymentViewModel --> WithdrawalRepository : withdrawalRepository
    PaymentViewModel --> UserRepository : userRepository
    PaymentViewModel --> AuthService : authService
    BehaviorReportViewModel --> BehaviorReportRepository : repository
    BehaviorReportViewModel --> AuthService : authService

    %% ============================================================
    %% VIEWMODEL -> MODEL  (state held)
    %% ============================================================
    AuthViewModel --> User
    AuthViewModel --> AppMode
    VehicleViewModel --> Vehicle
    BengkelViewModel --> Bengkel
    OrderViewModel --> Vehicle
    OrderViewModel --> LoadingPhase
    CustomerBiddingViewModel --> Bid
    CustomerBiddingViewModel --> LoadingPhase
    BengkelBiddingViewModel --> NearbyOrder
    BengkelRosterViewModel --> RosterMember
    MechanicInviteViewModel --> MechanicInvite
    AssignMechanicViewModel --> AvailableMechanic
    MechanicDashboardViewModel --> NearbyOrder
    MechanicJobsViewModel --> NearbyOrder
    ChatViewModel --> ChatMessage
    OrderTrackingViewModel --> NearbyOrder
    BengkelRouteViewModel "1" *-- "1" RouteLocationStore : locationStore
    OrderCompletionViewModel --> NearbyOrder
    HistoryViewModel --> NearbyOrder
    BengkelHistoryViewModel --> NearbyOrder
    MechanicHistoryViewModel --> NearbyOrder
    PaymentViewModel --> Topup
    PaymentViewModel --> Withdrawal
    PaymentViewModel --> PaymentTarget

    %% ============================================================
    %% REPOSITORY / SERVICE -> DTO / MODEL  (returns / sends / uses)
    %% ============================================================
    UserRepository ..> User
    UserRepository ..> ProfileUpdatePayload
    UserRepository ..> ProfileImageUpdatePayload
    UserRepository ..> BankDetailsUpdatePayload
    VehicleRepository ..> Vehicle
    VehicleRepository ..> VehicleUpdatePayload
    BengkelRepository ..> Bengkel
    BengkelRepository ..> BengkelUpdatePayload
    BengkelRepository ..> BengkelServicesUpdatePayload
    OrderRepository ..> NearbyOrder
    OrderRepository ..> ServiceRequestPayload
    OrderRepository ..> CreatedServiceRequest
    OrderRepository ..> AcceptBidParams
    OrderRepository ..> MarkCompletedParams
    OrderRepository ..> RateOrderParams
    OrderRepository ..> OpenDisputeParams
    OrderRepository ..> CancelOrderParams
    OrderRepository ..> StartSearchPayload
    OrderRepository ..> TodaysEarningRow
    BidRepository ..> Bid
    BidRepository ..> BidStatusUpdate
    ChatRepository ..> ChatMessage
    ChatRepository ..> ChatMessagePayload
    MechanicRepository ..> RosterMember
    MechanicRepository ..> MechanicInvite
    MechanicRepository ..> AvailableMechanic
    MechanicRepository ..> InviteMechanicParams
    MechanicRepository ..> RemoveMechanicParams
    MechanicRepository ..> RespondInviteParams
    MechanicRepository ..> AvailableMechanicsParams
    MechanicAssignmentRepository ..> NearbyOrder
    MechanicAssignmentRepository ..> AssignMechanicParams
    OrderLocationRepository ..> OrderLocation
    OrderLocationRepository ..> CustomerLocation
    OrderLocationRepository ..> OrderLocationPayload
    OrderLocationRepository ..> CustomerLocationPayload
    BehaviorReportRepository ..> BehaviorReportPayload
    BehaviorReportRepository ..> ReportedRequestRow
    TopupRepository ..> Topup
    WithdrawalRepository ..> Withdrawal
    WithdrawalRepository ..> RequestWithdrawalParams
    AuthService ..> SignUpRequest
    AuthService ..> AuthServiceError
    LocationService ..> PhotonSearchFeature
    PaymentService ..> CreateTopupRequest
    PaymentService ..> CreateTopupResponse
    BiddingService ..> OrdersRequest
    BiddingService ..> OrdersResponse
    BiddingService ..> PlaceBidRequest
    BiddingService ..> PlaceBidResponse
    BiddingService ..> NearbyOrder
```

## How to read it

- **Layer = name suffix / annotation** (no color): `<<enumeration>>`/`<<interface>>` mark Enums/Protocol; `*ViewModel`, `*Repository`, `*Service` name their layer; `*Payload`/`*Params`/`*Request`/`*Response`/`*Row`/`*Update` are DTOs; everything else is a Model. The ELK/adaptive layout naturally clusters nodes that are wired together.
- **The MVVM rule made literal:** every ViewModel reaches the backend only through Repositories and Services (the role-named `-->` arrows are the injected fields) — none touches `supabase.from(...)` directly. The one sanctioned exception is realtime channel setup, which lives inside the ViewModels as `RealtimeChannelV2?` state (no separate class node).
- **`NearbyOrder`** (the `service_requests` row) is the hub entity — bidding, mechanics, tracking, completion, and history all revolve around it. **`AuthService`** is the other ubiquitous node, injected into almost every ViewModel.
- **Arrow directions:** `-->  : role` from a ViewModel = an injected Repository/Service dependency (or, to a Model, the state it holds); `..>` into a DTO/Model = that Repository/Service returns or sends it; `*--` between Models = structural composition; `..|>` = protocol realization.
- **Two View-layer types are included** because they hold cross-cutting app state even though they live outside `ViewModels/`: `OrderRouteState` (a shared `ObservableObject` in `ContentView.swift` gating the tracking route) and `NetworkMonitor` (the offline-banner publisher). `NearbyMechanic` (decoded by a map card) and `PhotonSearchResponse` (the geocoder envelope) round out the model set.

> **If you want the grouped namespace boxes back** (the version with `namespace Models { ... }` etc.), it only renders under the **default (dagre)** layout — keep the layout on default, don't switch to adaptive/ELK. This flat version is the one to use for adaptive.
