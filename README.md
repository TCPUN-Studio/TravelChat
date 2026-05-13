# TravelChat

> A demo iOS/macOS app showing how to extend Apple's on-device LLM with **external API tools** and **server-driven prompts** — no App Store update required to change the AI's behaviour or the app's UI.

![Platform](https://img.shields.io/badge/platform-iOS%2026%20%7C%20macOS%2026-blue)
![Swift](https://img.shields.io/badge/swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## What This Project Demonstrates

### 1 — External API Tools with FoundationModels

Apple's [`FoundationModels`](https://developer.apple.com/documentation/foundationmodels) framework (iOS/macOS 26+) runs a powerful on-device LLM. Out of the box it has no access to real-time data. TravelChat shows how to bridge that gap with custom `Tool` implementations that call live external APIs:

| Tool | API | What it provides |
|---|---|---|
| `WeatherTool` | [wttr.in](https://wttr.in) | Current temperature, conditions, wind & humidity for any city |
| `CurrencyExchangeTool` | [Frankfurter](https://www.frankfurter.dev) + `CLGeocoder` | Live exchange rate between the user's locale currency and the destination |

The model decides when to call a tool based on the user's message — the app never hard-codes which tool to invoke.

### 2 — Server-Driven Prompts & UI (Zero App Store Updates)

The LLM's **system prompt** and the **quick-action chips** displayed in the UI are loaded from a remote JSON config (a GitHub Gist) at every cold launch. A developer can:

- Change the assistant's personality, scope, or instructions
- Add, remove, or relabel action chips
- Adjust what prompt each chip fires

…by editing a single Gist file. No Xcode, no build, no App Store review.

Tap the **↺ refresh button** in the toolbar to re-fetch the config and reload the session without restarting the app — ideal for live demos.

---

## Requirements

| Requirement | Version |
|---|---|
| Xcode | 26.0 beta or later |
| iOS Deployment Target | 26.0 |
| macOS Deployment Target | 26.0 |
| Swift | 5.0 |

> **Apple Silicon Mac required** — `FoundationModels` uses the on-device model which is not available on Intel or on the iOS Simulator running on Intel.

---

## Quick Start

```bash
git clone https://github.com/tcpun/TravelChat.git
cd TravelChat
open TravelChat.xcodeproj
```

1. Select an **iOS 26** or **macOS 26** target in Xcode
2. Press **⌘R** to build and run
3. The app loads its config from the Gist at launch — see [Customising the Remote Config](#customising-the-remote-config) below

---

## Customising the Remote Config

### Point to your own Gist

Open `TravelChat/RemoteConfig.swift` and replace the `gistURL` value:

```swift
static let gistURL = URL(string: "https://gist.githubusercontent.com/YOUR_USERNAME/YOUR_GIST_ID/raw/travelchat-config.json")!
```

> Use the URL **without** a commit SHA so every cold launch fetches the latest revision.

### Gist JSON schema

Create a public Gist file named `travelchat-config.json`:

```json
{
  "instructions": "You are TravelChat, a friendly travel advisor...",
  "actions": [
    { "label": "🌦️ Weather",    "prompt": "What's the weather like in Tokyo right now?" },
    { "label": "💱 Currency",   "prompt": "What's the exchange rate for Japan?" },
    { "label": "🗺️ Top Cities", "prompt": "What are some top travel destinations right now?" },
    { "label": "🍜 Local Food", "prompt": "What local dishes should I try when visiting a new city?" }
  ]
}
```

| Field | Type | Description |
|---|---|---|
| `instructions` | `String` | Full system prompt passed to `LanguageModelSession` |
| `actions` | `Array` | Quick-action chips shown above the input bar |
| `actions[].label` | `String` | Button label (supports emoji) |
| `actions[].prompt` | `String` | Prompt sent to the LLM when the chip is tapped |

If the Gist is unreachable (offline, timeout, parse error), the app silently falls back to its bundled defaults — it never blocks.

### More demo action chips

The following chips cover a wider range of travel topics and make for a compelling live demo. Copy any of these into your Gist's `actions` array:

| Label | Prompt |
|---|---|
| `🏨 Hotels` | `What types of accommodation are best for a first-time visit to Tokyo?` |
| `✈️ Flight Tips` | `What are some tips to make a long-haul flight more comfortable?` |
| `🎒 Packing List` | `What should I pack for a two-week trip to Southeast Asia?` |
| `🗣️ Local Phrases` | `What are some essential phrases to know when visiting Japan?` |
| `🚇 Getting Around` | `What's the best way to get around Tokyo using public transport?` |
| `📅 Best Time to Visit` | `When is the best time of year to visit Bali, and why?` |
| `🛂 Visa Tips` | `What general tips should I know about international visa applications?` |
| `🌡️ Health & Safety` | `What health precautions should I take before traveling to Southeast Asia?` |
| `🎭 Hidden Gems` | `What are some underrated travel destinations worth visiting in 2026?` |
| `💡 Budget Tips` | `What are the best ways to travel on a budget without sacrificing experience?` |

---

## Project Structure

```
TravelChat/
├── TravelChatApp.swift        App entry point
├── ChatView.swift             Main chat UI + action chips
├── ChatViewModel.swift        @Observable; owns LanguageModelSession; loads remote config; triggers welcome
├── ChatMessage.swift          Message value type (role + content)
├── RemoteConfig.swift         RemoteConfig model, fetch logic, Gist URL, and fallback defaults
├── WelcomeService.swift       Generates personalised welcome via FoundationModels + CoreLocation
└── Tool/
    ├── WeatherTool.swift       FoundationModels Tool → wttr.in
    └── CurrencyExchangeTool.swift  FoundationModels Tool → CLGeocoder + Frankfurter API
```

---

## How It Works — Architecture Overview

```
App launch
  └─ ChatViewModel.init()
       └─ Task { await loadConfig() }
            ├─ Fetch RemoteConfig JSON from Gist (5 s timeout, cache-busted)
            │    ├─ Success → use remote instructions + actions
            │    └─ Failure → fall back to bundled defaults
            ├─ Create LanguageModelSession(tools:instructions:)
            │    └─ session.prewarm()
            └─ WelcomeService.generate()
                 ├─ Get time of day from Date()
                 ├─ Try CLLocation + CLGeocoder for current city (falls back to Locale region)
                 └─ Separate LanguageModelSession generates welcome → first assistant message

User interaction
  ├─ Tap chip  → viewModel.send(action.prompt)
  └─ Type text → viewModel.send(inputText)
       └─ session.respond(to:)
            └─ LLM decides to call WeatherTool / CurrencyExchangeTool / respond directly
```

---

## Adding a New Tool

1. Create a new Swift file in `Tool/`
2. Conform to `FoundationModels.Tool`:

```swift
import FoundationModels

struct MyTool: Tool {
    let name = "myTool"
    let description = "What this tool does — the LLM reads this to decide when to call it."

    @Generable
    struct Arguments {
        @Guide(description: "Description visible to the model")
        var param: String
    }

    func call(arguments: Arguments) async throws -> String {
        // Fetch data, return a plain-text summary for the LLM to present
    }
}
```

3. Add an instance to the `tools:` array in `ChatViewModel.loadConfig()`:

```swift
session = LanguageModelSession(
    tools: [WeatherTool(), CurrencyExchangeTool(), MyTool()],
    instructions: resolvedInstructions
)
```

4. Update the system prompt (`instructions`) to describe when the model should call the new tool.

---

## Credits

Built by [Tc Pun / TCPUN Studio](https://github.com/tcpun) as a developer reference project.

- Weather data: [wttr.in](https://wttr.in)
- Exchange rates: [Frankfurter](https://www.frankfurter.dev)
- On-device LLM: Apple [FoundationModels](https://developer.apple.com/documentation/foundationmodels) framework

---

## License

MIT — see [LICENSE](LICENSE) for details.
