//
//  BengkelViewModel.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI
import Combine
import CoreLocation
import MapKit
import Supabase

// MARK: - Lightweight Display Type

/// A joined view of a service request with its related customer and vehicle info,
/// used for the provider dashboard "Incoming Requests" display.
struct IncomingRequestDisplay: Identifiable {
    let id: String
    let serviceType: String
    let isEmergency: Bool
    let status: ServiceRequestStatus
    let location: String?
    let estimatedPrice: Double?
    let createdAt: Date?
}

@MainActor
class BengkelViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, LocationSearchable {

    // MARK: - Published State

    @Published var myBengkel: Bengkel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Provider job state (live — from service_requests table)
    @Published var pendingRequests: [ServiceRequest] = []
    @Published var activeServiceRequests: [ServiceRequest] = []
    @Published var todaysEarnings: Double = 0.0

    // Team management
    @Published var teamMembers: [User] = []
    @Published var availableMechanics: [Mechanic] = []
    @Published var sentInvitations: [MechanicInvitation] = []
    @Published var pendingResignations: [MechanicResignation] = []

    // Voucher / promo management
    @Published var providerVouchers: [Voucher] = []

    // MARK: - Location / Map State (LocationSearchable)

    @Published var locationAddress: String = ""
    @Published var isEditingLocation: Bool = false
    @Published var isFetchingLocation: Bool = false
    @Published var searchResults: [PhotonSearchFeature] = []
    @Published var region = MKCoordinateRegion(
        // Default to Surabaya, Indonesia
        center: CLLocationCoordinate2D(latitude: -7.2575, longitude: 112.7521),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var pendingRequestsCount: Int { pendingRequests.count }
    var hasActiveJob: Bool { !activeServiceRequests.isEmpty }

    // MARK: - Dependencies

    private let authService = AuthService()
    private let bengkelRepository = BengkelRepository()
    private let userRepository = UserRepository()
    private let serviceRequestRepository = ServiceRequestRepository()
    private let invitationRepository = MechanicInvitationRepository()
    private let resignationRepository = MechanicResignationRepository()
    private let voucherRepository = VoucherRepository()
    private let locationService = LocationService()
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        // Debounced search — only fires while the user is editing the address field.
        $locationAddress
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                guard self.isEditingLocation else { return }
                Task { await self.performSearch(query: query) }
            }
            .store(in: &cancellables)
    }

    // ──────────────────────────────────────────────────────
    // MARK: - LocationSearchable
    // ──────────────────────────────────────────────────────

    func useCurrentLocation() {
        isFetchingLocation = true
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            isFetchingLocation = false
            errorMessage = "Location access denied. Enable it in Settings to use this feature."
        @unknown default:
            isFetchingLocation = false
        }
    }

    func selectSearchResult(_ result: PhotonSearchFeature) {
        let coord = CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude)
        region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        locationAddress = result.displayName
        searchResults = []
        isEditingLocation = false
    }

    func updateLocationFromMap(coordinate: CLLocationCoordinate2D) {
        isFetchingLocation = true
        Task {
            do {
                if let address = try await locationService.fetchAddress(from: coordinate) {
                    self.locationAddress = address
                }
            } catch {
                print("[BengkelVM] reverse geocode error: \(error)")
            }
            self.isFetchingLocation = false
        }
    }

    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.searchResults = []
            return
        }
        do {
            let results = try await locationService.searchOSM(query: trimmed, coordinate: region.center)
            self.searchResults = results
        } catch {
            print("[BengkelVM] Photon search error: \(error)")
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.isFetchingLocation = false
                self.errorMessage = "Location access denied. Enable it in Settings to use this feature."
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        let coord = location.coordinate
        Task { @MainActor in
            self.region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            do {
                if let address = try await self.locationService.fetchAddress(from: coord) {
                    self.locationAddress = address
                }
            } catch {
                print("[BengkelVM] reverse geocode after GPS error: \(error)")
            }
            self.isFetchingLocation = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isFetchingLocation = false
            self.errorMessage = "Failed to determine current location: \(error.localizedDescription)"
        }
    }

    // ──────────────────────────────────────────────────────
    // MARK: - Service Requests (Provider Dashboard)
    // ──────────────────────────────────────────────────────

    func fetchServiceRequests(bengkelId: String) async {
        do {
            let requests = try await serviceRequestRepository.fetchOpenByBengkel(bengkelId: bengkelId)
            self.pendingRequests = requests.filter { $0.status == .pending }
            self.activeServiceRequests = requests.filter {
                $0.status == .accepted || $0.status == .inProgress
            }
        } catch {
            self.errorMessage = "Failed to load service requests: \(error.localizedDescription)"
            print("[BengkelVM] fetchServiceRequests error: \(error)")
        }
    }

    func fetchTodaysEarnings(bengkelId: String) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let startStr = isoFormatter.string(from: startOfDay)

        do {
            let completed = try await serviceRequestRepository.fetchCompletedSince(
                bengkelId: bengkelId,
                sinceIso: startStr
            )
            self.todaysEarnings = completed.compactMap(\.estimatedPrice).reduce(0, +)
        } catch {
            print("[BengkelVM] fetchTodaysEarnings error: \(error)")
        }
    }

    func acceptJob(requestId: String) async {
        isLoading = true
        errorMessage = nil

        let payload = makeStatusUpdate(newStatus: .accepted)

        do {
            try await serviceRequestRepository.updateStatus(requestId: requestId, payload: payload)
            withAnimation {
                if let idx = pendingRequests.firstIndex(where: { $0.id == requestId }) {
                    var accepted = pendingRequests.remove(at: idx)
                    accepted.status = .accepted
                    self.activeServiceRequests.append(accepted)
                }
            }
            self.successMessage = "Job accepted! Customer has been notified."
        } catch {
            self.errorMessage = "Failed to accept job: \(error.localizedDescription)"
            print("[BengkelVM] acceptJob error: \(error)")
        }
        isLoading = false
    }

    func finishJob(requestId: String) async {
        isLoading = true
        errorMessage = nil

        let payload = makeStatusUpdate(newStatus: .completed)

        do {
            try await serviceRequestRepository.updateStatus(requestId: requestId, payload: payload)
            withAnimation {
                let price = self.activeServiceRequests.first(where: { $0.id == requestId })?.estimatedPrice ?? 0
                self.todaysEarnings += price
                self.activeServiceRequests.removeAll { $0.id == requestId }
            }
            self.successMessage = "Job completed! Earnings updated."
        } catch {
            self.errorMessage = "Failed to complete job: \(error.localizedDescription)"
            print("[BengkelVM] finishJob error: \(error)")
        }
        isLoading = false
    }

    func dispatchMechanic(requestId: String, mechanicId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        var payload = makeStatusUpdate(newStatus: .accepted)
        payload.mechanicId = mechanicId

        do {
            try await serviceRequestRepository.updateStatus(requestId: requestId, payload: payload)
            self.successMessage = "Mechanic successfully dispatched!"
            isLoading = false
            return true
        } catch {
            self.errorMessage = "Dispatch failed: \(error.localizedDescription)"
            print("[BengkelVM] dispatchMechanic error: \(error)")
            isLoading = false
            return false
        }
    }

    private func makeStatusUpdate(newStatus: ServiceRequestStatus, notes: String? = nil) -> ServiceRequestStatusUpdate {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ServiceRequestStatusUpdate(
            status: newStatus.rawValue,
            mechanicNotes: notes,
            updatedAt: isoFormatter.string(from: Date())
        )
    }

    // ──────────────────────────────────────────────────────
    // MARK: - Bengkel Lifecycle (Register / Fetch / Update / Delete)
    // ──────────────────────────────────────────────────────

    /// Registers a new bengkel. The address comes from the user-entered string while the
    /// coordinates come from `region.center` (set by the map/search picker).
    func registerBengkel(name: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        guard let session = try? await authService.getCurrentSession() else {
            self.errorMessage = "You must be logged in to register a Bengkel."
            isLoading = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()

        let address = locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            self.errorMessage = "Please pick a location on the map."
            isLoading = false
            return false
        }

        let newBengkel = Bengkel(
            id: nil,
            providerUid: uid,
            name: name,
            address: address,
            latitude: region.center.latitude,
            longitude: region.center.longitude,
            status: "Pending",
            offeredServices: [],
            averageRating: 0.0,
            totalReviews: 0,
            createdAt: nil
        )

        do {
            try await bengkelRepository.insertBengkel(newBengkel)
            self.successMessage = "Bengkel submitted for review! You will be notified once approved."
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func fetchMyBengkel(uid: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await bengkelRepository.fetchBengkel(providerUid: uid)
            self.myBengkel = fetched
        } catch {
            self.errorMessage = "Failed to load Bengkel: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Updates an existing bengkel. Address + coordinates come from `locationAddress` + `region.center`.
    func updateBengkel(bengkelId: String, name: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        let address = locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            self.errorMessage = "Please pick a location on the map."
            isLoading = false
            return false
        }

        let payload = BengkelUpdatePayload(
            name: name,
            address: address,
            latitude: region.center.latitude,
            longitude: region.center.longitude
        )

        do {
            try await bengkelRepository.updateBengkel(bengkelId: bengkelId, payload: payload)
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func deleteBengkel(bengkelId: String, password: String, email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await authService.signIn(email: email, password: password)
            try await bengkelRepository.deleteBengkel(bengkelId: bengkelId)
            self.myBengkel = nil
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // ──────────────────────────────────────────────────────
    // MARK: - Offered Services CRUD
    // ──────────────────────────────────────────────────────

    func addService(bengkelId: String, serviceType: ServiceType, isActive: Bool) async -> Bool {
        isLoading = true
        errorMessage = nil

        guard var currentBengkel = self.myBengkel else {
            self.errorMessage = "Bengkel data not found."
            isLoading = false
            return false
        }

        let newService = BengkelService(serviceType: serviceType, isActive: isActive)
        if currentBengkel.offeredServices == nil {
            currentBengkel.offeredServices = []
        }
        currentBengkel.offeredServices?.append(newService)

        do {
            try await bengkelRepository.saveBengkel(bengkelId: bengkelId, bengkel: currentBengkel)
            self.myBengkel = currentBengkel
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func updateService(bengkelId: String, serviceId: String, serviceType: ServiceType, isActive: Bool) async -> Bool {
        isLoading = true
        errorMessage = nil

        guard var currentBengkel = self.myBengkel else { return false }

        if let index = currentBengkel.offeredServices?.firstIndex(where: { $0.id == serviceId }) {
            currentBengkel.offeredServices?[index].serviceType = serviceType
            currentBengkel.offeredServices?[index].isActive = isActive

            do {
                try await bengkelRepository.saveBengkel(bengkelId: bengkelId, bengkel: currentBengkel)
                self.myBengkel = currentBengkel
                isLoading = false
                return true
            } catch {
                self.errorMessage = error.localizedDescription
                isLoading = false
                return false
            }
        }

        isLoading = false
        return true
    }

    func deleteService(bengkelId: String, serviceId: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        guard var currentBengkel = self.myBengkel else { return false }
        currentBengkel.offeredServices?.removeAll { $0.id == serviceId }

        do {
            try await bengkelRepository.saveBengkel(bengkelId: bengkelId, bengkel: currentBengkel)
            self.myBengkel = currentBengkel
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // ──────────────────────────────────────────────────────
    // MARK: - Mechanic Roster
    // ──────────────────────────────────────────────────────

    func fetchTeamProfiles() async {
        do {
            guard let uids = self.myBengkel?.mechanicUids, !uids.isEmpty else {
                self.teamMembers = []
                self.availableMechanics = []
                return
            }

            let users = try await userRepository.fetchUsers(uids: uids)
            self.teamMembers = users
            self.availableMechanics = users.map {
                Mechanic(
                    id: $0.id,
                    name: $0.name,
                    email: $0.email ?? "",
                    status: .available,
                    linkedBengkelId: self.myBengkel?.id ?? ""
                )
            }
        } catch {
            print("[BengkelVM] fetchTeamProfiles error: \(error)")
        }
    }

    func fetchMechanics(bengkelId: String) async {
        await fetchTeamProfiles()
    }

    func assignMechanic(to orderId: String, mechanicId: String) {
        print("[BengkelVM] assignMechanic called — order: \(orderId), mechanic: \(mechanicId)")

        if let index = availableMechanics.firstIndex(where: { $0.id == mechanicId }) {
            withAnimation(.easeInOut) {
                availableMechanics[index].status = .busy
            }
            successMessage = "Mechanic assigned successfully!"
        } else {
            errorMessage = "Mechanic not found."
        }
    }

    // ──────────────────────────────────────────────────────
    // MARK: - Mechanic Invitations (Email-Based Flow)
    // ──────────────────────────────────────────────────────

    func inviteMechanic(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        guard let currentBengkel = self.myBengkel, let bengkelId = currentBengkel.id else {
            self.errorMessage = "Bengkel data not found."
            isLoading = false
            return false
        }

        let resolvedUserId: String
        let resolvedUserName: String
        do {
            guard let found = try await userRepository.lookupByEmail(email) else {
                self.errorMessage = "User must create a BengkelIn account first."
                isLoading = false
                return false
            }
            resolvedUserId = found.user_id
            resolvedUserName = found.user_name
        } catch {
            self.errorMessage = "Failed to look up user: \(error.localizedDescription)"
            print("[BengkelVM] RPC get_user_by_email error: \(error)")
            isLoading = false
            return false
        }

        let existingUids = currentBengkel.mechanicUids ?? []
        if existingUids.contains(resolvedUserId) {
            self.errorMessage = "\(resolvedUserName) is already a mechanic at your bengkel."
            isLoading = false
            return false
        }

        do {
            let existing = try await invitationRepository.fetchPending(
                bengkelId: bengkelId,
                mechanicId: resolvedUserId
            )
            if !existing.isEmpty {
                self.errorMessage = "An invitation is already pending for \(resolvedUserName)."
                isLoading = false
                return false
            }
        } catch {
            print("[BengkelVM] Duplicate invite check error: \(error)")
        }

        do {
            let payload = MechanicInvitationInsert(
                bengkelId: bengkelId,
                mechanicId: resolvedUserId,
                status: InvitationStatus.pending.rawValue
            )
            try await invitationRepository.insertInvitation(payload)

            self.successMessage = "Invitation sent to \(resolvedUserName)!"
            await fetchSentInvitations(bengkelId: bengkelId)

            isLoading = false
            return true
        } catch {
            self.errorMessage = "Failed to send invitation: \(error.localizedDescription)"
            print("[BengkelVM] insert mechanic_invitations error: \(error)")
            isLoading = false
            return false
        }
    }

    func fetchSentInvitations(bengkelId: String) async {
        do {
            let invites = try await invitationRepository.fetchSentByBengkel(bengkelId: bengkelId)
            self.sentInvitations = invites
        } catch {
            print("[BengkelVM] fetchSentInvitations error: \(error)")
        }
    }

    // ──────────────────────────────────────────────────────
    // MARK: - Resignation Requests
    // ──────────────────────────────────────────────────────

    func fetchPendingResignations(bengkelId: String) async {
        do {
            let resignations = try await resignationRepository.fetchPendingForBengkel(bengkelId: bengkelId)
            self.pendingResignations = resignations
        } catch {
            print("[BengkelVM] fetchPendingResignations error: \(error)")
        }
    }

    func approveResignation(resignationId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            try await resignationRepository.approveResignationRPC(resignationId: resignationId)
            self.successMessage = "Resignation approved. Mechanic has been removed."

            await fetchTeamProfiles()
            if let bengkelId = myBengkel?.id {
                await fetchPendingResignations(bengkelId: bengkelId)
            }

            isLoading = false
            return true
        } catch {
            self.errorMessage = "Failed to approve resignation: \(error.localizedDescription)"
            print("[BengkelVM] approveResignation error: \(error)")
            isLoading = false
            return false
        }
    }

    // ──────────────────────────────────────────────────────
    // MARK: - Voucher / Promo Management
    // ──────────────────────────────────────────────────────

    func fetchProviderPromos() async {
        guard let session = try? await authService.getCurrentSession() else { return }
        let uid = session.user.id.uuidString.lowercased()

        do {
            let fetched = try await voucherRepository.fetchProviderVouchers(providerUid: uid)
            self.providerVouchers = fetched
        } catch {
            print("[BengkelVM] fetchProviderPromos error: \(error)")
        }
    }

    func createPromo(code: String, title: String, discount: Double, validUntil: Date) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        guard let session = try? await authService.getCurrentSession() else {
            self.errorMessage = "Not logged in."
            isLoading = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let dateStr = isoFormatter.string(from: validUntil)

        let payload = VoucherInsertPayload(
            code: code,
            title: title,
            discountAmount: discount,
            validUntil: dateStr,
            providerUid: uid
        )

        do {
            try await voucherRepository.insertVoucher(payload)
            self.successMessage = "Promo created successfully!"
            await fetchProviderPromos()
            isLoading = false
            return true
        } catch {
            self.errorMessage = "Failed to create promo: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
}
