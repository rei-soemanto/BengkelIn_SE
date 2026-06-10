# BengkelIn — Full-App Class Diagram

One comprehensive class diagram of the **entire iOS app's logic layers** (`BengkelIn_SE/`): every Enum, Model, Protocol, DTO, Repository, Service, and ViewModel, wired with their real relationships.

SwiftUI `View` structs are intentionally excluded — in a class diagram they would just be ~70 leaf nodes pointing at the ViewModels below. For a per-feature, presentation-friendly breakdown (each renders small and clean), see [`feature-class-diagrams.md`](feature-class-diagrams.md).

> **Layout compatibility:** this diagram is written **without `namespace` blocks on purpose**, so it renders in **both** the default (dagre) layout **and** the "adaptive" / **ELK** layout. The ELK layout engine does **not** support class-diagram `namespace` boxes — using them is what throws an error when you switch layouts. It is rendered in plain **black & white**; the layer of each class is read from its **name suffix / annotation** (see legend), so no color is needed.

**Layers** (identify by class-name suffix / annotation): `<<enumeration>>` = Enum · `<<interface>>` = Protocol · `*ViewModel` = ViewModel · `*Repository` = Repository · `*Service` = Service · `*Payload`/`*Params`/`*Request`/`*Response`/`*Row`/`*Update` = DTO · everything else = Model.

**Arrows**: `..>` depends on / uses · `-->` association · `*--` composition · `..|>` realizes interface.

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

    %% ============================================================
    %% MODELS (domain entities)
    %% ============================================================
    class User {
        +String id
        +String name
        +String? profileImageUrl
        +Double balance
        +Double? heldBalance
        +Double? pendingBalance
        +String? email
        +String? phoneNumber
        +String role
        +String? bankName
        +String? bankAccountNumber
        +String? bankAccountName
        +Int? points
        +Int? pendingPoints
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
        +String serviceRequestId
        +String? providerUid
        +Double latitude
        +Double longitude
        +String? updatedAt
        +String id
    }
    class CustomerLocation {
        +String serviceRequestId
        +String? customerId
        +Double latitude
        +Double longitude
        +String? updatedAt
        +String id
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
    class IndonesianBank {
        +String id
        +String name
        +Int[] accountLengths
        +IndonesianBank[] all$
        +named(name) IndonesianBank$
        +isValidAccountNumber(acct) Bool
    }
    class PhotonSearchResponse {
        +PhotonSearchFeature[] features
    }
    class PhotonSearchFeature {
        +UUID id
        +PhotonSearchProperties properties
        +PhotonSearchGeometry geometry
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
    class OpenDisputeParams {
        +String p_request_id
        +String p_reason
        +String? p_proof_url
    }
    class RateOrderParams {
        +String p_request_id
        +Int p_rating
    }
    class MarkCompletedParams {
        +String p_request_id
        +String? p_completion_photo_url
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
    class ChatMessagePayload {
        +String service_request_id
        +String sender_id
        +String? content
        +String? image_url
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
    class BankDetailsUpdatePayload {
        +String bank_name
        +String bank_account_number
        +String bank_account_name
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
        +deleteOrder(id)
        +updateOrderPrice(id, price)
        +cancelOrder(id)
        +acceptBid(bidId) NearbyOrder
        +submitRating(requestId, rating)
        +markOrderCompleted(requestId, url) NearbyOrder
        +openDispute(requestId, reason, url) NearbyOrder
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
    %% SERVICES  (Auth SDK / Storage / external APIs / system)
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
    class ChatReadCursor {
        +String serviceRequestId
        +Date lastReadAt
        +markRead(at)
        +unreadCount(incoming) Int
    }
    class ChatPresence {
        +String? activeServiceRequestId
    }
    class ImageCompressor {
        +compressed(data, maxDim, quality) Data$
    }

    %% ============================================================
    %% VIEWMODELS  (ObservableObject, @MainActor)
    %% ============================================================
 motel
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
    class VehicleViewModel {
        +Vehicle[] userVehicles
        +Bool isLoading
        +String? errorMessage
        +fetchVehicles()
        +addVehicle(...) Bool
        +updateVehicle(...) Bool
        +deleteVehicle(id) Bool
    }
    class BengkelViewModel {
        +Bengkel? myBengkel
        +Double todaysEarnings
        +Bool hasAcceptedMechanic
        +String locationAddress
        +PhotonSearchFeature[] searchResults
        +MKCoordinateRegion region
        +registerBengkel(name, address) Bool
        +updateBengkel(id, name, address) Bool
        +addService(id, type, active) Bool
    }
    class BengkelBiddingViewModel {
        +NearbyOrder[] orders
        +Bengkel? myBengkel
        +Bid[] myPendingBids
        +NearbyOrder? newOrderAlert
        +Bool hasMechanics
        +start()
        +loadOrders()
        +placeBid(order, price, notes)
    }
    class BengkelHistoryViewModel {
        +NearbyOrder[] orders
        +NearbyOrder? detailOrder
        +Set~String~ reportedOrderIds
        +loadOrders()
        +select(order)
        +markReported(orderId)
    }
    class BengkelRouteViewModel {
        +NearbyOrder? order
        +String? myUid
        +Bool reassignedAway
        +start(order)
        +refreshOrder()
        +reportIssue(reason, photo) Bool
    }
    class AssignMechanicViewModel {
        +AvailableMechanic[] availableMechanics
        +Bool isAssigning
        +fetchAvailableMechanics(reqId)
        +assign(reqId, mechanicId) Bool
    }
    class BengkelRosterViewModel {
        +RosterMember[] roster
        +String inviteEmail
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
    class MechanicHistoryViewModel {
        +NearbyOrder[] orders
        +NearbyOrder? detailOrder
        +Set~String~ reportedOrderIds
        +loadOrders()
        +select(order)
        +markReported(orderId)
    }
    class OrderViewModel {
        +String locationAddress
        +String? selectedService
        +Int estimatedPrice
        +Int tireCount
        +Data?[] photosData
        +Vehicle[] vehicles
        +String? selectedVehicleId
        +Bool usePoints
        +Int availablePoints
        +Bool navigateToBidding
        +MKCoordinateRegion region
        +loadVehicles()
        +createOrder()
        +beginOrder(usePoints)
    }
    class CustomerBiddingViewModel {
        +Bid[] bids
        +Bid? acceptedBid
        +Int minPrice
        +Int customerBidPrice
        +Bool isSearching
        +Int searchSecondsRemaining
        +startSearch(price)
        +acceptBid(bid)
        +rejectBid(bid)
    }
    class CustomerLocationPublishViewModel {
        +Bool isPublishing
        +CLLocationCoordinate2D? currentCoordinate
        +start(reqId)
        +stop()
    }
    class LocationPublishViewModel {
        +Bool isPublishing
        +String? errorMessage
        +start(reqId, coordinate)
        +stop()
    }
    class OrderTrackingViewModel {
        +CLLocationCoordinate2D? providerCoordinate
        +NearbyOrder? order
        +Bool isLive
        +start(reqId)
        +openDispute(reason) Bool
    }
    class OrderCompletionViewModel {
        +NearbyOrder? order
        +Bool isLoading
        +start()
        +markCompleted(photo)
    }
    class OrderRatingViewModel {
        +Bool isSubmitting
        +String? errorMessage
        +submit(reqId, rating) Bool
    }
    class ChatViewModel {
        +ChatMessage[] messages
        +String draft
        +Bool isLocked
        +start()
        +sendText()
        +sendImage(data)
    }
    class ChatWatchViewModel {
        +Int unreadCount
        +start()
        +markAllRead()
    }
    class HistoryViewModel {
        +NearbyOrder[] orders
        +NearbyOrder? detailOrder
        +Bid? trackingBid
        +loadOrders()
        +select(order)
        +markReported(orderId)
    }
    class PaymentViewModel {
        +Double balance
        +Double heldBalance
        +Int points
        +Topup[] topups
        +Withdrawal[] withdrawals
        +start()
        +startTopup(amount)
        +saveBankDetails(...) Bool
        +requestWithdrawal(amount) Bool
    }
    class BehaviorReportViewModel {
        +Bool isSubmitting
        +String? errorMessage
        +submit(reqId, reason) Bool
    }

    %% ViewModel-layer helper state (ObservableObject stores / routing state)
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
        +enter(id)
        +leave(id)
    }

    %% ============================================================
    %% MODEL STRUCTURAL RELATIONSHIPS
    %% ============================================================
    Bengkel "1" *-- "*" BengkelService : offers
    BengkelService --> ServiceType
    NearbyMechanic --> "*" BengkelService
    Bid --> "0..1" Bengkel : bengkel
    PhotonSearchResponse "1" *-- "*" PhotonSearchFeature
    PhotonSearchFeature *-- PhotonSearchProperties
    PhotonSearchFeature *-- PhotonSearchGeometry

    %% ============================================================
    %% PROTOCOL REALIZATION
    %% ============================================================
    BengkelViewModel ..|> LocationSearchable
    OrderViewModel ..|> LocationSearchable

    %% ============================================================
    %% VIEWMODEL -> REPOSITORY / SERVICE WIRING
    %% ============================================================
    AuthViewModel ..> AuthService
    AuthViewModel ..> UserRepository
    ProfileViewModel ..> AuthService
    ProfileViewModel ..> UserRepository
    ProfileViewModel ..> StorageService
    VehicleViewModel ..> AuthService
    VehicleViewModel ..> VehicleRepository
    BengkelViewModel ..> AuthService
    BengkelViewModel ..> BengkelRepository
    BengkelViewModel ..> OrderRepository
    BengkelViewModel ..> MechanicRepository
    BengkelViewModel ..> LocationService
    BengkelBiddingViewModel ..> OrderRepository
    BengkelBiddingViewModel ..> BengkelRepository
    BengkelBiddingViewModel ..> BidRepository
    BengkelBiddingViewModel ..> BiddingService
    BengkelBiddingViewModel ..> MechanicRepository
    BengkelBiddingViewModel ..> NotificationService
    BengkelBiddingViewModel ..> AuthService
    BengkelHistoryViewModel ..> BengkelRepository
    BengkelHistoryViewModel ..> OrderRepository
    BengkelHistoryViewModel ..> BehaviorReportRepository
    BengkelHistoryViewModel ..> AuthService
    BengkelRouteViewModel ..> OrderRepository
    BengkelRouteViewModel ..> BengkelRepository
    BengkelRouteViewModel ..> StorageService
    BengkelRouteViewModel ..> OrderLocationRepository
    BengkelRouteViewModel ..> AuthService
    BengkelRouteViewModel ..> NotificationService
    AssignMechanicViewModel ..> MechanicRepository
    AssignMechanicViewModel ..> MechanicAssignmentRepository
    BengkelRosterViewModel ..> MechanicRepository
    MechanicInviteViewModel ..> MechanicRepository
    MechanicDashboardViewModel ..> MechanicAssignmentRepository
    MechanicDashboardViewModel ..> AuthService
    MechanicDashboardViewModel ..> NotificationService
    MechanicJobsViewModel ..> MechanicAssignmentRepository
    MechanicJobsViewModel ..> AuthService
    MechanicHistoryViewModel ..> OrderRepository
    MechanicHistoryViewModel ..> BehaviorReportRepository
    MechanicHistoryViewModel ..> AuthService
    OrderViewModel ..> AuthService
    OrderViewModel ..> LocationService
    OrderViewModel ..> OrderRepository
    OrderViewModel ..> StorageService
    OrderViewModel ..> UserRepository
    OrderViewModel ..> VehicleRepository
    CustomerBiddingViewModel ..> AuthService
    CustomerBiddingViewModel ..> UserRepository
    CustomerBiddingViewModel ..> OrderRepository
    CustomerBiddingViewModel ..> BidRepository
    CustomerBiddingViewModel ..> StorageService
    CustomerBiddingViewModel ..> NotificationService
    CustomerLocationPublishViewModel ..> OrderLocationRepository
    CustomerLocationPublishViewModel ..> AuthService
    LocationPublishViewModel ..> OrderLocationRepository
    LocationPublishViewModel ..> AuthService
    LocationPublishViewModel ..> OrderRepository
    OrderTrackingViewModel ..> OrderLocationRepository
    OrderTrackingViewModel ..> OrderRepository
    OrderTrackingViewModel ..> NotificationService
    OrderCompletionViewModel ..> AuthService
    OrderCompletionViewModel ..> OrderRepository
    OrderCompletionViewModel ..> StorageService
    OrderCompletionViewModel ..> NotificationService
    OrderRatingViewModel ..> OrderRepository
    ChatViewModel ..> ChatRepository
    ChatViewModel ..> OrderRepository
    ChatViewModel ..> StorageService
    ChatViewModel ..> AuthService
    ChatWatchViewModel ..> ChatRepository
    ChatWatchViewModel ..> NotificationService
    ChatWatchViewModel ..> AuthService
    HistoryViewModel ..> AuthService
    HistoryViewModel ..> OrderRepository
    HistoryViewModel ..> BidRepository
    HistoryViewModel ..> BehaviorReportRepository
    PaymentViewModel ..> AuthService
    PaymentViewModel ..> UserRepository
    PaymentViewModel ..> TopupRepository
    PaymentViewModel ..> WithdrawalRepository
    PaymentViewModel ..> PaymentService
    BehaviorReportViewModel ..> BehaviorReportRepository
    BehaviorReportViewModel ..> AuthService
    ChatWatchViewModel ..> ChatReadCursor
    ChatWatchViewModel ..> ChatPresence
    ChatViewModel ..> ImageCompressor
    ProfileViewModel ..> ImageCompressor

    %% ============================================================
    %% VIEWMODEL -> MODEL  (association)
    %% ============================================================
    AuthViewModel --> User
    AuthViewModel --> AppMode
    VehicleViewModel --> Vehicle
    BengkelViewModel --> Bengkel
    BengkelBiddingViewModel --> NearbyOrder
    CustomerBiddingViewModel --> Bid
    OrderCompletionViewModel --> NearbyOrder
    HistoryViewModel --> NearbyOrder
    ChatViewModel --> ChatMessage
    PaymentViewModel --> Topup
    PaymentViewModel --> Withdrawal
    PaymentViewModel --> PaymentTarget
    BengkelRouteViewModel *-- RouteLocationStore : locationStore

    %% ============================================================
    %% REPOSITORY / SERVICE -> DTO / MODEL  (returns / uses)
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

- **Layer = name suffix / annotation** (no color): `<<enumeration>>`/`<<interface>>` mark Enums/Protocol; `*ViewModel`, `*Repository`, `*Service` name their layer; `*Payload`/`*Params`/`*Request`/`*Response`/`*Row` are DTOs; everything else is a Model. The ELK/adaptive layout naturally clusters nodes that are wired together.
- **The MVVM rule made literal:** every ViewModel depends only on Repositories and Services (`..>`) — none reaches Supabase directly (the only sanctioned exception is realtime channel setup, which has no class node here).
- **`NearbyOrder`** (the `service_requests` row) is the hub entity — bidding, mechanics, tracking, completion, and history all revolve around it.
- **Arrow directions:** `..>` from a ViewModel = a Repository/Service dependency; `..>` into a DTO/Model = that Repository/Service returns or sends it; `-->` from a ViewModel to a Model = the state it holds; `*--`/`-->` between Models = structural composition/association. Business behavior lives in the ViewModel/Repository/Service layers.

> **If you ever want the grouped namespace boxes back** (the version with `namespace Models { ... }` etc.), it only renders under the **default (dagre)** layout — keep the layout on default, don't switch to adaptive/ELK. This flat version is the one to use for adaptive.
