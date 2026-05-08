//
//  MechanicProfileView.swift
//  BengkelIn
//

import SwiftUI
import Combine

@MainActor
struct MechanicProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject var viewModel: MechanicProfileViewModel
    
    // Primary initializer
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        self._viewModel = StateObject(wrappedValue: MechanicProfileViewModel())
    }
    
    // Initializer for injecting mocks (Previews)
    init(authViewModel: AuthViewModel, viewModel: MechanicProfileViewModel) {
        self.authViewModel = authViewModel
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    @State private var showResignSheet = false
    @State private var passwordInput = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Profile")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(authViewModel.currentUser?.name ?? "Mechanic")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // Bengkel Info Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Current Workspace")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if let bengkel = viewModel.myBengkel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(bengkel.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let address = bengkel.address {
                                Label(address, systemImage: "mappin.and.ellipse")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5)
                        
                        // Danger Zone
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Danger Zone")
                                .font(.subheadline)
                                .foregroundColor(.red)
                            
                            Button(action: {
                                showResignSheet = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Resign from Bengkel")
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.red)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.top, 16)
                        
                    } else {
                        Text("You are not currently linked to any Bengkel.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                    }
                }
                .padding(.horizontal)
                
                // Messages
                if let error = viewModel.errorMessage {
                    messageView(text: error, color: .red)
                }
                
                if let success = viewModel.successMessage {
                    messageView(text: success, color: .green)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .background(Color(.systemGray6).edgesIgnoringSafeArea(.all))
        .task {
            // Only fetch if not in preview
            guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
            await viewModel.fetchMyBengkel()
        }
        .sheet(isPresented: $showResignSheet) {
            resignationSheet
        }
    }
    
    private func messageView(text: String, color: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(color)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
    }
    
    private var resignationSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Confirm Resignation")) {
                    Text("This action will disconnect you from the current Bengkel and cannot be undone without a new invitation.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    SecureField("Enter your password", text: $passwordInput)
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.subheadline)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            let success = await viewModel.submitResignation(password: passwordInput)
                            if success {
                                passwordInput = ""
                                showResignSheet = false
                            }
                        }
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isSubmitting {
                                ProgressView().padding(.trailing, 8)
                            }
                            Text("Confirm Resignation").fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .foregroundColor(.red)
                    .disabled(passwordInput.isEmpty || viewModel.isSubmitting)
                }
            }
            .navigationTitle("Resignation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showResignSheet = false
                        passwordInput = ""
                        viewModel.errorMessage = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - PREVIEW MOCK
@MainActor
class MockMechanicProfileViewModel: MechanicProfileViewModel {
    override init() {
        super.init()
        // Use memberwise init with all fields to be safe
        self.myBengkel = Bengkel(
            id: "mock_id",
            providerUid: "mock_provider",
            name: "The Dream Garage",
            address: "456 Mockingbird Lane",
            latitude: 0,
            longitude: 0,
            status: "Verified",
            offeredServices: [],
            averageRating: 5.0,
            totalReviews: 10,
            mechanicUids: [],
            createdAt: Date()
        )
    }
    
    override func fetchMyBengkel() async {
        // Do absolutely nothing to prevent loops
        return
    }
}

#Preview {
    MechanicProfileView(
        authViewModel: AuthViewModel(),
        viewModel: MockMechanicProfileViewModel()
    )
}
