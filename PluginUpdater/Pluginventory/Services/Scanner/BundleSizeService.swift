import Foundation

/// Computes plugin bundle sizes off the scan critical path.
///
/// Summing every file inside every bundle is expensive — audio plugins ship large
/// sample, preset, and wavetable trees, so a full library can be tens of gigabytes
/// across hundreds of thousands of files. Doing that during the scan was the single
/// biggest source of slow scans. This service moves that work into a background pass
/// and caches each result against the bundle's modification date, so a rescan only
/// re-walks bundles that actually changed.
actor BundleSizeService {

    /// A request to (re)compute the size of a single bundle.
    struct SizeRequest: Sendable {
        /// Filesystem path of the bundle. Also used as the result key.
        let path: String
        /// Modification date the cached size was computed for, if any.
        let cachedMtime: Date?
        /// Previously computed size in bytes (0 if never computed).
        let cachedSize: Int64
    }

    /// The resolved size of a bundle plus the modification date it was computed for.
    struct SizeResult: Sendable {
        let size: Int64
        let mtime: Date?
    }

    private let concurrency: Int

    init(concurrency: Int = Constants.Defaults.scanConcurrency) {
        self.concurrency = concurrency
    }

    // MARK: - Public

    /// Resolves sizes for the given requests, keyed by `path`.
    ///
    /// For each request the bundle's current modification date is read (one cheap stat).
    /// If it matches `cachedMtime` and a cached size exists, the cached size is returned
    /// without walking the bundle. Otherwise the bundle is walked to compute a fresh size.
    /// Runs with bounded concurrency to avoid saturating the filesystem.
    func computeSizes(_ requests: [SizeRequest]) async -> [String: SizeResult] {
        guard !requests.isEmpty else { return [:] }

        var results: [String: SizeResult] = [:]
        results.reserveCapacity(requests.count)

        await withTaskGroup(of: (String, SizeResult).self) { group in
            var inFlight = 0

            for request in requests {
                if inFlight >= concurrency {
                    if let (path, result) = await group.next() {
                        results[path] = result
                        inFlight -= 1
                    }
                }

                group.addTask {
                    (request.path, Self.resolve(request))
                }
                inFlight += 1
            }

            for await (path, result) in group {
                results[path] = result
            }
        }

        return results
    }

    // MARK: - Private

    /// Resolves a single request, honoring the modification-date cache.
    private static func resolve(_ request: SizeRequest) -> SizeResult {
        let url = URL(fileURLWithPath: request.path)
        let currentMtime = modificationDate(of: url)

        // Cache hit: unchanged bundle with a previously computed size.
        if let cached = request.cachedMtime,
           let current = currentMtime,
           cached == current,
           request.cachedSize > 0 {
            return SizeResult(size: request.cachedSize, mtime: current)
        }

        let size = directorySize(at: url)
        return SizeResult(size: size, mtime: currentMtime)
    }

    /// The bundle's content modification date, or `nil` if unavailable.
    static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// Recursively sums the size of every regular file in a directory tree.
    ///
    /// Uses the values prefetched by the enumerator rather than re-stat'ing each file,
    /// and prefers total-allocated size (what the file actually occupies on disk),
    /// falling back to logical file size.
    static func directorySize(at url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isRegularFile == false { continue }
            if let allocated = values.totalFileAllocatedSize {
                total += Int64(allocated)
            } else if let logical = values.fileSize {
                total += Int64(logical)
            }
        }
        return total
    }
}
