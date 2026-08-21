import Testing
import Foundation
@testable import Pluginventory

@Suite("PluginCategoryClassifier Tests")
struct PluginCategoryClassifierTests {

    // MARK: - Resolution Order

    @Test("Bundle-id prefix match wins over the name heuristic")
    func bundleIDPrefixBeatsKeyword() {
        let classifier = PluginCategoryClassifier(mappings: [
            CategoryMapping(match: "com.example.delaything", field: .bundleIDPrefix, category: .synth)
        ])
        // Name contains "delay" (heuristic -> .delay) but the prefix mapping wins.
        let result = classifier.classify(
            bundleID: "com.example.delaything.v1",
            vendorName: "",
            name: "Delay Thing"
        )
        #expect(result == .synth)
    }

    @Test("Exact vendor match is used when no prefix matches")
    func vendorMatch() {
        let classifier = PluginCategoryClassifier(mappings: [
            CategoryMapping(match: "Valhalla DSP", field: .vendor, category: .reverb)
        ])
        // Vendor comparison is case-insensitive.
        let result = classifier.classify(
            bundleID: "com.unknown.thing",
            vendorName: "valhalla dsp",
            name: "Mystery"
        )
        #expect(result == .reverb)
    }

    @Test("Vendor match takes precedence over name keyword and heuristic")
    func vendorBeatsNameKeyword() {
        let classifier = PluginCategoryClassifier(mappings: [
            CategoryMapping(match: "Acme", field: .vendor, category: .utility),
            CategoryMapping(match: "reverb", field: .nameKeyword, category: .creative)
        ])
        let result = classifier.classify(bundleID: "com.x.y", vendorName: "Acme", name: "Spring Reverb")
        #expect(result == .utility)
    }

    @Test("Name keyword match is used when no prefix or vendor matches")
    func nameKeywordMatch() {
        let classifier = PluginCategoryClassifier(mappings: [
            CategoryMapping(match: "vocoder", field: .nameKeyword, category: .creative)
        ])
        let result = classifier.classify(
            bundleID: "com.acme.x",
            vendorName: "Acme",
            name: "Robo Vocoder 3000"
        )
        #expect(result == .creative)
    }

    @Test("Name keyword mapping takes precedence over the built-in heuristic")
    func nameKeywordBeatsHeuristic() {
        // Deliberately map the "reverb" keyword to .creative; the heuristic would say .reverb.
        let classifier = PluginCategoryClassifier(mappings: [
            CategoryMapping(match: "reverb", field: .nameKeyword, category: .creative)
        ])
        let result = classifier.classify(bundleID: "", vendorName: "", name: "Spring Reverb")
        #expect(result == .creative)
    }

    // MARK: - Longest-Prefix Precedence

    @Test("Longest matching bundle-id prefix wins over a shorter one")
    func longestPrefixWins() {
        // Generic prefix listed first, specific one second — longest must still win.
        let classifier = PluginCategoryClassifier(mappings: [
            CategoryMapping(match: "com.valhalladsp.", field: .bundleIDPrefix, category: .reverb),
            CategoryMapping(match: "com.valhalladsp.valhalladelay", field: .bundleIDPrefix, category: .delay)
        ])
        let delay = classifier.classify(bundleID: "com.ValhallaDSP.ValhallaDelay", vendorName: "", name: "")
        let room = classifier.classify(bundleID: "com.ValhallaDSP.ValhallaRoom", vendorName: "", name: "")
        #expect(delay == .delay)
        #expect(room == .reverb)
    }

    // MARK: - Built-in Heuristic

    @Test("Built-in heuristic classifies by keyword when mappings are empty")
    func heuristicFallback() {
        let classifier = PluginCategoryClassifier(mappings: [])
        #expect(classifier.classify(bundleID: "x", vendorName: "y", name: "Big Reverb") == .reverb)
        #expect(classifier.classify(bundleID: "x", vendorName: "y", name: "Vintage Compressor") == .compressor)
        #expect(classifier.classify(bundleID: "x", vendorName: "y", name: "Tape Machine") == .saturation)
        #expect(classifier.classify(bundleID: "x", vendorName: "y", name: "Sub Bass Synth") == .synth)
        #expect(classifier.classify(bundleID: "x", vendorName: "y", name: "Loudness Meter") == .metering)
    }

    @Test("Heuristic keyword order resolves overlapping names deterministically")
    func heuristicOrdering() {
        let classifier = PluginCategoryClassifier(mappings: [])
        // "delay" is checked before "tape", so a tape-style delay resolves to .delay.
        #expect(classifier.classify(bundleID: "x", vendorName: "y", name: "Tape Delay") == .delay)
    }

    // MARK: - Fallback

    @Test("Unknown plugin falls back to uncategorized")
    func unknownIsUncategorized() {
        let classifier = PluginCategoryClassifier(mappings: [])
        let result = classifier.classify(bundleID: "com.x.y", vendorName: "Nobody", name: "Widget")
        #expect(result == .uncategorized)
    }

    // MARK: - Default Mappings

    @Test("Default mappings are populated")
    func defaultMappingsNonEmpty() {
        #expect(!PluginCategoryClassifier.defaultMappings.isEmpty)
    }

    @Test("Default mappings classify well-known plugins")
    func defaultMappingsClassify() {
        let classifier = PluginCategoryClassifier(mappings: PluginCategoryClassifier.defaultMappings)
        #expect(classifier.classify(bundleID: "com.fabfilter.Pro-C 2", vendorName: "FabFilter", name: "Pro-C 2") == .compressor)
        #expect(classifier.classify(bundleID: "com.izotope.RX 10", vendorName: "iZotope", name: "RX") == .noiseReduction)
        #expect(classifier.classify(bundleID: "com.example.unknown", vendorName: "Klanghelm", name: "MJUC") == .compressor)
        // Bundle-id comparison is case-insensitive.
        #expect(classifier.classify(bundleID: "COM.FABFILTER.PRO-Q", vendorName: "", name: "") == .eq)
    }

    @Test("Default mappings honor longest-prefix precedence for Valhalla")
    func defaultMappingsLongestPrefix() {
        let classifier = PluginCategoryClassifier(mappings: PluginCategoryClassifier.defaultMappings)
        #expect(classifier.classify(bundleID: "com.ValhallaDSP.ValhallaDelay", vendorName: "", name: "") == .delay)
        #expect(classifier.classify(bundleID: "com.ValhallaDSP.ValhallaRoom", vendorName: "", name: "") == .reverb)
    }

    // MARK: - CategoryMapping Codable

    @Test("CategoryMapping decodes from the bundled JSON shape")
    func categoryMappingDecodes() throws {
        let json = """
        [{"match":"com.fabfilter.Pro-Q","field":"bundleIDPrefix","category":"eq"}]
        """
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode([CategoryMapping].self, from: data)
        let first = try #require(decoded.first)
        #expect(first.match == "com.fabfilter.Pro-Q")
        #expect(first.field == .bundleIDPrefix)
        #expect(first.category == .eq)
    }

    // MARK: - PluginCategory

    @Test("Display names are human-readable")
    func displayNames() {
        #expect(PluginCategory.eq.displayName == "EQ")
        #expect(PluginCategory.channelStrip.displayName == "Channel Strip")
        #expect(PluginCategory.guitarAmp.displayName == "Guitar/Amp")
        #expect(PluginCategory.noiseReduction.displayName == "Noise Reduction")
        #expect(PluginCategory.uncategorized.displayName == "Uncategorized")
        #expect(PluginCategory.reverb.displayName == "Reverb")
    }

    @Test("Identifier equals raw value for every case")
    func identifierMatchesRawValue() {
        for category in PluginCategory.allCases {
            #expect(category.id == category.rawValue)
        }
        #expect(PluginCategory.allCases.contains(.uncategorized))
    }

    @Test("PluginCategory round-trips through Codable")
    func codableRoundTrip() throws {
        for category in PluginCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(PluginCategory.self, from: data)
            #expect(decoded == category)
        }
    }
}
