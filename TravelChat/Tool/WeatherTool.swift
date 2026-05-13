// Copyright (c) 2026 Tc Pun / TCPUN Studio
// Licensed under the MIT License. See LICENSE for details.

import Foundation
import FoundationModels

@MainActor
struct WeatherTool: Tool {
    
    let name = "getWeather"
    let description = "Retrieves current weather for a specified city."
    
    @Generable
    struct Arguments {
        @Guide(description: "The name of the city to get weather for")
        var city: String
    }
    
    func call(arguments: Arguments) async throws -> String {
        let cityEncoded = arguments.city
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? arguments.city
        let urlString = "https://wttr.in/\(cityEncoded)?format=j1"
        
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "WeatherTool",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL for city: \(arguments.city)"])
        }
        
        var request = URLRequest(url: url)
        request.setValue("TravelChat/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NSError(
                domain: "WeatherTool",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Weather data not found for \(arguments.city)"])
        }
        
        let wttr = try JSONDecoder().decode(WttrResponse.self, from: data)
        
        guard let current = wttr.current_condition.first else {
            throw NSError(
                domain: "WeatherTool",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No weather data returned for \(arguments.city)"])
        }
        
        let desc = current.weatherDesc.first?.value ?? "Unknown"
        return "\(arguments.city): \(current.temp_C)°C, \(desc), wind \(current.windspeedKmph) km/h, humidity \(current.humidity)%"
    }
}

// MARK: - wttr.in JSON models

struct WttrResponse: Codable {
    let current_condition: [WttrCurrentCondition]
}

struct WttrCurrentCondition: Codable {
    let temp_C: String
    let windspeedKmph: String
    let humidity: String
    let weatherDesc: [WttrDescription]
}

struct WttrDescription: Codable {
    let value: String
}
