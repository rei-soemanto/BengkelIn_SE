//
//  LocationSearchView.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//
//  Generic search overlay driven by any LocationSearchable ViewModel.
//  Typing in the text field triggers a debounced Photon search via the VM,
//  tapping a result calls `selectSearchResult(_:)`.
//

import SwiftUI

struct LocationSearchView<VM: LocationSearchable>: View {
    @ObservedObject var viewModel: VM

    var body: some View {
        VStack(spacing: 0) {
            // Header with search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search address…", text: $viewModel.locationAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)

                Button {
                    viewModel.locationAddress = ""
                    viewModel.searchResults = []
                    viewModel.isEditingLocation = false
                } label: {
                    Text("Cancel")
                        .foregroundColor(.primary.opacity(0.9))
                }
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // Results list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.searchResults.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 30))
                                .foregroundColor(.secondary)
                            Text(viewModel.locationAddress.isEmpty
                                 ? "Type to search for an address."
                                 : "No results. Try a different query.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(viewModel.searchResults) { feature in
                            Button {
                                viewModel.selectSearchResult(feature)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.primary.opacity(0.7))
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(feature.properties.name ?? feature.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(feature.displayName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
