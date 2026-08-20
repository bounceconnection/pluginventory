import Testing
import Foundation
@testable import Pluginventory

@Suite("OffloadedPlugin Tests")
struct OffloadedPluginTests {

    @Test("offloadRecord round-trips the stored fields")
    func recordRoundTrip() {
        let date = Date(timeIntervalSince1970: 1000)
        let item = OffloadedPlugin(
            name: "X", vendorName: "V", bundleIdentifier: "com.v.x", formatRaw: "vst3",
            originalPath: "/Library/Audio/Plug-Ins/VST3/X.vst3",
            offloadedPath: "/tmp/off/X.vst3", sizeBytes: 123, offloadedAt: date
        )
        let record = item.offloadRecord
        #expect(record.originalPath == "/Library/Audio/Plug-Ins/VST3/X.vst3")
        #expect(record.offloadedPath == "/tmp/off/X.vst3")
        #expect(record.bundleName == "X.vst3")
        #expect(record.sizeBytes == 123)
        #expect(record.offloadedAt == date)
        #expect(item.format == .vst3)
    }

    @Test("Offload then restore via manager using an OffloadedPlugin record")
    func offloadRestoreIntegration() async throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("OffloadInt-\(UUID().uuidString)")
        let installDir = tmp.appendingPathComponent("VST3")
        let offloadRoot = tmp.appendingPathComponent("Offload")
        try fm.createDirectory(at: installDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let bundle = installDir.appendingPathComponent("Test.vst3")
        try fm.createDirectory(at: bundle.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try Data(repeating: 0, count: 500).write(to: bundle.appendingPathComponent("Contents/x.bin"))

        let manager = OffloadManager(offloadRoot: offloadRoot)
        let record = try await manager.offload(bundleAt: bundle)
        #expect(!fm.fileExists(atPath: bundle.path))
        #expect(fm.fileExists(atPath: record.offloadedPath))

        let item = OffloadedPlugin(
            name: "Test", vendorName: "V", bundleIdentifier: "com.v.test", formatRaw: "vst3",
            originalPath: record.originalPath, offloadedPath: record.offloadedPath,
            sizeBytes: record.sizeBytes, offloadedAt: record.offloadedAt
        )
        try await manager.restore(item.offloadRecord)
        #expect(fm.fileExists(atPath: bundle.path))
        #expect(!fm.fileExists(atPath: record.offloadedPath))
    }
}
