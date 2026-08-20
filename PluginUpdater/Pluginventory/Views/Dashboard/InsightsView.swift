import SwiftUI
import Charts

/// A library-analytics view (Plugoff-style "Insights"): overview totals plus
/// breakdowns by format, category, and manufacturer.
struct InsightsView: View {
    let data: InsightsData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statTiles
                if !data.formatCounts.isEmpty {
                    chartCard(title: "Formats") {
                        Chart(data.formatCounts) { item in
                            BarMark(
                                x: .value("Count", item.count),
                                y: .value("Format", item.format.displayName)
                            )
                            .foregroundStyle(.blue)
                            .annotation(position: .trailing, alignment: .leading) {
                                Text("\(item.count)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .chartXAxis(.hidden)
                        .frame(height: chartHeight(data.formatCounts.count))
                    }
                }
                if !data.categoryCounts.isEmpty {
                    chartCard(title: "Categories") {
                        Chart(data.categoryCounts) { item in
                            BarMark(
                                x: .value("Count", item.count),
                                y: .value("Category", item.category.displayName)
                            )
                            .foregroundStyle(.green)
                            .annotation(position: .trailing, alignment: .leading) {
                                Text("\(item.count)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .chartXAxis(.hidden)
                        .frame(height: chartHeight(data.categoryCounts.count))
                    }
                }
                if !data.manufacturersRanked.isEmpty {
                    chartCard(title: "Top Manufacturers") {
                        Chart(data.topManufacturers(12)) { item in
                            BarMark(
                                x: .value("Count", item.count),
                                y: .value("Manufacturer", item.name)
                            )
                            .foregroundStyle(.purple)
                            .annotation(position: .trailing, alignment: .leading) {
                                Text("\(item.count)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .chartXAxis(.hidden)
                        .frame(height: chartHeight(min(data.manufacturersRanked.count, 12)))
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 560, minHeight: 520)
        .navigationTitle("Insights")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func chartHeight(_ rows: Int) -> CGFloat {
        max(80, CGFloat(rows) * 30)
    }

    private var statTiles: some View {
        HStack(spacing: 12) {
            StatTile(title: "Plugins", value: "\(data.pluginCount)", systemImage: "puzzlepiece.extension")
            StatTile(title: "Manufacturers", value: "\(data.manufacturerCount)", systemImage: "building.2")
            StatTile(
                title: "Total Size",
                value: ByteCountFormatter.string(fromByteCount: data.totalSizeBytes, countStyle: .file),
                systemImage: "internaldrive"
            )
        }
    }

    @ViewBuilder
    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
