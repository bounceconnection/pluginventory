import Foundation

/// A durable record of a single offloaded plugin bundle.
///
/// Offloading *moves* a plugin bundle out of its install location into a separate
/// offload folder to reclaim disk space. Everything needed to move the bundle back
/// to exactly where it came from is captured here, so the record can be persisted
/// (it is `Codable`) and later handed back to ``OffloadManager/restore(_:)``.
struct OffloadRecord: Codable, Sendable, Equatable {

    /// Absolute path the bundle occupied before it was offloaded. This is the restore target.
    let originalPath: String

    /// Absolute path the bundle currently occupies inside the offload folder.
    let offloadedPath: String

    /// The bundle's file name (e.g. `"Pro-Q 3.vst3"`) — the source's last path component.
    let bundleName: String

    /// Size of the bundle in bytes, measured at the moment it was offloaded.
    let sizeBytes: Int64

    /// When the bundle was offloaded.
    let offloadedAt: Date
}

/// Moves plugin bundles into a separate offload folder to reclaim disk space, and
/// moves them back on demand.
///
/// This mirrors the offloading feature of apps like Plugoff: a bundle is *moved*
/// (not copied) into an offload root, freeing its space on the original volume, and
/// can later be *moved* back to precisely its original location. Because every
/// operation touches the filesystem, the type is an `actor` so its work stays off
/// the main thread and concurrent calls are serialized.
actor OffloadManager {

    // MARK: - Errors

    /// Errors thrown while offloading or restoring a bundle.
    enum OffloadError: Error, LocalizedError {
        /// The bundle to offload does not exist at the given path.
        case sourceMissing(String)
        /// A file already occupies the offload destination path.
        case alreadyExists(String)
        /// The offloaded bundle is no longer present at its recorded offload path.
        case notOffloaded(String)
        /// Restoring would overwrite a file already at the original location.
        case restoreTargetOccupied(String)
        /// An underlying filesystem operation failed.
        case ioFailure(String)

        var errorDescription: String? {
            switch self {
            case .sourceMissing(let path):
                return "The plugin bundle to offload does not exist at \(path)."
            case .alreadyExists(let path):
                return "A file already exists at the offload destination \(path)."
            case .notOffloaded(let path):
                return "The offloaded bundle is no longer present at \(path)."
            case .restoreTargetOccupied(let path):
                return "Cannot restore: a file already exists at the original location \(path)."
            case .ioFailure(let message):
                return "A file operation failed: \(message)"
            }
        }
    }

    // MARK: - Properties

    /// The folder that offloaded bundles are moved into.
    private let offloadRoot: URL

    // MARK: - Initialization

    /// Creates a manager that offloads bundles into the given root folder.
    /// - Parameter offloadRoot: Destination folder for offloaded bundles
    ///   (for example `~/PluginventoryOffload`). It is created lazily on first offload.
    init(offloadRoot: URL) {
        self.offloadRoot = offloadRoot
    }

    /// Creates a manager that offloads into `~/PluginventoryOffload`.
    init() {
        self.offloadRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("PluginventoryOffload", isDirectory: true)
    }

    // MARK: - Offloading

    /// Moves the bundle at `sourceURL` into the offload root, freeing its original space.
    ///
    /// The bundle's size is measured *before* the move, since afterwards the source no
    /// longer exists. The offload root is created if necessary. If a file already
    /// occupies the destination the move is refused, so nothing is clobbered.
    ///
    /// - Parameter sourceURL: Filesystem location of the bundle to offload.
    /// - Returns: A record describing the move, suitable for persistence and later restore.
    /// - Throws: ``OffloadError/sourceMissing(_:)`` if the bundle is absent,
    ///   ``OffloadError/alreadyExists(_:)`` if the destination is occupied, or
    ///   ``OffloadError/ioFailure(_:)`` if the filesystem move fails.
    func offload(bundleAt sourceURL: URL) throws -> OffloadRecord {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw OffloadError.sourceMissing(sourceURL.path)
        }

        // Measure while the bundle still exists; the move erases the source.
        let sizeBytes = BundleSizeService.directorySize(at: sourceURL)
        let bundleName = sourceURL.lastPathComponent

        do {
            try fileManager.createDirectory(at: offloadRoot, withIntermediateDirectories: true)
        } catch {
            throw OffloadError.ioFailure(error.localizedDescription)
        }

        let destination = offloadRoot.appendingPathComponent(bundleName)

        guard !fileManager.fileExists(atPath: destination.path) else {
            throw OffloadError.alreadyExists(destination.path)
        }

        do {
            try fileManager.moveItem(at: sourceURL, to: destination)
        } catch {
            throw OffloadError.ioFailure(error.localizedDescription)
        }

        return OffloadRecord(
            originalPath: sourceURL.path,
            offloadedPath: destination.path,
            bundleName: bundleName,
            sizeBytes: sizeBytes,
            offloadedAt: Date()
        )
    }

    // MARK: - Restoring

    /// Moves a previously offloaded bundle back to its original location.
    ///
    /// The original location's parent directory is recreated if it went missing while
    /// the bundle was offloaded. If a file already occupies the original location the
    /// restore is refused, so nothing is clobbered.
    ///
    /// - Parameter record: The record returned by ``offload(bundleAt:)``.
    /// - Throws: ``OffloadError/notOffloaded(_:)`` if the offloaded copy is gone,
    ///   ``OffloadError/restoreTargetOccupied(_:)`` if the original location is taken,
    ///   or ``OffloadError/ioFailure(_:)`` if the filesystem move fails.
    func restore(_ record: OffloadRecord) throws {
        let fileManager = FileManager.default
        let source = URL(fileURLWithPath: record.offloadedPath)
        let target = URL(fileURLWithPath: record.originalPath)

        guard fileManager.fileExists(atPath: source.path) else {
            throw OffloadError.notOffloaded(record.offloadedPath)
        }

        guard !fileManager.fileExists(atPath: target.path) else {
            throw OffloadError.restoreTargetOccupied(target.path)
        }

        let parent = target.deletingLastPathComponent()

        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            try fileManager.moveItem(at: source, to: target)
        } catch {
            throw OffloadError.ioFailure(error.localizedDescription)
        }
    }

    // MARK: - Queries

    /// Whether the offloaded copy described by `record` currently exists on disk.
    /// - Parameter record: The record to check.
    /// - Returns: `true` if a file exists at the recorded offload path.
    func isOffloaded(_ record: OffloadRecord) -> Bool {
        FileManager.default.fileExists(atPath: record.offloadedPath)
    }
}
