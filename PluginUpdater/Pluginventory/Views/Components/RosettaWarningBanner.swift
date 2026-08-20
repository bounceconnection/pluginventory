import SwiftUI

/// A warning banner shown when the library contains plugins that will stop
/// working once macOS 28 removes Rosetta 2 (Intel-only or legacy binaries).
///
/// Mirrors the prominent macOS 28 / Rosetta notice in PluginHub.
struct RosettaWarningBanner: View {
    let count: Int
    let onView: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 1) {
                Text("^[\(count) plugin](inflect: true) won't work in macOS 28")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Apple is retiring Rosetta, so these Intel-only plugins stop working when you update.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            Spacer()
            Button("View", action: onView)
                .buttonStyle(.bordered)
                .tint(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(red: 0.62, green: 0.16, blue: 0.14))
    }
}
