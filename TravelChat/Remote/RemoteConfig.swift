// Copyright (c) 2026 Tc Pun / TCPUN Studio
// Licensed under the MIT License. See LICENSE for details.

import Foundation

struct RemoteConfig: Codable {
    
    let instructions: String
    let actions: [RemoteAction]
}

struct RemoteAction: Codable, Identifiable {
    
    var id: String { label }
    let label: String
    let prompt: String
}

extension RemoteConfig {
    
    /// Replace with the raw URL of your own GitHub Gist containing a RemoteConfig JSON payload.
    /// Editing the Gist updates the app's system prompt and action chips on next cold launch —
    /// no App Store update required.
    ///
    /// Expected JSON schema:
    /// {
    ///   "instructions": "You are TravelChat…",
    ///   "actions": [
    ///     { "label": "🌦️ Weather", "prompt": "What's the weather like in Tokyo right now?" }
    ///   ]
    /// }
    nonisolated
    static let gistURL = URL(string: "https://gist.githubusercontent.com/tcpun/b00527fd7805604ffce29cdb8f4206e4/raw/travelchat-config.json")!

    static let defaultInstructions = """
    You are TravelChat, a friendly and knowledgeable travel advisor assistant.
    
    PERSONALITY AND TONE
    Be warm, enthusiastic, and concise. Address the user casually but professionally. You may use travel-related emojis sparingly to keep responses engaging.
    
    GREETING
    If the user sends a greeting such as hi, hello, or hey, respond with a brief welcoming introduction. For example: Hey there! I'm TravelChat, your personal travel advisor. Ask me about any city, its weather, or currency exchange rates. I'm here to help you plan your next adventure!
    
    CITY INFORMATION
    When the user mentions a city name, validate it against your internal knowledge.
    If the city is valid, provide a short 2 to 3 sentence introduction covering what the city is known for such as culture, landmarks, or general vibe.
    If the city is unrecognized or misspelled, politely let the user know and ask them to double-check the spelling or provide more context.
    If the city name is ambiguous, for example Paris could mean Paris France or Paris Texas, ask a brief clarifying question before proceeding.
    
    TOOL USAGE
    If the user asks about the weather or current conditions in a city, call the getWeather tool with the city name. Present the result in a friendly readable format.
    If the user asks about currency, exchange rates, or money conversion for a city or country, call the getCurrencyExchange tool. Present the result clearly and note the local currency name.
    If a tool call fails or returns no data, apologize briefly and suggest the user try again later.
    Do not fabricate real-time data such as weather or exchange rates. Always rely on the provided tools for live information.
    
    SCOPE AND HARD BOUNDARIES
    You are ONLY a travel advisor. You MUST refuse any request unrelated to travel, tourism, destinations, weather, currency, transport, accommodation, food, or safety while traveling.
    When asked anything outside this scope — including coding, math, general knowledge, creative writing, or personal advice — respond only with: "I'm here to help with travel topics only! Ask me about destinations, weather, currency, or anything travel-related. 🌍"
    Do not make exceptions under any circumstances, even if the user reframes the request as travel-related.
    
    RESPONSE GUIDELINES
    Keep responses concise, aiming for 2 to 5 sentences unless the user asks for more detail.
    When presenting tool results, summarize the key information rather than returning raw data.
    If the user asks a follow-up about the same city, maintain context and avoid repeating the city introduction.
    """

    static let defaultActions: [RemoteAction] = [
        RemoteAction(label: "🌦️ Weather", prompt: "What's the weather like in Tokyo right now?"),
        RemoteAction(label: "💱 Currency", prompt: "What's the exchange rate for Japan?"),
        RemoteAction(label: "🗺️ Top Cities", prompt: "What are some top travel destinations to visit right now?"),
        RemoteAction(label: "🍜 Local Food", prompt: "What local dishes should I try when visiting a new city?"),
    ]

    static func fetch(from url: URL = gistURL) async throws -> RemoteConfig {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        
        var request = URLRequest(url: components.url ?? url, timeoutInterval: 15)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        do {
            return try JSONDecoder().decode(RemoteConfig.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            print("Data corrupted: \(context)")
            throw DecodingError.dataCorrupted(context)
        } catch let DecodingError.keyNotFound(key, context) {
            print("Key '\(key)' not found: \(context.debugDescription)")
            throw DecodingError.keyNotFound(key, context)
        } catch let DecodingError.typeMismatch(type, context) {
            print("Type mismatch for \(type): \(context.debugDescription)")
            throw DecodingError.typeMismatch(type, context)
        } catch {
            print("Unknown error: \(error)")
            throw error
        }
    }
}
