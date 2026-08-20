import Foundation

/// A single plugin's data as consumed by the Insights dashboard's analysis layer.
struct InsightPlugin: Sendable {
    let name: String
    let vendorName: String
    let format: PluginFormat
    let category: PluginCategory
    let fileSize: Int64
}

/// An immutable, precomputed snapshot of aggregate statistics for a collection
/// of plugins, backing the "Insights" dashboard.
struct InsightsData: Sendable {

    struct FormatCount: Sendable, Identifiable {
        let format: PluginFormat
        let count: Int
        var id: String { format.rawValue }
    }

    struct CategoryCount: Sendable, Identifiable {
        let category: PluginCategory
        let count: Int
        var id: String { category.rawValue }
    }

    struct ManufacturerCount: Sendable, Identifiable {
        let name: String
        let count: Int
        var id: String { name }
    }

    let pluginCount: Int
    let manufacturerCount: Int
    let totalSizeBytes: Int64
    let formatCounts: [FormatCount]
    let categoryCounts: [CategoryCount]
    let manufacturersRanked: [ManufacturerCount]

    static func build(from plugins: [InsightPlugin]) -> InsightsData {
        let pluginCount = plugins.count
        let totalSizeBytes = plugins.reduce(Int64(0)) { $0 + $1.fileSize }

        var vendorTally: [String: Int] = [:]
        var formatTally: [PluginFormat: Int] = [:]
        var categoryTally: [PluginCategory: Int] = [:]

        for plugin in plugins {
            vendorTally[plugin.vendorName, default: 0] += 1
            formatTally[plugin.format, default: 0] += 1
            categoryTally[plugin.category, default: 0] += 1
        }

        let formatCounts = formatTally
            .map { FormatCount(format: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.format.displayName < rhs.format.displayName
            }

        let categoryCounts = categoryTally
            .map { CategoryCount(category: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.category.displayName < rhs.category.displayName
            }

        let manufacturersRanked = vendorTally
            .map { ManufacturerCount(name: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.name < rhs.name
            }

        return InsightsData(
            pluginCount: pluginCount,
            manufacturerCount: vendorTally.count,
            totalSizeBytes: totalSizeBytes,
            formatCounts: formatCounts,
            categoryCounts: categoryCounts,
            manufacturersRanked: manufacturersRanked
        )
    }

    func topManufacturers(_ limit: Int) -> [ManufacturerCount] {
        guard limit > 0 else { return [] }
        return Array(manufacturersRanked.prefix(limit))
    }
}
