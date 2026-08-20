/// A single plugin instance considered by ``DuplicateDetector``.
struct DuplicatePluginInput: Sendable, Hashable {
    let name: String
    let vendorName: String
    let bundleIdentifier: String
    let format: PluginFormat
    let path: String
}

/// A collection of plugin instances that were detected as duplicates of one another.
struct DuplicateGroup: Sendable, Identifiable {
    let id: String
    let displayName: String
    let members: [DuplicatePluginInput]
}

/// The result of analyzing a set of plugins for duplicates.
struct DuplicateReport: Sendable {
    let formatGroups: [DuplicateGroup]
    let locationGroups: [DuplicateGroup]
    let duplicatePaths: Set<String>
    var formatDuplicateCount: Int { formatGroups.count }
    var locationDuplicateCount: Int { locationGroups.count }
}

/// Detects cross-format and cross-location duplicate plugins.
///
/// - Cross-format duplicates: the same plugin (matched case-insensitively on
///   vendor + name) available in two or more distinct formats.
/// - Location duplicates: the same plugin + format (matched on bundle
///   identifier + format) installed at two or more distinct paths.
struct DuplicateDetector: Sendable {

    func analyze(_ inputs: [DuplicatePluginInput]) -> DuplicateReport {
        let formatGroups = makeFormatGroups(inputs)
        let locationGroups = makeLocationGroups(inputs)

        var duplicatePaths: Set<String> = []
        for group in formatGroups {
            for member in group.members {
                duplicatePaths.insert(member.path)
            }
        }
        for group in locationGroups {
            for member in group.members {
                duplicatePaths.insert(member.path)
            }
        }

        return DuplicateReport(
            formatGroups: formatGroups,
            locationGroups: locationGroups,
            duplicatePaths: duplicatePaths
        )
    }

    // MARK: - Cross-format

    private func makeFormatGroups(_ inputs: [DuplicatePluginInput]) -> [DuplicateGroup] {
        var buckets: [String: [DuplicatePluginInput]] = [:]
        for input in inputs {
            let key = "\(input.vendorName.lowercased())|\(input.name.lowercased())"
            buckets[key, default: []].append(input)
        }

        var groups: [DuplicateGroup] = []
        for (key, members) in buckets {
            let distinctFormats = Set(members.map { $0.format })
            guard distinctFormats.count >= 2 else { continue }

            let sortedMembers = sorted(members)
            guard let representative = sortedMembers.first else { continue }
            let displayName = "\(representative.vendorName) – \(representative.name)"
            groups.append(
                DuplicateGroup(id: key, displayName: displayName, members: sortedMembers)
            )
        }

        return sorted(groups)
    }

    // MARK: - Location

    private func makeLocationGroups(_ inputs: [DuplicatePluginInput]) -> [DuplicateGroup] {
        var buckets: [String: [DuplicatePluginInput]] = [:]
        for input in inputs {
            let key = "\(input.bundleIdentifier)|\(input.format.rawValue)"
            buckets[key, default: []].append(input)
        }

        var groups: [DuplicateGroup] = []
        for (key, members) in buckets {
            let distinctPaths = Set(members.map { $0.path })
            guard distinctPaths.count >= 2 else { continue }

            let sortedMembers = sorted(members)
            guard let representative = sortedMembers.first else { continue }
            groups.append(
                DuplicateGroup(
                    id: key,
                    displayName: representative.bundleIdentifier,
                    members: sortedMembers
                )
            )
        }

        return sorted(groups)
    }

    // MARK: - Deterministic ordering

    private func sorted(_ groups: [DuplicateGroup]) -> [DuplicateGroup] {
        groups.sorted { lhs, rhs in
            let left = lhs.displayName.lowercased()
            let right = rhs.displayName.lowercased()
            if left != right {
                return left < right
            }
            return lhs.id < rhs.id
        }
    }

    private func sorted(_ members: [DuplicatePluginInput]) -> [DuplicatePluginInput] {
        members.sorted { lhs, rhs in
            if lhs.format.rawValue != rhs.format.rawValue {
                return lhs.format.rawValue < rhs.format.rawValue
            }
            if lhs.path != rhs.path {
                return lhs.path < rhs.path
            }
            if lhs.bundleIdentifier != rhs.bundleIdentifier {
                return lhs.bundleIdentifier < rhs.bundleIdentifier
            }
            return lhs.name < rhs.name
        }
    }
}
