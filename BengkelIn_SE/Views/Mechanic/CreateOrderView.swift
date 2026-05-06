//
//  CreateOrderView.swift
//  BengkelIn_SE
//
//  Customer Order Flow: Select Vehicle, Select Bengkel, Create Request.
//

import SwiftUI

struct CreateOrderView: View {
    @StateObject private var mechanicVM = MechanicViewModel()
    @StateObject private var vehicleVM = VehicleViewModel()
    
    @Environment(\.dismiss) var dismiss
    
    // Form State
    @State private var selectedVehicleId: String = ""
    @State private var selectedBengkelId: String = ""
    @State private var serviceType: String = ""
    @State private var description: String = ""
    @State private var location: String = ""
    @State private var isEmergency: Bool = false
    
    // Navigation State
    @State private var navigateToWaiting = false
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Vehicle Selection
                Section(header: Text("Your Vehicle")) {
                    if vehicleVM.userVehicles.isEmpty {
                        Text("Loading vehicles or none available...")
                            .foregroundColor(.gray)
                    } else {
                        Picker("Select Vehicle", selection: $selectedVehicleId) {
                            Text("Select a vehicle").tag("")
                            ForEach(vehicleVM.userVehicles) { vehicle in
                                Text("\(vehicle.manufacturer) \(vehicle.model) (\(vehicle.licensePlate))")
                                    .tag(vehicle.id ?? "")
                            }
                        }
                    }
                }
                
                // MARK: - Bengkel Selection
                Section(header: Text("Choose Bengkel")) {
                    if mechanicVM.isFetchingBengkels {
                        ProgressView("Fetching available bengkels...")
                    } else if mechanicVM.availableBengkels.isEmpty {
                        Text("No verified bengkels found nearby.")
                            .foregroundColor(.gray)
                    } else {
                        Picker("Select Bengkel", selection: $selectedBengkelId) {
                            Text("Select a bengkel").tag("")
                            ForEach(mechanicVM.availableBengkels) { bengkel in
                                Text("\(bengkel.name) ⭐️\(String(format: "%.1f", bengkel.averageRating ?? 0.0))")
                                    .tag(bengkel.id ?? "")
                            }
                        }
                    }
                }
                
                // MARK: - Request Details
                Section(header: Text("Service Details")) {
                    TextField("Service Type (e.g. Flat Tire)", text: $serviceType)
                    TextField("Current Location", text: $location)
                    
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Describe the problem...")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                    }
                    
                    Toggle("Emergency (Roadside Assistance)", isOn: $isEmergency)
                        .tint(.red)
                }
                
                // MARK: - Submit Button
                Section {
                    Button(action: {
                        submitRequest()
                    }) {
                        HStack {
                            Spacer()
                            if mechanicVM.isCreatingRequest {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 8)
                            }
                            Text("Request Assistance")
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .foregroundColor(.white)
                    }
                    .padding()
                    .listRowBackground(isFormValid ? (isEmergency ? Color.red : Color.blue) : Color.gray.opacity(0.5))
                    .disabled(!isFormValid || mechanicVM.isCreatingRequest)
                }
                
                // MARK: - Error / Success Banners
                if let error = mechanicVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("New Service Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await vehicleVM.fetchVehicles()
                await mechanicVM.fetchAvailableBengkels()
                
                // Auto-select first if available
                if let firstVehicle = vehicleVM.userVehicles.first?.id {
                    selectedVehicleId = firstVehicle
                }
            }
            .navigationDestination(isPresented: $navigateToWaiting) {
                WaitingForMechanicView(mechanicVM: mechanicVM)
            }
        }
    }
    
    private var isFormValid: Bool {
        !selectedVehicleId.isEmpty &&
        !selectedBengkelId.isEmpty &&
        !serviceType.trimmingCharacters(in: .whitespaces).isEmpty &&
        !location.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func submitRequest() {
        Task {
            let success = await mechanicVM.createServiceRequest(
                vehicleId: selectedVehicleId,
                bengkelId: selectedBengkelId,
                serviceType: serviceType,
                description: description.isEmpty ? nil : description,
                isEmergency: isEmergency,
                location: location
            )
            
            if success {
                navigateToWaiting = true
            }
        }
    }
}

#Preview {
    CreateOrderView()
}
