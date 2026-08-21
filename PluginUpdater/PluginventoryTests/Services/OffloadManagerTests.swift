import Testing
import Foundation
@testable import Pluginventory

@Suite("OffloadManager Tests")
struct OffloadManagerTests {

    // MARK: - Fixtures

    /// A fake bundle plus the temp roots that must be cleaned up afterwards.
    private struct Fixture {
        let manager: OffloadManager
        /// The fake plugin bundle (a directory with a file inside) to offload.
        let sourceBundle: URL
        /// The base temp directory containing everything; remove it to clean up.
        let root: URL
        /// The offload destination root the manager is pointed at.
        let offloadRoot: URL
    }

    /// Creates a fake plugin bundle (a directory containing one file) under a fresh
    /// temp source folder, alongside a fresh temp offload root and a manager pointed
    /// at that root. The caller must `cleanup` the returned fixture.
    private func makeFixture(bundleName: String = "TestPlugin.vst3") throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OffloadManagerTests-\(UUID().uuidString)")
        let sourceRoot = root.appendingPathComponent("source")
        let offloadRoot = root.appendingPathComponent("offload")

        let bundle = sourceRoot.appendingPathComponent(bundleName)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)

        // A file inside the bundle so it has a non-zero measured size.
        let payload = bundle.appendingPathComponent("payload.bin")
        try Data(repeating: 0xAB, count: 4_096).write(to: payload)

        let manager = OffloadManager(offloadRoot: offloadRoot)
        return Fixture(manager: manager, sourceBundle: bundle, root: root, offloadRoot: offloadRoot)
    }

    private func cleanup(_ fixture: Fixture) {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Runs an async throwing operation and returns the `OffloadError` it threw,
    /// or `nil` if it did not throw an `OffloadError`.
    private func caughtOffloadError(
        _ operation: () async throws -> Void
    ) async -> OffloadManager.OffloadError? {
        do {
            try await operation()
            return nil
        } catch let error as OffloadManager.OffloadError {
            return error
        } catch {
            return nil
        }
    }

    // MARK: - Offload

    @Test("offload moves the bundle into the offload root and returns a matching record")
    func offloadMovesBundle() async throws {
        let fixture = try makeFixture()
        defer { cleanup(fixture) }

        let record = try await fixture.manager.offload(bundleAt: fixture.sourceBundle)

        // The record describes the move accurately.
        #expect(record.bundleName == fixture.sourceBundle.lastPathComponent)
        #expect(record.sizeBytes > 0)
        #expect(record.originalPath == fixture.sourceBundle.path)

        // Source is gone; destination exists inside the offload root under the same name.
        #expect(exists(fixture.sourceBundle) == false)

        let offloadedURL = URL(fileURLWithPath: record.offloadedPath)
        #expect(exists(offloadedURL))
        #expect(offloadedURL.deletingLastPathComponent().path == fixture.offloadRoot.path)
        #expect(offloadedURL.lastPathComponent == fixture.sourceBundle.lastPathComponent)
    }

    // MARK: - Restore

    @Test("restore moves the bundle back to its original path")
    func restoreMovesBundleBack() async throws {
        let fixture = try makeFixture()
        defer { cleanup(fixture) }

        let record = try await fixture.manager.offload(bundleAt: fixture.sourceBundle)
        #expect(exists(fixture.sourceBundle) == false)

        try await fixture.manager.restore(record)

        // Back at the original location; the offloaded copy is gone.
        #expect(exists(URL(fileURLWithPath: record.originalPath)))
        #expect(exists(URL(fileURLWithPath: record.offloadedPath)) == false)
    }

    // MARK: - Error paths

    @Test("offloading a missing source throws sourceMissing")
    func offloadMissingSourceThrows() async throws {
        let fixture = try makeFixture()
        defer { cleanup(fixture) }

        let missing = fixture.root.appendingPathComponent("DoesNotExist.vst3")

        await #expect(throws: OffloadManager.OffloadError.self) {
            _ = try await fixture.manager.offload(bundleAt: missing)
        }
    }

    @Test("offloading into an occupied destination throws alreadyExists")
    func offloadDestinationOccupiedThrows() async throws {
        let fixture = try makeFixture()
        defer { cleanup(fixture) }

        // Pre-occupy the destination path inside the offload root.
        let destination = fixture.offloadRoot.appendingPathComponent(fixture.sourceBundle.lastPathComponent)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let error = await caughtOffloadError {
            _ = try await fixture.manager.offload(bundleAt: fixture.sourceBundle)
        }
        let offloadError = try #require(error)
        guard case .alreadyExists = offloadError else {
            Issue.record("Expected .alreadyExists, got \(offloadError)")
            return
        }

        // The guard fired before any move: the source is untouched.
        #expect(exists(fixture.sourceBundle))
    }

    @Test("restore into an occupied original location throws restoreTargetOccupied")
    func restoreTargetOccupiedThrows() async throws {
        let fixture = try makeFixture()
        defer { cleanup(fixture) }

        let record = try await fixture.manager.offload(bundleAt: fixture.sourceBundle)

        // Something now occupies the original location.
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: record.originalPath),
            withIntermediateDirectories: true
        )

        let error = await caughtOffloadError {
            try await fixture.manager.restore(record)
        }
        let offloadError = try #require(error)
        guard case .restoreTargetOccupied = offloadError else {
            Issue.record("Expected .restoreTargetOccupied, got \(offloadError)")
            return
        }

        // The offloaded copy is left in place when restore refuses.
        #expect(exists(URL(fileURLWithPath: record.offloadedPath)))
    }

    // MARK: - Queries

    @Test("isOffloaded is true after offload and false after restore")
    func isOffloadedReflectsState() async throws {
        let fixture = try makeFixture()
        defer { cleanup(fixture) }

        let record = try await fixture.manager.offload(bundleAt: fixture.sourceBundle)
        let afterOffload = await fixture.manager.isOffloaded(record)
        #expect(afterOffload)

        try await fixture.manager.restore(record)
        let afterRestore = await fixture.manager.isOffloaded(record)
        #expect(afterRestore == false)
    }
}
