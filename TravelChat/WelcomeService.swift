// Copyright (c) 2026 Tc Pun / TCPUN Studio
// Licensed under the MIT License. See LICENSE for details.

import CoreLocation
import Foundation
import FoundationModels

enum WelcomeService {

    /// Generates a personalized welcome message using the on-device model.
    /// Returns `nil` if generation fails (app should start silently in that case).
    static func generate() async -> String? {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = switch hour {
            case 0..<12: "morning"
            case 12..<17: "afternoon"
            default: "evening"
        }

        let locationHint: String
        if let city = await currentCity() {
            locationHint = "The user is currently in \(city)."
        } else if let region = Locale.current.region?.identifier,
                  let country = Locale.current.localizedString(forRegionCode: region) {
            locationHint = "The user appears to be in \(country) based on their device locale."
        } else {
            locationHint = ""
        }

        let prompt = """
        Good \(timeOfDay)! \(locationHint)
        Write a single short paragraph (2–3 sentences) welcoming the user to TravelChat. \
        Mention the time of day warmly. \
        If a location is provided, acknowledge it and hint at nearby travel possibilities. \
        End with an invitation to ask about any destination, weather, or currency.
        """

        let session = LanguageModelSession()
        return try? await session.respond(to: prompt).content
    }

    // MARK: - Location

    private static func currentCity() async -> String? {
        guard await requestLocationAuthorization() else { return nil }

        guard let location = await fetchOneLocation() else { return nil }

        return await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                let city = placemarks?.first?.locality
                    ?? placemarks?.first?.administrativeArea
                continuation.resume(returning: city)
            }
        }
    }

    /// Returns `true` if location access is authorized (or just became authorized).
    private static func requestLocationAuthorization() async -> Bool {
        let manager = CLLocationManager()
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                let delegate = AuthorizationDelegate(continuation: continuation)
                manager.delegate = delegate
                // Keep delegate alive for the duration of the callback.
                objc_setAssociatedObject(manager, &AssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN)
                manager.requestWhenInUseAuthorization()
            }
        default:
            return false
        }
    }

    /// Requests a single location fix using the async CLLocationUpdate API (iOS/macOS 17+).
    private static func fetchOneLocation() async -> CLLocation? {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location {
                    return location
                }
                if update.authorizationDenied || update.authorizationRequestInProgress == false {
                    return nil
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    // MARK: - Helpers

    private enum AssociatedKeys {
        static var delegate = "AuthorizationDelegateKey"
    }

    private final class AuthorizationDelegate: NSObject, CLLocationManagerDelegate {
        private let continuation: CheckedContinuation<Bool, Never>
        private var resumed = false

        init(continuation: CheckedContinuation<Bool, Never>) {
            self.continuation = continuation
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            guard !resumed else { return }
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                resumed = true
                continuation.resume(returning: true)
            case .denied, .restricted:
                resumed = true
                continuation.resume(returning: false)
            default:
                break
            }
        }
    }
}
