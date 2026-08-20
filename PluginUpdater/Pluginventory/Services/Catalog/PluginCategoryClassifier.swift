import Foundation

// MARK: - CategoryMapping

/// A single rule used by ``PluginCategoryClassifier`` to map a plugin onto a
/// ``PluginCategory``. `match` is compared case-insensitively against the plugin
/// attribute named by `field`.
struct CategoryMapping: Codable, Sendable {

    // MARK: - MatchField

    /// The plugin attribute a ``CategoryMapping`` is tested against.
    enum MatchField: String, Codable, Sendable {
        case bundleIDPrefix
        case vendor
        case nameKeyword
    }

    let match: String
    let field: MatchField
    let category: PluginCategory
}

// MARK: - PluginCategoryClassifier

/// Classifies audio plugins into a ``PluginCategory`` using an ordered set of
/// rules (bundle-id prefix, exact vendor, name keyword) with a built-in keyword
/// heuristic as a final fallback.
struct PluginCategoryClassifier: Sendable {

    // MARK: - Properties

    private let mappings: [CategoryMapping]

    // MARK: - Initialization

    init(mappings: [CategoryMapping]) {
        self.mappings = mappings
    }

    // MARK: - Loading

    /// Loads mappings from `plugin_categories.json` in the app bundle, falling
    /// back to ``defaultMappings`` when the file is missing or undecodable.
    static func loadFromBundle() -> PluginCategoryClassifier {
        guard let url = Bundle.main.url(forResource: "plugin_categories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([CategoryMapping].self, from: data) else {
            return PluginCategoryClassifier(mappings: defaultMappings)
        }
        return PluginCategoryClassifier(mappings: decoded)
    }

    // MARK: - Classification

    /// Resolves the best ``PluginCategory`` for a plugin.
    ///
    /// Resolution order:
    /// 1. Longest matching `bundleIDPrefix` (case-insensitive `hasPrefix`).
    /// 2. Exact `vendor` match (case-insensitive).
    /// 3. First `nameKeyword` contained in `name` (case-insensitive).
    /// 4. Built-in keyword heuristic on `name`.
    /// 5. ``PluginCategory/uncategorized`` when nothing matches.
    func classify(bundleID: String, vendorName: String, name: String) -> PluginCategory {
        let loweredBundleID = bundleID.lowercased()
        let loweredVendor = vendorName.lowercased()
        let loweredName = name.lowercased()

        // 1. Longest matching bundle-id prefix wins.
        if let category = longestBundleIDPrefixMatch(loweredBundleID: loweredBundleID) {
            return category
        }

        // 2. Exact vendor match.
        if !loweredVendor.isEmpty {
            for mapping in mappings where mapping.field == .vendor {
                if mapping.match.lowercased() == loweredVendor {
                    return mapping.category
                }
            }
        }

        // 3. First name-keyword contained in the plugin name.
        for mapping in mappings where mapping.field == .nameKeyword {
            let keyword = mapping.match.lowercased()
            if !keyword.isEmpty, loweredName.contains(keyword) {
                return mapping.category
            }
        }

        // 4. Built-in keyword heuristic.
        if let category = Self.heuristicCategory(forLoweredName: loweredName) {
            return category
        }

        // 5. Nothing matched.
        return .uncategorized
    }

    // MARK: - Private Helpers

    /// Returns the category of the longest `bundleIDPrefix` mapping whose match
    /// is a case-insensitive prefix of the bundle identifier, or `nil`.
    private func longestBundleIDPrefixMatch(loweredBundleID: String) -> PluginCategory? {
        guard !loweredBundleID.isEmpty else { return nil }
        var bestCategory: PluginCategory?
        var bestLength = 0
        for mapping in mappings where mapping.field == .bundleIDPrefix {
            let prefix = mapping.match.lowercased()
            guard !prefix.isEmpty, loweredBundleID.hasPrefix(prefix) else { continue }
            if prefix.count > bestLength {
                bestLength = prefix.count
                bestCategory = mapping.category
            }
        }
        return bestCategory
    }

    /// A small, order-sensitive keyword heuristic applied to a lowercased name.
    private static func heuristicCategory(forLoweredName name: String) -> PluginCategory? {
        for entry in heuristicKeywords where name.contains(entry.keyword) {
            return entry.category
        }
        return nil
    }

    /// Ordered heuristic keywords. Earlier entries take precedence when several
    /// of these substrings appear in the same name.
    private static let heuristicKeywords: [(keyword: String, category: PluginCategory)] = [
        ("reverb", .reverb),
        ("delay", .delay),
        ("equali", .eq),
        ("eq", .eq),
        ("comp", .compressor),
        ("limit", .dynamics),
        ("gate", .dynamics),
        ("saturat", .saturation),
        ("tape", .saturation),
        ("distort", .distortion),
        ("chorus", .modulation),
        ("flanger", .modulation),
        ("phaser", .modulation),
        ("synth", .synth),
        ("piano", .synth),
        ("keys", .synth),
        ("drum", .drums),
        ("meter", .metering),
        ("loudness", .metering),
        ("lufs", .metering),
        ("analy", .analyzer),
        ("spectrum", .analyzer),
        ("amp", .guitarAmp),
        ("cab", .guitarAmp),
        ("master", .mastering),
    ]

    // MARK: - Default Mappings

    /// Built-in starter mappings, used when the bundled JSON is unavailable.
    /// Kept in sync with `Resources/plugin_categories.json`.
    static let defaultMappings: [CategoryMapping] = [
        CategoryMapping(match: "com.fabfilter.Pro-Q", field: .bundleIDPrefix, category: .eq),
        CategoryMapping(match: "com.fabfilter.Pro-C", field: .bundleIDPrefix, category: .compressor),
        CategoryMapping(match: "com.fabfilter.Pro-DS", field: .bundleIDPrefix, category: .dynamics),
        CategoryMapping(match: "com.fabfilter.Pro-G", field: .bundleIDPrefix, category: .dynamics),
        CategoryMapping(match: "com.fabfilter.Pro-MB", field: .bundleIDPrefix, category: .compressor),
        CategoryMapping(match: "com.fabfilter.Pro-L", field: .bundleIDPrefix, category: .dynamics),
        CategoryMapping(match: "com.fabfilter.Pro-R", field: .bundleIDPrefix, category: .reverb),
        CategoryMapping(match: "com.fabfilter.Saturn", field: .bundleIDPrefix, category: .saturation),
        CategoryMapping(match: "com.fabfilter.Timeless", field: .bundleIDPrefix, category: .delay),
        CategoryMapping(match: "com.fabfilter.Volcano", field: .bundleIDPrefix, category: .filter),
        CategoryMapping(match: "com.fabfilter.Simplon", field: .bundleIDPrefix, category: .filter),
        CategoryMapping(match: "com.fabfilter.Twin", field: .bundleIDPrefix, category: .synth),
        CategoryMapping(match: "com.izotope.Ozone", field: .bundleIDPrefix, category: .mastering),
        CategoryMapping(match: "com.izotope.Insight", field: .bundleIDPrefix, category: .metering),
        CategoryMapping(match: "com.izotope.Neutron", field: .bundleIDPrefix, category: .channelStrip),
        CategoryMapping(match: "com.izotope.Nectar", field: .bundleIDPrefix, category: .channelStrip),
        CategoryMapping(match: "com.izotope.RX", field: .bundleIDPrefix, category: .noiseReduction),
        CategoryMapping(match: "com.izotope.Trash", field: .bundleIDPrefix, category: .distortion),
        CategoryMapping(match: "com.izotope.VocalSynth", field: .bundleIDPrefix, category: .creative),
        CategoryMapping(match: "com.ValhallaDSP.", field: .bundleIDPrefix, category: .reverb),
        CategoryMapping(match: "com.ValhallaDSP.ValhallaDelay", field: .bundleIDPrefix, category: .delay),
        CategoryMapping(match: "com.ValhallaDSP.ValhallaFreqEcho", field: .bundleIDPrefix, category: .delay),
        CategoryMapping(match: "com.ValhallaDSP.ValhallaSpaceModulator", field: .bundleIDPrefix, category: .modulation),
        CategoryMapping(match: "com.ValhallaDSP.ValhallaSupermassive", field: .bundleIDPrefix, category: .reverb),
        CategoryMapping(match: "com.soundtoys.", field: .bundleIDPrefix, category: .creative),
        CategoryMapping(match: "com.soundtoys.EchoBoy", field: .bundleIDPrefix, category: .delay),
        CategoryMapping(match: "com.soundtoys.Decapitator", field: .bundleIDPrefix, category: .saturation),
        CategoryMapping(match: "com.soundtoys.PhaseMistress", field: .bundleIDPrefix, category: .modulation),
        CategoryMapping(match: "com.soundtoys.MicroShift", field: .bundleIDPrefix, category: .pitch),
        CategoryMapping(match: "com.native-instruments.Massive", field: .bundleIDPrefix, category: .synth),
        CategoryMapping(match: "com.native-instruments.Absynth", field: .bundleIDPrefix, category: .synth),
        CategoryMapping(match: "com.native-instruments.FM8", field: .bundleIDPrefix, category: .synth),
        CategoryMapping(match: "com.native-instruments.Kontakt", field: .bundleIDPrefix, category: .sampler),
        CategoryMapping(match: "com.native-instruments.Battery", field: .bundleIDPrefix, category: .drums),
        CategoryMapping(match: "com.native-instruments.GuitarRig", field: .bundleIDPrefix, category: .guitarAmp),
        CategoryMapping(match: "com.xferrecords.serum", field: .bundleIDPrefix, category: .synth),
        CategoryMapping(match: "com.xferrecords.LFOTool", field: .bundleIDPrefix, category: .modulation),
        CategoryMapping(match: "com.xferrecords.OTT", field: .bundleIDPrefix, category: .compressor),
        CategoryMapping(match: "com.u-he.", field: .bundleIDPrefix, category: .synth),
        CategoryMapping(match: "com.u-he.Presswerk", field: .bundleIDPrefix, category: .compressor),
        CategoryMapping(match: "com.u-he.Satin", field: .bundleIDPrefix, category: .saturation),
        CategoryMapping(match: "com.u-he.ColourCopy", field: .bundleIDPrefix, category: .delay),
        CategoryMapping(match: "com.spectrasonics.Omnisphere", field: .bundleIDPrefix, category: .synth),
        CategoryMapping(match: "com.spectrasonics.Keyscape", field: .bundleIDPrefix, category: .synth),
        CategoryMapping(match: "com.spectrasonics.Stylus", field: .bundleIDPrefix, category: .drums),
        CategoryMapping(match: "com.oeksound.soothe", field: .bundleIDPrefix, category: .dynamics),
        CategoryMapping(match: "com.oeksound.spiff", field: .bundleIDPrefix, category: .dynamics),
        CategoryMapping(match: "com.antarestech.AutoTune", field: .bundleIDPrefix, category: .pitch),
        CategoryMapping(match: "com.celemony.Melodyne", field: .bundleIDPrefix, category: .pitch),
        CategoryMapping(match: "com.toguaudioline.", field: .bundleIDPrefix, category: .synth),
        CategoryMapping(match: "com.toguaudioline.TAL-Reverb", field: .bundleIDPrefix, category: .reverb),
        CategoryMapping(match: "com.toontrack.EZdrummer", field: .bundleIDPrefix, category: .drums),
        CategoryMapping(match: "com.toontrack.Superior", field: .bundleIDPrefix, category: .drums),
        CategoryMapping(match: "com.xlnaudio.AddictiveDrums", field: .bundleIDPrefix, category: .drums),
        CategoryMapping(match: "com.eventide.", field: .bundleIDPrefix, category: .reverb),
        CategoryMapping(match: "com.eventide.Blackhole", field: .bundleIDPrefix, category: .reverb),
        CategoryMapping(match: "com.arturia.", field: .bundleIDPrefix, category: .synth),
        CategoryMapping(match: "com.cableguys.", field: .bundleIDPrefix, category: .modulation),
        CategoryMapping(match: "com.kilohearts.", field: .bundleIDPrefix, category: .creative),
        CategoryMapping(match: "com.output.", field: .bundleIDPrefix, category: .creative),
        CategoryMapping(match: "com.softube.", field: .bundleIDPrefix, category: .saturation),
        CategoryMapping(match: "com.slatedigital.", field: .bundleIDPrefix, category: .channelStrip),
        CategoryMapping(match: "com.sonnox.", field: .bundleIDPrefix, category: .mastering),
        CategoryMapping(match: "Arturia", field: .vendor, category: .synth),
        CategoryMapping(match: "u-he", field: .vendor, category: .synth),
        CategoryMapping(match: "Xfer Records", field: .vendor, category: .synth),
        CategoryMapping(match: "Cableguys", field: .vendor, category: .modulation),
        CategoryMapping(match: "Softube", field: .vendor, category: .saturation),
        CategoryMapping(match: "Sonnox", field: .vendor, category: .mastering),
        CategoryMapping(match: "Waves", field: .vendor, category: .dynamics),
        CategoryMapping(match: "Slate Digital", field: .vendor, category: .channelStrip),
        CategoryMapping(match: "Plugin Alliance", field: .vendor, category: .channelStrip),
        CategoryMapping(match: "Spitfire Audio", field: .vendor, category: .sampler),
        CategoryMapping(match: "Output", field: .vendor, category: .creative),
        CategoryMapping(match: "Kilohearts", field: .vendor, category: .creative),
        CategoryMapping(match: "Valhalla DSP", field: .vendor, category: .reverb),
        CategoryMapping(match: "Newfangled Audio", field: .vendor, category: .mastering),
        CategoryMapping(match: "MeldaProduction", field: .vendor, category: .utility),
        CategoryMapping(match: "Tokyo Dawn Labs", field: .vendor, category: .dynamics),
        CategoryMapping(match: "Klanghelm", field: .vendor, category: .compressor),
        CategoryMapping(match: "Spectrasonics", field: .vendor, category: .synth),
        CategoryMapping(match: "Toontrack", field: .vendor, category: .drums),
        CategoryMapping(match: "reFX", field: .vendor, category: .synth),
        CategoryMapping(match: "Roland", field: .vendor, category: .synth),
        CategoryMapping(match: "KORG", field: .vendor, category: .synth),
        CategoryMapping(match: "Antares", field: .vendor, category: .pitch),
        CategoryMapping(match: "Celemony", field: .vendor, category: .pitch),
        CategoryMapping(match: "Oeksound", field: .vendor, category: .dynamics),
        CategoryMapping(match: "de-esser", field: .nameKeyword, category: .dynamics),
        CategoryMapping(match: "transient", field: .nameKeyword, category: .dynamics),
        CategoryMapping(match: "maximizer", field: .nameKeyword, category: .mastering),
        CategoryMapping(match: "exciter", field: .nameKeyword, category: .saturation),
        CategoryMapping(match: "bitcrush", field: .nameKeyword, category: .creative),
        CategoryMapping(match: "vocoder", field: .nameKeyword, category: .creative),
        CategoryMapping(match: "convolution", field: .nameKeyword, category: .reverb),
    ]
}
