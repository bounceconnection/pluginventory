import Foundation

/// A functional category an audio plugin can be classified into
/// (e.g. by ``PluginCategoryClassifier``).
enum PluginCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case synth
    case sampler
    case drums
    case eq
    case dynamics
    case compressor
    case saturation
    case distortion
    case reverb
    case delay
    case modulation
    case filter
    case pitch
    case mastering
    case metering
    case analyzer
    case channelStrip
    case utility
    case guitarAmp
    case noiseReduction
    case creative
    case uncategorized

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .synth: "Synth"
        case .sampler: "Sampler"
        case .drums: "Drums"
        case .eq: "EQ"
        case .dynamics: "Dynamics"
        case .compressor: "Compressor"
        case .saturation: "Saturation"
        case .distortion: "Distortion"
        case .reverb: "Reverb"
        case .delay: "Delay"
        case .modulation: "Modulation"
        case .filter: "Filter"
        case .pitch: "Pitch"
        case .mastering: "Mastering"
        case .metering: "Metering"
        case .analyzer: "Analyzer"
        case .channelStrip: "Channel Strip"
        case .utility: "Utility"
        case .guitarAmp: "Guitar/Amp"
        case .noiseReduction: "Noise Reduction"
        case .creative: "Creative"
        case .uncategorized: "Uncategorized"
        }
    }
}
