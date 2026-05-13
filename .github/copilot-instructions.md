# TravelChat – Copilot Instructions

## Project Overview

TravelChat is a SwiftUI travel advisor chatbot that runs on **iOS and macOS** (deployment target: iOS 26 / macOS 26). It uses Apple's **`FoundationModels`** framework (on-device LLM, new in iOS/macOS 26) to power an AI assistant that can answer travel questions and call real-time tools.

## Build & Run

Open `TravelChat.xcodeproj` in Xcode 26+. There is no SPM package, no CLI build script, and no test suite — build and run exclusively through Xcode.

- **Run on simulator**: Product → Run (⌘R), select an iOS 26 or macOS 26 target
- **Supported platforms**: `iphoneos`, `iphonesimulator`, `macosx` (all configured via `SUPPORTED_PLATFORMS`)
- **Bundle ID**: `studio.tcpun.app.TravelChat`
- **Required entitlement**: `com.apple.security.network.client` (network outbound calls to wttr.in and Frankfurter API)

## Architecture

```
TravelChatApp          Entry point — wraps ChatView in NavigationStack
ChatView               SwiftUI view; renders message list + action chips + input bar
  └─ MessageBubble     Stateless bubble component (user = blue right, assistant = gray left)
ChatViewModel          @MainActor ObservableObject; fetches RemoteConfig, owns LanguageModelSession
  └─ LanguageModelSession  Created after config resolves; optional until then; prewarmed post-init
ChatMessage            Value-type model: id (UUID), role (user|assistant), content (String)
RemoteConfig           Codable config model + fetch logic; defines Gist URL and fallback defaults
  └─ RemoteAction      Identifiable chip: label (display text) + prompt (sent to LLM on tap)
Tool/
  WeatherTool          Calls wttr.in (?format=j1) → returns temp/conditions/wind/humidity string
  CurrencyExchangeTool CLGeocoder → country code → Locale.currency → Frankfurter API v2 → rate string
```

### Startup & config loading flow

```
App launches
  └─ ChatViewModel.init() → Task { await loadConfig() }
       ├─ RemoteConfig.fetch(from: gistURL)  [5s timeout, no cache]
       │    ├─ success → use remote instructions + actions
       │    └─ failure → silent fallback to RemoteConfig.defaultInstructions / defaultActions
       └─ LanguageModelSession created with resolved instructions
       └─ session?.prewarm()
ChatView shows "Connecting to advisor…" while isLoadingConfig == true
Chips render from viewModel.actions; tapping fires viewModel.send(action.prompt)
```

The `LanguageModelSession` holds the full conversation context internally — `ChatViewModel` only appends user/assistant pairs to its local `messages` array for display. There is no manual history management.

## Key Conventions

### FoundationModels Tool pattern
Every tool must:
1. Conform to `FoundationModels.Tool`
2. Declare a nested `@Generable struct Arguments` with `@Guide(description:)` annotations on each property
3. Implement `func call(arguments: Arguments) async throws -> String` returning a plain-text result

```swift
struct MyTool: Tool {
    let name = "myTool"
    let description = "What this tool does."

    @Generable
    struct Arguments {
        @Guide(description: "Description for the model")
        var param: String
    }

    func call(arguments: Arguments) async throws -> String {
        // return plain text consumed by the LLM
    }
}
```

### Session is created after config loads (not at declaration)
`LanguageModelSession` is an `Optional` on `ChatViewModel`, initialized to `nil` and set inside the async `loadConfig()` method after the remote config is resolved. Do **not** return to storing it as a `let` stored property — it must be created with the fetched (or fallback) `instructions`. The view gates all sends on `!viewModel.isLoadingConfig`.

### Remote config — Gist-driven instructions and chips
`RemoteConfig.gistURL` in `RemoteConfig.swift` is the **single place** to update when pointing to a different config source. The Gist JSON schema:

```json
{
  "instructions": "System prompt string for LanguageModelSession",
  "actions": [
    { "label": "🌦️ Weather", "prompt": "Full prompt sent to the LLM when tapped" }
  ]
}
```

- `RemoteConfig.defaultInstructions` and `RemoteConfig.defaultActions` are the offline fallbacks.
- Fetch is fire-and-forget on cold launch with a 5-second timeout and no caching (`reloadIgnoringLocalCacheData`).

### Session is created once, not per-message
Once `loadConfig()` sets `session`, it is never replaced. Do not recreate `LanguageModelSession` per `send()` call — it holds the full conversation context internally and must persist across messages.

### Platform-conditional UI
Use `#if os(iOS)` / `#if os(macOS)` for platform-specific view modifiers. The macOS window has a fixed frame (`600×400`); iOS uses `.navigationBarTitleDisplayMode(.inline)`.

### External APIs
| Tool | API | Notes |
|---|---|---|
| WeatherTool | `https://wttr.in/{city}?format=j1` | Set `User-Agent: TravelChat/1.0`; parse `current_condition[0]` |
| CurrencyExchangeTool | `https://api.frankfurter.dev/v2/rates?base={base}&quotes={quote}` | Response is a JSON **array** of `FrankfurterV2Rate`; city → country via `CLGeocoder`, country → currency via `Locale` |

### ViewModel concurrency
`ChatViewModel` is `@MainActor`. `WeatherTool` is also `@MainActor`. `CurrencyExchangeTool` is not (it uses a `withCheckedThrowingContinuation` wrapper around `CLGeocoder`). `send(_:)` is an `async` method called via `Task { }` from the view layer.
