import Testing
import Foundation
@testable import Pluginventory

@Suite("InsightsData Tests")
struct InsightsDataTests {

    private func makePlugin(
        name: String = "Plugin",
        vendor: String,
        format: PluginFormat,
        category: PluginCategory,
        fileSize: Int64 = 0
    ) -> InsightPlugin {
        InsightPlugin(name: name, vendorName: vendor, format: format, category: category, fileSize: fileSize)
    }

    @Test("pluginCount and totalSizeBytes sum correctly")
    func countAndTotalSize() {
        let plugins = [
            makePlugin(vendor: "Acme", format: .vst3, category: .synth, fileSize: 100),
            makePlugin(vendor: "Beta", format: .au, category: .reverb, fileSize: 250),
            makePlugin(vendor: "Gamma", format: .clap, category: .delay, fileSize: 50)
        ]
        let data = InsightsData.build(from: plugins)
        #expect(data.pluginCount == 3)
        #expect(data.totalSizeBytes == 400)
    }

    @Test("manufacturerCount counts distinct vendors")
    func distinctVendors() {
        let plugins = [
            makePlugin(vendor: "Acme", format: .vst3, category: .synth),
            makePlugin(vendor: "Acme", format: .au, category: .reverb),
            makePlugin(vendor: "Beta", format: .clap, category: .delay)
        ]
        let data = InsightsData.build(from: plugins)
        #expect(data.pluginCount == 3)
        #expect(data.manufacturerCount == 2)
    }

    @Test("formatCounts aggregates and excludes zero-count formats")
    func formatAggregation() throws {
        let plugins = [
            makePlugin(vendor: "Acme", format: .vst3, category: .synth),
            makePlugin(vendor: "Beta", format: .vst3, category: .reverb),
            makePlugin(vendor: "Gamma", format: .au, category: .delay)
        ]
        let data = InsightsData.build(from: plugins)
        #expect(data.formatCounts.count == 2)
        #expect(!data.formatCounts.contains { $0.format == .clap })
        let first = try #require(data.formatCounts.first)
        #expect(first.format == .vst3)
        #expect(first.count == 2)
    }

    @Test("categoryCounts excludes empty categories and sorts by count desc")
    func categoryAggregation() throws {
        let plugins = [
            makePlugin(vendor: "Acme", format: .vst3, category: .reverb),
            makePlugin(vendor: "Beta", format: .au, category: .reverb),
            makePlugin(vendor: "Gamma", format: .clap, category: .reverb),
            makePlugin(vendor: "Delta", format: .vst2, category: .synth)
        ]
        let data = InsightsData.build(from: plugins)
        #expect(data.categoryCounts.count == 2)
        let first = try #require(data.categoryCounts.first)
        #expect(first.category == .reverb)
        #expect(first.count == 3)
    }

    @Test("manufacturersRanked sorts by count desc then name asc")
    func manufacturerRankingAndTieBreak() throws {
        let plugins = [
            makePlugin(vendor: "Zephyr", format: .vst3, category: .synth),
            makePlugin(vendor: "Apex", format: .au, category: .reverb),
            makePlugin(vendor: "Apex", format: .clap, category: .delay)
        ]
        let data = InsightsData.build(from: plugins)
        #expect(data.manufacturersRanked.map(\.name) == ["Apex", "Zephyr"])
    }

    @Test("topManufacturers respects the limit and ordering")
    func topManufacturersLimits() throws {
        let plugins = [
            makePlugin(vendor: "Acme", format: .vst3, category: .synth),
            makePlugin(vendor: "Acme", format: .au, category: .reverb),
            makePlugin(vendor: "Acme", format: .clap, category: .delay),
            makePlugin(vendor: "Beta", format: .vst3, category: .synth),
            makePlugin(vendor: "Beta", format: .au, category: .reverb),
            makePlugin(vendor: "Gamma", format: .vst2, category: .eq)
        ]
        let data = InsightsData.build(from: plugins)
        let top2 = data.topManufacturers(2)
        #expect(top2.count == 2)
        let firstTop = try #require(top2.first)
        #expect(firstTop.name == "Acme")
        #expect(data.topManufacturers(0).isEmpty)
        #expect(data.topManufacturers(-5).isEmpty)
        #expect(data.topManufacturers(1000).count == 3)
    }

    @Test("empty input yields zeroed values and empty arrays")
    func emptyInput() {
        let data = InsightsData.build(from: [])
        #expect(data.pluginCount == 0)
        #expect(data.manufacturerCount == 0)
        #expect(data.totalSizeBytes == 0)
        #expect(data.formatCounts.isEmpty)
        #expect(data.categoryCounts.isEmpty)
        #expect(data.manufacturersRanked.isEmpty)
    }
}
