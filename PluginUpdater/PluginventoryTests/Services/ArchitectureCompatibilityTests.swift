import Testing
import Foundation
@testable import Pluginventory

@Suite("ArchitectureCompatibility Tests")
struct ArchitectureCompatibilityTests {

    @Test("Universal binary is native, not Intel-only, and survives macOS 28")
    func universalBinary() {
        let archs: [CPUArchitecture] = [.arm64, .x86_64]
        #expect(ArchitectureCompatibility.isUniversal(archs))
        #expect(!ArchitectureCompatibility.isIntelOnly(archs))
        #expect(!ArchitectureCompatibility.breaksInMacOS28(archs))
        #expect(ArchitectureCompatibility.compatibilityReason(archs) == nil)
    }

    @Test("Intel-only binary requires Rosetta and breaks in macOS 28")
    func intelOnlyBinary() throws {
        let archs: [CPUArchitecture] = [.x86_64]
        #expect(ArchitectureCompatibility.isIntelOnly(archs))
        #expect(ArchitectureCompatibility.requiresRosetta(archs))
        #expect(ArchitectureCompatibility.breaksInMacOS28(archs))
        let reason = try #require(ArchitectureCompatibility.compatibilityReason(archs))
        #expect(reason.contains("Rosetta"))
    }

    @Test("Apple Silicon-only binary is native and survives macOS 28")
    func appleSiliconOnlyBinary() {
        let archs: [CPUArchitecture] = [.arm64]
        #expect(ArchitectureCompatibility.isAppleSiliconNative(archs))
        #expect(!ArchitectureCompatibility.breaksInMacOS28(archs))
    }

    @Test("Legacy i386 binary breaks and is flagged as legacy")
    func legacyIntel32Binary() throws {
        let archs: [CPUArchitecture] = [.i386]
        #expect(ArchitectureCompatibility.breaksInMacOS28(archs))
        let reason = try #require(ArchitectureCompatibility.compatibilityReason(archs))
        #expect(reason.contains("Legacy"))
    }

    @Test("Legacy PowerPC binary breaks and is flagged as legacy")
    func legacyPowerPCBinary() throws {
        let archs: [CPUArchitecture] = [.ppc]
        #expect(ArchitectureCompatibility.breaksInMacOS28(archs))
        let reason = try #require(ArchitectureCompatibility.compatibilityReason(archs))
        #expect(reason.contains("Legacy"))
    }

    @Test("Empty slice list is indeterminate and does not break")
    func emptySliceList() {
        let archs: [CPUArchitecture] = []
        #expect(!ArchitectureCompatibility.breaksInMacOS28(archs))
        #expect(ArchitectureCompatibility.compatibilityReason(archs) == nil)
    }

    @Test("Unknown-only slice list is indeterminate and does not break")
    func unknownOnlySliceList() {
        let archs: [CPUArchitecture] = [.unknown]
        #expect(!ArchitectureCompatibility.breaksInMacOS28(archs))
        #expect(ArchitectureCompatibility.compatibilityReason(archs) == nil)
    }

    @Test("Sunset summary counts only the plugins that break in macOS 28")
    func sunsetSummaryCountsBrokenPlugins() {
        let archLists: [[CPUArchitecture]] = [[.arm64, .x86_64], [.x86_64], [.arm64], [.i386]]
        let summary = RosettaSunsetSummary.summarize(archLists)
        #expect(summary.brokenCount == 2)
        #expect(summary.total == 4)
    }
}
