//
//  OSMMapView.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//
//  UIViewRepresentable wrapping MKMapView with an OpenStreetMap tile overlay.
//  Notifies the parent ViewModel when the user pans the map so it can reverse-geocode.
//

import SwiftUI
import MapKit

struct OSMMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    /// While the search overlay is shown we suppress region-change callbacks to avoid feedback loops.
    var isEditing: Bool
    var onRegionChange: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // OpenStreetMap tile overlay
        let template = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = true
        mapView.addOverlay(overlay, level: .aboveLabels)

        mapView.setRegion(region, animated: false)
        mapView.showsUserLocation = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Only re-center if region changed meaningfully (avoid fighting the user's pan).
        let current = mapView.region.center
        let next = region.center
        let delta = abs(current.latitude - next.latitude) + abs(current.longitude - next.longitude)
        if delta > 0.0005 {
            mapView.setRegion(region, animated: true)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: OSMMapView
        private var debounceWork: DispatchWorkItem?

        init(_ parent: OSMMapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Don't react while the user is in the search overlay.
            if parent.isEditing { return }

            let center = mapView.region.center
            parent.region = mapView.region

            // Debounce so we only reverse-geocode after the user stops panning.
            debounceWork?.cancel()
            let work = DispatchWorkItem { [parent] in
                parent.onRegionChange(center)
            }
            debounceWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
    }
}
