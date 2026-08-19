import Foundation
import SwiftData

/// A plugin bundle that has been moved out of its install location into the
/// offload folder to reclaim disk space. Retains everything needed to move it
/// back to exactly where it came from.
@Model
final class OffloadedPlugin {
    var name: String
    var vendorName: String
    var bundleIdentifier: String
    var formatRaw: String
    var originalPath: String
    var offloadedPath: String
    var sizeBytes: Int64
    var offloadedAt: Date

    init(
        name: String,
        vendorName: String,
        bundleIdentifier: String,
        formatRaw: String,
        originalPath: String,
        offloadedPath: String,
        sizeBytes: Int64,
        offloadedAt: Date
    ) {
        self.name = name
        self.vendorName = vendorName
        self.bundleIdentifier = bundleIdentifier
        self.formatRaw = formatRaw
        self.originalPath = originalPath
        self.offloadedPath = offloadedPath
        self.sizeBytes = sizeBytes
        self.offloadedAt = offloadedAt
    }

    var format: PluginFormat? { PluginFormat(rawValue: formatRaw) }

    var sizeDisplay: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    /// The record needed by `OffloadManager` to restore this bundle.
    var offloadRecord: OffloadRecord {
        OffloadRecord(
            originalPath: originalPath,
            offloadedPath: offloadedPath,
            bundleName: URL(fileURLWithPath: originalPath).lastPathComponent,
            sizeBytes: sizeBytes,
            offloadedAt: offloadedAt
        )
    }
}
