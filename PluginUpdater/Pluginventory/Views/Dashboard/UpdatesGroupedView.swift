import SwiftUI

/// One updatable plugin, as shown in the grouped updates view.
struct UpdateRowInfo: Identifiable {
    let id: String
    let name: String
    let currentVersion: String
    let availableVersion: String
    let downloadURL: String?
    let architectures: [CPUArchitecture]
}

/// Updatable plugins for a single vendor.
struct VendorUpdateGroup: Identifiable {
    let id: String
    let vendor: String
    let rows: [UpdateRowInfo]
}

/// PluginHub-style grouped list of available updates: one section per vendor,
/// each row showing the installed → available version diff, architecture chips,
/// and a download link.
struct UpdatesGroupedView: View {
    let groups: [VendorUpdateGroup]

    var body: some View {
        if groups.isEmpty {
            ContentUnavailableView(
                "No Updates Available",
                systemImage: "checkmark.circle",
                description: Text("All your plugins are up to date.")
            )
        } else {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.rows) { row in
                            UpdateRowView(row: row)
                        }
                    } header: {
                        Text("\(group.vendor) (\(group.rows.count))")
                    }
                }
            }
        }
    }
}

private struct UpdateRowView: View {
    let row: UpdateRowInfo

    var body: some View {
        HStack(spacing: 10) {
            Text(row.name)
                .frame(minWidth: 130, alignment: .leading)
            VersionDiffView(current: row.currentVersion, available: row.availableVersion)
            ArchChipView(architectures: row.architectures)
            Spacer()
            downloadLink
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var downloadLink: some View {
        if let urlString = row.downloadURL, let url = URL(string: urlString) {
            Link(destination: url) {
                Label("Get", systemImage: "arrow.down.circle")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct VersionDiffView: View {
    let current: String
    let available: String

    var body: some View {
        HStack(spacing: 4) {
            Text(current)
                .foregroundStyle(.secondary)
                .strikethrough()
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(available)
                .foregroundStyle(.green)
                .fontWeight(.semibold)
        }
        .font(.callout)
        .monospacedDigit()
    }
}

private struct ArchChipView: View {
    let architectures: [CPUArchitecture]

    var body: some View {
        if ArchitectureCompatibility.breaksInMacOS28(architectures) {
            chip("Intel-only", color: .orange)
        } else if ArchitectureCompatibility.isUniversal(architectures) {
            chip("Universal", color: .blue)
        } else if ArchitectureCompatibility.isAppleSiliconNative(architectures) {
            chip("Apple Silicon", color: .green)
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}
