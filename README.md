# Lumio iOS SDK

Revenue-first analytics for iOS subscription apps. Track your onboarding funnel, paywall performance, and core activation — then see exactly where users drop off and why.

## Features

- **Onboarding Funnel** — Track each step with `trackStep()`. See drop-off rates per screen.
- **Paywall Analytics** — Track impressions with `trackPaywallView()`. Measure time-to-paywall velocity.
- **Aha! Multiplier** — Track your core action with `trackCoreAction()`. See how Day-1 activation correlates with LTV.
- **Cohort Segmentation** — Tag users with `identifyUser()`. Split your funnel by traffic source, user goal, or any custom property.
- **Source Attribution** — Automatically detects Apple Search Ads vs organic. Includes a pre-built `SourcePickerView` for self-reported attribution.
- **Auto-Collected** — Platform (iPhone/iPad), iOS version, and source are detected automatically on `configure()`.
- **RevenueCat Integration** — Purchase and renewal events flow in via server-to-server webhooks. No SDK code needed for revenue tracking.
- **Offline Support** — Failed events are persisted to disk and retried on next launch.
- **Privacy-First** — Uses IDFV (no ATT required). Zero personal data collected.

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 6.0+
- Xcode 16.0+
- Zero external dependencies

## Installation

### Swift Package Manager (Xcode)

1. **File → Add Package Dependencies...**
2. Enter the URL:
   ```
   https://github.com/turganbekuly/lumio-ios.git
   ```
3. Select **Up to Next Major Version** from `1.0.0`
4. Add **Lumio** to your app target

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/turganbekuly/lumio-ios.git", from: "1.0.0")
]
```

## Quick Start

```swift
import Lumio
import RevenueCat

// 1. Configure (once, on app launch)
Lumio.shared.configure(appKey: "lm_your_key_here")

// 2. Tell RevenueCat to use the same user ID Lumio uses.
//    Required so purchase webhooks land on the same user as your tracked events.
Purchases.shared.logIn(Lumio.shared.userID) { _, _, _ in }

// 3. Track onboarding steps
Lumio.shared.trackStep(name: "welcome", order: 1)
Lumio.shared.trackStep(name: "age_selection", order: 2)
Lumio.shared.trackStep(name: "goal_setting", order: 3)

// 4. Track paywall view
Lumio.shared.trackPaywallView(name: "main_paywall")

// 5. Track core activation action
Lumio.shared.trackCoreAction(name: "first_session_completed")

// 6. Tag users for cohort analysis (optional — source & platform are auto-collected)
Lumio.shared.identifyUser(property: "goal", value: "lose_weight")
```

## API Reference

### `configure(appKey:endpoint:)`

Initialize the SDK. Call once in `App.init()` or `application(_:didFinishLaunchingWithOptions:)`.

```swift
Lumio.shared.configure(appKey: "lm_your_key")

// Self-hosted backend? Override the endpoint:
// Lumio.shared.configure(appKey: "lm_your_key", endpoint: URL(string: "https://your-server.com")!)
```

Auto-collects on configure:
| Property | Example | Source |
|----------|---------|--------|
| `platform` | `iPhone` | `UIDevice.current.userInterfaceIdiom` |
| `ios_version` | `17.4` | `UIDevice.current.systemVersion` |
| `source` | `apple_search_ads` / `organic` | Apple AdServices framework |

### `trackStep(name:order:)`

Track a screen in your onboarding funnel.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Step identifier (snake_case). Appears in the funnel chart. |
| `order` | `Int` | Sequential position (1, 2, 3...). Steps are sorted by this. |

### `trackPaywallView(name:)`

Track when a paywall is displayed.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Paywall identifier (e.g. `"main_paywall"`, `"annual_promo"`). |

### `trackCoreAction(name:)`

Track the "aha!" moment — the single most important action in your app.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Action identifier (e.g. `"focus_session_completed"`). |

> Track only **one** core action per app. The Aha! Multiplier compares users who completed this action within 24h vs those who didn't.

### `identifyUser(property:value:)`

Tag the current user with a property for cohort segmentation.

| Parameter | Type | Description |
|-----------|------|-------------|
| `property` | `String` | Property key (e.g. `"goal"`, `"experience"`). |
| `value` | `String` | Property value (e.g. `"lose_weight"`, `"beginner"`). |

> `source` and `platform` are auto-collected — only call this for app-specific properties.

### `SourcePickerView`

Pre-built SwiftUI view for self-reported source attribution.

```swift
Lumio.SourcePickerView(
    title: "Quick question",
    subtitle: "How did you hear about us?",
    sources: ["TikTok", "Instagram", "App Store", "Friend", "Other"],
    accentColor: .blue,
    property: "source",
    showSkip: true,
    skipLabel: "Skip",
    columns: nil,                               // auto: 1 iPhone, 2 iPad/Mac
    onComplete: { selected in
        // selected: normalized value ("tiktok") or nil if skipped
    }
)
```

Adapts to iPhone (1 column), iPad (2 columns), macOS (2 columns + hover states).

### `flush()`

Force-flush queued events. Call in `sceneDidDisconnect` or `applicationWillTerminate`.

```swift
Lumio.shared.flush()
```

## How It Works

1. **Events are batched** — flushed every 30 seconds or when 30 events accumulate
2. **Sent via HTTPS** — `POST /v1/track` with your API key in the `X-App-Key` header
3. **Retried on failure** — exponential backoff (1s, 4s, 16s), max 3 attempts
4. **Persisted offline** — failed batches saved to disk, retried on next launch
5. **User ID** — Keychain-persisted UUID (seeded from IDFV on first launch). Survives app reinstalls on the same device in most cases. Pass `Lumio.shared.userID` to RevenueCat so purchases land on the same user.

## RevenueCat Integration

Purchases are tracked via RevenueCat webhooks (server-to-server) — no SDK code needed for revenue tracking itself, but you **must** align the user IDs so Lumio can join SDK events to purchases.

**In your app**, right after `configure()`:

```swift
Lumio.shared.configure(appKey: "lm_your_key")
Purchases.shared.logIn(Lumio.shared.userID) { _, _, _ in }
```

Without this, RevenueCat generates its own `$RCAnonymousID:…` and the join fails — you'll see one user with all your funnel events and a separate "user" with just the purchase.

**In the RevenueCat dashboard**, set up the webhook:

1. **Project Settings → Integrations → Webhooks**
2. URL: `https://api.trylumio.app/v1/webhooks/revenuecat`
3. Auth header: `Bearer lm_whk_your_webhook_secret` (your per-app **webhook secret** from Lumio → Settings — *not* the public SDK app key)
4. Events: `INITIAL_PURCHASE`, `RENEWAL`

## License

MIT
