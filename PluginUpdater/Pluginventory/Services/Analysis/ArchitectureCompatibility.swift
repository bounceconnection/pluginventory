/// A namespace of pure functions that classify a binary's CPU architecture
/// slices and determine how it will fare once Apple retires Rosetta 2 in macOS 28.
enum ArchitectureCompatibility {

    static func isUniversal(_ archs: [CPUArchitecture]) -> Bool {
        archs.contains(.arm64) && archs.contains(.x86_64)
    }

    static func isAppleSiliconNative(_ archs: [CPUArchitecture]) -> Bool {
        archs.contains(.arm64)
    }

    static func isIntelOnly(_ archs: [CPUArchitecture]) -> Bool {
        archs.contains(.x86_64) && !archs.contains(.arm64)
    }

    static func requiresRosetta(_ archs: [CPUArchitecture]) -> Bool {
        guard !archs.contains(.arm64) else { return false }
        return archs.contains(.x86_64)
            || archs.contains(.i386)
            || archs.contains(.ppc)
    }

    static func breaksInMacOS28(_ archs: [CPUArchitecture]) -> Bool {
        requiresRosetta(archs)
    }

    static func compatibilityReason(_ archs: [CPUArchitecture]) -> String? {
        guard breaksInMacOS28(archs) else { return nil }
        if archs.contains(.i386) || archs.contains(.ppc) {
            return "Legacy 32-bit/PowerPC — won't run on modern macOS"
        }
        return "Intel-only — needs Rosetta, which Apple removes in macOS 28"
    }
}

/// A roll-up of how many plugins will stop working once macOS 28 removes Rosetta 2.
struct RosettaSunsetSummary: Sendable {
    let brokenCount: Int
    let total: Int

    static func summarize(_ archLists: [[CPUArchitecture]]) -> RosettaSunsetSummary {
        let broken = archLists.filter { ArchitectureCompatibility.breaksInMacOS28($0) }.count
        return RosettaSunsetSummary(brokenCount: broken, total: archLists.count)
    }
}
