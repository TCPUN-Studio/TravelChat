// Copyright (c) 2026 Tc Pun / TCPUN Studio
// Licensed under the MIT License. See LICENSE for details.

import Foundation
import FoundationModels
import CoreLocation

struct CurrencyExchangeTool: Tool {
    
    let name = "getCurrencyExchange"
    let description = "Retrieves exchange rate between user's locale currency and destination city's currency."

    @Generable
    struct Arguments {
        @Guide(description: "The destination city name")
        var destinationCity: String
    }

    func call(arguments: Arguments) async throws -> String {
        let countryCode = try await geocodeToCountryCode(arguments.destinationCity)

        guard let destCurrency = currencyForCountry(countryCode) else {
            return "Unable to determine currency for \(arguments.destinationCity)"
        }

        guard let userCurrency = Locale.current.currency?.identifier else {
            return "Unable to determine your local currency"
        }

        if destCurrency == userCurrency {
            return "Your local currency (\(userCurrency)) is already used in \(arguments.destinationCity). No exchange needed!"
        }

        let rate = try await fetchExchangeRate(base: userCurrency, quote: destCurrency)
        return "1 \(userCurrency) = \(String(format: "%.4f", rate)) \(destCurrency)"
    }

    private func geocodeToCountryCode(_ cityName: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            CLGeocoder().geocodeAddressString(cityName) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let placemark = placemarks?.first, let countryCode = placemark.isoCountryCode else {
                    continuation.resume(throwing: NSError(
                        domain: "CurrencyExchangeTool",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to determine country for \(cityName)"]
                    ))
                    return
                }
                continuation.resume(returning: countryCode)
            }
        }
    }

    private func currencyForCountry(_ isoCountryCode: String) -> String? {
        let components: [String: String] = [NSLocale.Key.countryCode.rawValue: isoCountryCode]
        let identifier = Locale.identifier(fromComponents: components)
        let locale = Locale(identifier: identifier)
        return locale.currency?.identifier
    }

    private func fetchExchangeRate(base: String, quote: String) async throws -> Double {
        // Frankfurter API v2: response is an array of rate objects
        let urlString = "https://api.frankfurter.dev/v2/rates?base=\(base)&quotes=\(quote)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "CurrencyExchangeTool", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let rates = try JSONDecoder().decode([FrankfurterV2Rate].self, from: data)

        guard let rate = rates.first?.rate else {
            throw NSError(domain: "CurrencyExchangeTool", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Exchange rate not found"])
        }

        return rate
    }
}

// Actual Frankfurter API v2 response is an array:
// [{"date":"2026-05-08","base":"SGD","quote":"EUR","rate":0.6709}]
struct FrankfurterV2Rate: Codable {
    let date: String
    let base: String
    let quote: String
    let rate: Double
}
