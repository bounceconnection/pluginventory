import Testing
import Foundation
@testable import Pluginventory

@Suite("DuplicateDetector Tests")
struct DuplicateDetectorTests {

    @Test("Cross-format duplicate: same vendor+name as VST3 and AU forms one group")
    func crossFormatDuplicate() throws {
        let inputs = [
            DuplicatePluginInput(name: "Pro-Q 3", vendorName: "FabFilter", bundleIdentifier: "com.fabfilter.proq3.vst3", format: .vst3, path: "/Library/Audio/Plug-Ins/VST3/Pro-Q 3.vst3"),
            DuplicatePluginInput(name: "Pro-Q 3", vendorName: "FabFilter", bundleIdentifier: "com.fabfilter.proq3.au", format: .au, path: "/Library/Audio/Plug-Ins/Components/Pro-Q 3.component")
        ]
        let report = DuplicateDetector().analyze(inputs)
        #expect(report.formatDuplicateCount == 1)
        #expect(report.locationDuplicateCount == 0)
        let group = try #require(report.formatGroups.first)
        #expect(group.members.count == 2)
        #expect(group.id == "fabfilter|pro-q 3")
        #expect(group.displayName == "FabFilter – Pro-Q 3")
        #expect(report.duplicatePaths.count == 2)
    }

    @Test("Case-insensitivity: differing casing still groups together")
    func caseInsensitiveGrouping() throws {
        let inputs = [
            DuplicatePluginInput(name: "Pro-Q 3", vendorName: "FabFilter", bundleIdentifier: "com.fabfilter.proq3.vst3", format: .vst3, path: "/A/Pro-Q 3.vst3"),
            DuplicatePluginInput(name: "pro-q 3", vendorName: "fabfilter", bundleIdentifier: "com.fabfilter.proq3.au", format: .au, path: "/B/Pro-Q 3.component")
        ]
        let report = DuplicateDetector().analyze(inputs)
        #expect(report.formatDuplicateCount == 1)
        let group = try #require(report.formatGroups.first)
        #expect(group.members.count == 2)
        #expect(group.id == "fabfilter|pro-q 3")
    }

    @Test("Location duplicate: same bundle id and format at two paths forms one group")
    func locationDuplicate() throws {
        let inputs = [
            DuplicatePluginInput(name: "Serum", vendorName: "Xfer Records", bundleIdentifier: "com.xferrecords.serum", format: .vst3, path: "/Library/Audio/Plug-Ins/VST3/Serum.vst3"),
            DuplicatePluginInput(name: "Serum", vendorName: "Xfer Records", bundleIdentifier: "com.xferrecords.serum", format: .vst3, path: "/Users/me/Library/Audio/Plug-Ins/VST3/Serum.vst3")
        ]
        let report = DuplicateDetector().analyze(inputs)
        #expect(report.locationDuplicateCount == 1)
        let group = try #require(report.locationGroups.first)
        #expect(group.members.count == 2)
        #expect(group.id == "com.xferrecords.serum|vst3")
        #expect(report.formatDuplicateCount == 0)
    }

    @Test("Not a duplicate: single format and single path yield no groups")
    func singleInstanceIsNotDuplicate() {
        let inputs = [
            DuplicatePluginInput(name: "Diva", vendorName: "u-he", bundleIdentifier: "com.u-he.diva", format: .vst3, path: "/Library/Audio/Plug-Ins/VST3/Diva.vst3")
        ]
        let report = DuplicateDetector().analyze(inputs)
        #expect(report.formatGroups.isEmpty)
        #expect(report.locationGroups.isEmpty)
        #expect(report.duplicatePaths.isEmpty)
    }

    @Test("Empty input produces an empty report")
    func emptyInput() {
        let report = DuplicateDetector().analyze([])
        #expect(report.formatGroups.isEmpty)
        #expect(report.locationGroups.isEmpty)
        #expect(report.duplicatePaths.isEmpty)
    }

    @Test("Plugin present in three formats forms a group with three members")
    func threeFormatDuplicate() throws {
        let inputs = [
            DuplicatePluginInput(name: "Pro-Q 3", vendorName: "FabFilter", bundleIdentifier: "com.fabfilter.proq3.au", format: .au, path: "/Library/Audio/Plug-Ins/Components/Pro-Q 3.component"),
            DuplicatePluginInput(name: "Pro-Q 3", vendorName: "FabFilter", bundleIdentifier: "com.fabfilter.proq3.vst2", format: .vst2, path: "/Library/Audio/Plug-Ins/VST/Pro-Q 3.vst"),
            DuplicatePluginInput(name: "Pro-Q 3", vendorName: "FabFilter", bundleIdentifier: "com.fabfilter.proq3.vst3", format: .vst3, path: "/Library/Audio/Plug-Ins/VST3/Pro-Q 3.vst3")
        ]
        let report = DuplicateDetector().analyze(inputs)
        #expect(report.formatDuplicateCount == 1)
        let group = try #require(report.formatGroups.first)
        #expect(group.members.count == 3)
        #expect(group.members.map { $0.format.rawValue } == ["au", "vst2", "vst3"])
        #expect(report.duplicatePaths.count == 3)
    }
}
