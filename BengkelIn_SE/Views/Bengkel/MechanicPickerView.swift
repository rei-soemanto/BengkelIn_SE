//
//  MechanicPickerView.swift
//  BengkelIn_SE
//
//  Created for Mechanic feature on 05/05/26.
//

import SwiftUI

struct MechanicPickerView: View {
    @ObservedObject var bengkelVM: BengkelViewModel
    
    let orderId: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMechanicId: String?
    @State private var showNoMechanicAlert = false
    @State private var showAssignedAlert = false
    
    private var availableOnly: [Mechanic] {
        bengkelVM.availableMechanics.filter { $0.status == .available }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assign Mechanic")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text("Order:")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text(orderId)
                                .font(.subheadline)
                                .fontDesign(.monospaced)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // MARK: - Mechanic List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Mechanics")
                            .font(.headline)
                        
                        if bengkelVM.availableMechanics.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2.slash")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("No mechanics registered")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            ForEach(bengkelVM.availableMechanics) { mechanic in
                                mechanicRow(mechanic)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // MARK: - Assign Button
                    Button {
                        if availableOnly.isEmpty {
                            showNoMechanicAlert = true
                        } else if let mechanicId = selectedMechanicId {
                            bengkelVM.assignMechanic(to: orderId, mechanicId: mechanicId)
                            showAssignedAlert = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Assign Selected Mechanic")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            (availableOnly.isEmpty || selectedMechanicId == nil)
                            ? Color.gray
                            : Color.blue
                        )
                        .cornerRadius(12)
                    }
                    .disabled(availableOnly.isEmpty || selectedMechanicId == nil)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Pick a Mechanic")
            .navigationBarTitleDisplayMode(.inline)
            .alert("No Mechanics Available", isPresented: $showNoMechanicAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All mechanics are currently busy. Please try again later.")
            }
            .alert("Mechanic Assigned!", isPresented: $showAssignedAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("The mechanic has been assigned to this order successfully.")
            }
        }
    }
    
    // MARK: - Mechanic Row
    private func mechanicRow(_ mechanic: Mechanic) -> some View {
        Button {
            if mechanic.status == .available {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedMechanicId = mechanic.id
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 44, height: 44)
                    Text(String(mechanic.name.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mechanic.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(mechanic.status.rawValue)
                        .font(.caption)
                        .foregroundColor(mechanic.status == .available ? .green : .orange)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                if mechanic.status == .busy {
                    Text("Busy")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(6)
                } else if selectedMechanicId == mechanic.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                selectedMechanicId == mechanic.id
                ? Color.blue.opacity(0.08)
                : Color(.systemGray6)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedMechanicId == mechanic.id ? Color.blue.opacity(0.3) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .disabled(mechanic.status == .busy)
    }
}

#Preview {
    MechanicPickerView(
        bengkelVM: BengkelViewModel(),
        orderId: "ORD-PREVIEW-001"
    )
}
