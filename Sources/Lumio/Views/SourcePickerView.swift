#if canImport(SwiftUI)
import SwiftUI

/// A drop-in SwiftUI view for self-reported source attribution.
///
/// Present this during onboarding to ask users how they discovered your app.
/// On selection, it automatically calls `Lumio.shared.identifyUser(property:value:)`
/// and invokes your `onComplete` closure.
///
/// ```swift
/// // Minimal usage
/// Lumio.SourcePickerView(
///     sources: ["TikTok", "Instagram", "App Store", "Friend"],
///     onComplete: { _ in navigateNext() }
/// )
///
/// // Fully customized
/// Lumio.SourcePickerView(
///     title: "One quick question",
///     subtitle: "This helps us improve your experience",
///     sources: ["TikTok", "Instagram", "App Store Search", "Reddit", "Friend", "Other"],
///     accentColor: .blue,
///     property: "source",
///     showSkip: true,
///     skipLabel: "Maybe later",
///     columns: 2,
///     onComplete: { selected in
///         print("User selected: \(selected ?? "skipped")")
///     }
/// )
/// ```
public struct GMSourcePickerView: View {

    // MARK: - Configuration

    /// The heading text displayed above the options.
    public let title: String

    /// The subheading text displayed below the title.
    public let subtitle: String

    /// The source options to display as tappable cards.
    public let sources: [String]

    /// The accent color used for the selected state highlight. Defaults to the app's accent color.
    public let accentColor: Color

    /// The `identifyUser` property key sent to the backend. Defaults to `"source"`.
    public let property: String

    /// Whether to show a skip button below the options.
    public let showSkip: Bool

    /// The label for the skip button.
    public let skipLabel: String

    /// Number of columns in the grid. `nil` means auto: 1 on compact width, 2 on regular.
    public let columns: Int?

    /// Called when the user selects a source or skips. Receives the normalized value, or `nil` if skipped.
    public let onComplete: (String?) -> Void

    // MARK: - State

    @State private var selected: String?
    @State private var isHovering: String?
    @Environment(\.horizontalSizeClass) private var sizeClass

    // MARK: - Init

    public init(
        title: String = "Quick question",
        subtitle: String = "How did you hear about us?",
        sources: [String],
        accentColor: Color = .accentColor,
        property: String = "source",
        showSkip: Bool = true,
        skipLabel: String = "Skip",
        columns: Int? = nil,
        onComplete: @escaping (String?) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.sources = sources
        self.accentColor = accentColor
        self.property = property
        self.showSkip = showSkip
        self.skipLabel = skipLabel
        self.columns = columns
        self.onComplete = onComplete
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.bottom, 28)
                .padding(.horizontal, 24)

                // Source grid
                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(sources, id: \.self) { source in
                        sourceCard(source)
                    }
                }
                .padding(.horizontal, 20)

                // Skip button
                if showSkip {
                    Button {
                        onComplete(nil)
                    } label: {
                        Text(skipLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 24)
                    #if os(macOS)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    #endif
                }

                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grid Columns

    private var gridColumns: [GridItem] {
        let count = resolvedColumns
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    private var resolvedColumns: Int {
        if let columns { return max(1, columns) }
        #if os(macOS)
        return 2
        #else
        return sizeClass == .regular ? 2 : 1
        #endif
    }

    // MARK: - Source Card

    private func sourceCard(_ source: String) -> some View {
        let isSelected = selected == source
        let isHovered = isHovering == source

        return Button {
            guard selected == nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                selected = source
            }
            let normalized = normalize(source)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                Lumio.shared.identifyUser(property: property, value: normalized)
                onComplete(normalized)
            }
        } label: {
            HStack(spacing: 12) {
                Text(source)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(cardBackground(isSelected: isSelected, isHovered: isHovered))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? accentColor.opacity(0.3) : Color.primary.opacity(isHovered ? 0.15 : 0.08),
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(selected != nil && !isSelected)
        .opacity(selected != nil && !isSelected ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: selected)
        #if os(macOS)
        .onHover { hovering in
            isHovering = hovering ? source : nil
        }
        #endif
    }

    @ViewBuilder
    private func cardBackground(isSelected: Bool, isHovered: Bool) -> some View {
        if isSelected {
            accentColor
        } else if isHovered {
            #if os(macOS)
            Color.primary.opacity(0.04)
            #else
            Color.clear
            #endif
        } else {
            #if os(iOS)
            Color(.secondarySystemGroupedBackground)
            #else
            Color(nsColor: .controlBackgroundColor)
            #endif
        }
    }

    // MARK: - Helpers

    private func normalize(_ source: String) -> String {
        source
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 15.0, macOS 12.0, *)
struct SourcePickerView_Previews: PreviewProvider {
    static var previews: some View {
        GMSourcePickerView(
            sources: ["TikTok", "Instagram", "App Store Search", "Reddit", "YouTube", "Friend", "Other"],
            onComplete: { print("Selected: \($0 ?? "skipped")") }
        )
    }
}
#endif

#endif // canImport(SwiftUI)
