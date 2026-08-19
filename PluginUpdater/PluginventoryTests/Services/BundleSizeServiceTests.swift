import Testing
import Foundation
@testable import Pluginventory

@Suite("BundleSizeService Tests")
struct BundleSizeServiceTests {

    /// Creates a temporary directory containing files with the given byte lengths.
    /// Returns the directory URL; caller is responsible for cleanup.
    private func makeTree(fileByteCounts: [Int]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SizeServiceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for (index, count) in fileByteCounts.enumerated() {
            let fileURL = dir.appendingPathComponent("file-\(index).bin")
            let data = Data(repeating: 0xAB, count: count)
            try data.write(to: fileURL)
        }
        return dir
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - directorySize

    @Test("directorySize reflects the content written")
    func directorySizeSumsFiles() throws {
        let dir = try makeTree(fileByteCounts: [5_000, 3_000])
        defer { cleanup(dir) }

        let size = BundleSizeService.directorySize(at: dir)
        // Allocated size is >= logical content; never less.
        #expect(size >= 8_000)
    }

    @Test("directorySize recurses into subdirectories")
    func directorySizeRecurses() throws {
        let dir = try makeTree(fileByteCounts: [1_000])
        defer { cleanup(dir) }
        let sub = dir.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(repeating: 0xCD, count: 4_000).write(to: sub.appendingPathComponent("deep.bin"))

        let size = BundleSizeService.directorySize(at: dir)
        #expect(size >= 5_000)
    }

    @Test("directorySize is zero for a nonexistent directory")
    func directorySizeNonexistent() {
        let size = BundleSizeService.directorySize(at: URL(fileURLWithPath: "/nope/does/not/exist"))
        #expect(size == 0)
    }

    // MARK: - modificationDate

    @Test("modificationDate returns a date for an existing directory")
    func modificationDatePresent() throws {
        let dir = try makeTree(fileByteCounts: [10])
        defer { cleanup(dir) }
        #expect(BundleSizeService.modificationDate(of: dir) != nil)
    }

    // MARK: - computeSizes cache behavior

    @Test("Cache miss computes the real size")
    func cacheMissComputes() async throws {
        let dir = try makeTree(fileByteCounts: [6_000])
        defer { cleanup(dir) }

        let real = BundleSizeService.directorySize(at: dir)
        let service = BundleSizeService()
        let results = await service.computeSizes([
            .init(path: dir.path, cachedMtime: nil, cachedSize: 0)
        ])

        let result = try #require(results[dir.path])
        #expect(result.size == real)
        #expect(result.mtime != nil)
    }

    @Test("Cache hit returns the cached size without re-walking")
    func cacheHitReturnsCached() async throws {
        let dir = try makeTree(fileByteCounts: [6_000])
        defer { cleanup(dir) }

        // Use the bundle's actual current mtime so the request is considered a hit.
        let mtime = try #require(BundleSizeService.modificationDate(of: dir))
        let bogusCachedSize: Int64 = 999_999_999

        let service = BundleSizeService()
        let results = await service.computeSizes([
            .init(path: dir.path, cachedMtime: mtime, cachedSize: bogusCachedSize)
        ])

        let result = try #require(results[dir.path])
        // Returns the (bogus) cached size, proving it did not re-walk the tree.
        #expect(result.size == bogusCachedSize)
        #expect(result.mtime == mtime)
    }

    @Test("Stale cache (mtime mismatch) recomputes")
    func staleCacheRecomputes() async throws {
        let dir = try makeTree(fileByteCounts: [6_000])
        defer { cleanup(dir) }

        let real = BundleSizeService.directorySize(at: dir)
        let staleDate = Date(timeIntervalSince1970: 0)
        let bogusCachedSize: Int64 = 999_999_999

        let service = BundleSizeService()
        let results = await service.computeSizes([
            .init(path: dir.path, cachedMtime: staleDate, cachedSize: bogusCachedSize)
        ])

        let result = try #require(results[dir.path])
        #expect(result.size == real)
        #expect(result.size != bogusCachedSize)
    }

    @Test("Empty request list returns empty results")
    func emptyRequests() async {
        let service = BundleSizeService()
        let results = await service.computeSizes([])
        #expect(results.isEmpty)
    }

    @Test("Resolves multiple bundles keyed by path")
    func multipleBundles() async throws {
        let dirA = try makeTree(fileByteCounts: [2_000])
        let dirB = try makeTree(fileByteCounts: [7_000])
        defer { cleanup(dirA); cleanup(dirB) }

        let service = BundleSizeService()
        let results = await service.computeSizes([
            .init(path: dirA.path, cachedMtime: nil, cachedSize: 0),
            .init(path: dirB.path, cachedMtime: nil, cachedSize: 0)
        ])

        #expect(results.count == 2)
        #expect((results[dirA.path]?.size ?? 0) >= 2_000)
        #expect((results[dirB.path]?.size ?? 0) >= 7_000)
    }
}
