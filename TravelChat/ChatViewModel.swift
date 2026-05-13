// Copyright (c) 2026 Tc Pun / TCPUN Studio
// Licensed under the MIT License. See LICENSE for details.

import Foundation
import FoundationModels
import Observation

@Observable
@MainActor
class ChatViewModel {
    
    var messages: [ChatMessage] = []
    var isGenerating = false
    var actions: [RemoteAction] = []
    var isLoadingConfig = true

    private var session: LanguageModelSession?

    init() {
        Task {
            await loadConfig()
        }
    }

    func refresh() async {
        guard !isLoadingConfig, !isGenerating else { return }
        messages = []
        actions = []
        session = nil
        isLoadingConfig = true
        await loadConfig()
    }

    func send(_ text: String) async {
        guard let session else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: trimmed))
        isGenerating = true
        defer { isGenerating = false }

        do {
            let response = try await session.respond(to: trimmed)
            messages.append(ChatMessage(role: .assistant, content: response.content))
        } catch {
            messages.append(ChatMessage(
                role: .assistant,
                content: "I'm sorry, I encountered an issue. Please try again."
            ))
        }
    }
}

private extension ChatViewModel {
    
    func loadConfig() async {
        defer { isLoadingConfig = false }

        do {
            let config = try await RemoteConfig.fetch()
            actions = config.actions
            session = LanguageModelSession(
                tools: [WeatherTool(), CurrencyExchangeTool()],
                instructions: config.instructions
            )
        } catch {
            actions = RemoteConfig.defaultActions
            session = LanguageModelSession(
                tools: [WeatherTool(), CurrencyExchangeTool()],
                instructions: RemoteConfig.defaultInstructions
            )
        }

        session?.prewarm()
        await generateWelcome()
    }

    func generateWelcome() async {
        let content = await WelcomeService.generate()
        guard let content else { return }
        messages.append(ChatMessage(role: .assistant, content: content))
    }
}
