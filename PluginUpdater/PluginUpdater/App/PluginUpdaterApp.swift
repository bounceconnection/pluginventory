import SwiftUI
import SwiftData
import ServiceManagement

@main
struct PluginUpdaterApp: App {
    let modelContainer: ModelContainer
    @State private var appState: AppState

    init() {
        do {
            let container = try PersistenceController.makeContainer()
            self.modelContainer = container
            self._appState = State(initialValue: AppState(modelContainer: container))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(appState)
                .task {
                    await initialSetup()
                }
        }
        .modelContainer(modelContainer)

        MenuBarExtra("Plugin Updater", systemImage: "puzzlepiece.extension") {
            MenuBarPopoverView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appState)
        }
        .modelContainer(modelContainer)
    }

    @MainActor
    private func initialSetup() async {
        // Seed scan locations
        do {
            try PersistenceController.seedDefaultScanLocations(in: modelContainer.mainContext)
        } catch {
            appState.errorMessage = "Failed to seed scan locations: \(error.localizedDescription)"
        }

        // Enable notifications by default on first launch
        if !UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding) {
            UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.notificationsEnabled)
            UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding)
            _ = await NotificationManager.shared.requestAuthorization()
        }

        // Load manifest + scan
        await appState.loadManifest()
        await appState.performScan()
    }
}

// MARK: - Dashboard

enum SidebarFilter: Hashable {
    case all
    case format(PluginFormat)
    case updatesAvailable
}

/// Wraps a Plugin with its computed update status so the Table can sort all columns.
struct PluginRow: Identifiable {
    let plugin: Plugin
    let availableVersion: String
    let hasUpdate: Bool

    var id: PersistentIdentifier { plugin.id }
    var name: String { plugin.name }
    var vendorName: String { plugin.vendorName }
    var formatRawValue: String { plugin.format.rawValue }
    var currentVersion: String { plugin.currentVersion }
    /// 2 = update available, 1 = up to date, 0 = no data. Descending sort puts updates first.
    var updatePriority: Int { hasUpdate ? 2 : (availableVersion == "—" ? 0 : 1) }
}

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<Plugin> { !$0.isRemoved }) private var plugins: [Plugin]
    @State private var sidebarSelection: SidebarFilter = .all
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\PluginRow.name)]
    @State private var selectedPluginID: PersistentIdentifier?
    @State private var showInspector = false

    private var filteredRows: [PluginRow] {
        var result = plugins

        switch sidebarSelection {
        case .all:
            break
        case .format(let format):
            result = result.filter { $0.format == format }
        case .updatesAvailable:
            result = result.filter { plugin in
                guard let entry = appState.manifestEntries[plugin.bundleIdentifier] else { return false }
                return entry.latestVersion.isNewerVersion(than: plugin.currentVersion)
            }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.vendorName.localizedCaseInsensitiveContains(searchText)
            }
        }

        let rows = result.map { plugin -> PluginRow in
            let manifest = appState.manifestEntries
            if let entry = manifest[plugin.bundleIdentifier] {
                let hasUpdate = entry.latestVersion.isNewerVersion(than: plugin.currentVersion)
                return PluginRow(plugin: plugin, availableVersion: entry.latestVersion, hasUpdate: hasUpdate)
            }
            return PluginRow(plugin: plugin, availableVersion: "—", hasUpdate: false)
        }

        return rows.sorted(using: sortOrder)
    }

    private var updatesCount: Int {
        plugins.filter { plugin in
            guard let entry = appState.manifestEntries[plugin.bundleIdentifier] else { return false }
            return entry.latestVersion.isNewerVersion(than: plugin.currentVersion)
        }.count
    }

    private var statusSubtitle: String {
        if let error = appState.errorMessage {
            return error
        } else if let date = appState.lastScanDate {
            return "Last scan: \(date.formatted(.relative(presentation: .named)))"
        }
        return ""
    }

    private var selectedPlugin: Plugin? {
        guard let id = selectedPluginID else { return nil }
        return plugins.first { $0.id == id }
    }

    private func pluginCount(for format: PluginFormat) -> Int {
        plugins.filter { $0.format == format }.count
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                Label("All (\(plugins.count))", systemImage: "music.note.list")
                    .tag(SidebarFilter.all)
                if updatesCount > 0 {
                    Label("Updates Available (\(updatesCount))", systemImage: "arrow.up.circle.fill")
                        .tag(SidebarFilter.updatesAvailable)
                        .foregroundStyle(.green)
                }
                Section("Formats") {
                    ForEach(PluginFormat.allCases) { format in
                        Label("\(format.displayName) (\(pluginCount(for: format)))", systemImage: "puzzlepiece.extension")
                            .tag(SidebarFilter.format(format))
                    }
                }
            }
            .navigationTitle("Plugins")
        } detail: {
            Table(filteredRows, selection: $selectedPluginID, sortOrder: $sortOrder) {
                TableColumn("Name", value: \PluginRow.name) { (row: PluginRow) in
                    Text(row.name)
                }
                TableColumn("Vendor", value: \PluginRow.vendorName) { (row: PluginRow) in
                    Text(row.vendorName)
                }
                TableColumn("Format", value: \PluginRow.formatRawValue) { (row: PluginRow) in
                    PluginFormatBadge(format: row.plugin.format)
                }
                .width(min: 50, ideal: 60, max: 80)
                TableColumn("Installed", value: \PluginRow.currentVersion) { (row: PluginRow) in
                    Text(row.currentVersion)
                        .monospacedDigit()
                }
                .width(min: 60, ideal: 80, max: 120)
                TableColumn("Available", value: \PluginRow.updatePriority) { (row: PluginRow) in
                    AvailableVersionCell(
                        availableVersion: row.availableVersion,
                        hasUpdate: row.hasUpdate
                    )
                }
                .width(min: 60, ideal: 80, max: 120)
            }
            .overlay {
                if plugins.isEmpty && !appState.isScanning {
                    ContentUnavailableView("No Plugins Found", systemImage: "puzzlepiece.extension", description: Text("Run a scan to discover your audio plugins."))
                } else if filteredRows.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if appState.isScanning {
                        ProgressView(value: appState.scanProgress)
                            .progressViewStyle(.circular)
                            .controlSize(.regular)
                    } else {
                        Button {
                            Task { await appState.performScan() }
                        } label: {
                            Label("Scan Now", systemImage: "arrow.clockwise")
                        }
                        .controlSize(.large)
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        TextField("Search plugins or vendors", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 180, idealWidth: 250)
                        Button {
                            showInspector.toggle()
                        } label: {
                            Label("Info", systemImage: "sidebar.trailing")
                        }
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
            .inspector(isPresented: $showInspector) {
                if let plugin = selectedPlugin {
                    PluginDetailView(plugin: plugin, manifest: appState.manifestEntries)
                        .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
                } else {
                    ContentUnavailableView("No Selection", systemImage: "cursorarrow.click", description: Text("Select a plugin to view its details."))
                        .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
                }
            }
            .onChange(of: selectedPluginID) { _, newValue in
                if newValue != nil {
                    showInspector = true
                }
            }
        }
        .frame(minWidth: 700, minHeight: 400)
    }
}

// MARK: - Available Version Cell

struct AvailableVersionCell: View {
    let availableVersion: String
    let hasUpdate: Bool

    var body: some View {
        if hasUpdate {
            Label(availableVersion, systemImage: "arrow.up.circle.fill")
                .monospacedDigit()
                .foregroundStyle(.green)
                .symbolRenderingMode(.multicolor)
        } else if availableVersion != "—" {
            Text(availableVersion)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } else {
            Text("—")
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Plugin Detail (Inspector)

struct PluginDetailView: View {
    let plugin: Plugin
    let manifest: [String: UpdateManifestEntry]

    private var sortedHistory: [PluginVersion] {
        plugin.versionHistory.sorted { $0.detectedDate > $1.detectedDate }
    }

    private var manifestEntry: UpdateManifestEntry? {
        manifest[plugin.bundleIdentifier]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plugin.name)
                            .font(.title2.bold())
                        Text(plugin.vendorName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    PluginFormatBadge(format: plugin.format)
                }

                Divider()

                // Info
                Group {
                    LabeledContent("Version") {
                        Text(plugin.currentVersion)
                            .monospacedDigit()
                    }
                    if let entry = manifestEntry {
                        LabeledContent("Latest") {
                            Text(entry.latestVersion)
                                .monospacedDigit()
                                .foregroundStyle(
                                    entry.latestVersion.isNewerVersion(than: plugin.currentVersion) ? .green : .secondary
                                )
                        }
                        if let url = entry.downloadURL, let downloadURL = URL(string: url) {
                            LabeledContent("Download") {
                                Link("Open", destination: downloadURL)
                            }
                        }
                    }
                    LabeledContent("Bundle ID") {
                        Text(plugin.bundleIdentifier)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("Path") {
                        HStack(spacing: 4) {
                            Text(plugin.path)
                                .font(.caption)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            Button {
                                NSWorkspace.shared.selectFile(plugin.path, inFileViewerRootedAtPath: "")
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    LabeledContent("First Seen") {
                        Text(plugin.installedDate.formatted(.dateTime.month().day().year()))
                    }
                    LabeledContent("Last Seen") {
                        Text(plugin.lastSeenDate.formatted(.dateTime.month().day().year()))
                    }
                }

                Divider()

                // Version History
                Text("Version History")
                    .font(.headline)

                if sortedHistory.isEmpty {
                    Text("No version changes recorded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedHistory) { version in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(version.version)
                                    .font(.body.monospaced())
                                if let prev = version.previousVersion {
                                    Text("from \(prev)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(version.detectedDate.formatted(.dateTime.month().day().year()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if version.id != sortedHistory.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Format Badge

struct PluginFormatBadge: View {
    let format: PluginFormat

    private var color: Color {
        switch format {
        case .vst3: .blue
        case .au: .purple
        case .clap: .orange
        }
    }

    var body: some View {
        Text(format.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }
}

// MARK: - Menu Bar

struct MenuBarPopoverView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plugin Updater")
                .font(.headline)
            Divider()
            Text("\(appState.totalPluginCount) plugins")
                .font(.subheadline)
            if appState.updatesAvailableCount > 0 {
                Text("\(appState.updatesAvailableCount) updates available")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
            if let date = appState.lastScanDate {
                Text("Last scan: \(date.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No scan performed yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if appState.isScanning {
                ProgressView(value: appState.scanProgress)
                    .controlSize(.small)
            }
            if !appState.recentChanges.isEmpty {
                Divider()
                ForEach(appState.recentChanges.prefix(5), id: \.self) { change in
                    Text(change)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            Button(appState.isScanning ? "Scanning..." : "Scan Now") {
                Task { await appState.performScan() }
            }
            .disabled(appState.isScanning)
            Button("Open Dashboard") {
                NSApp.activate()
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        .padding()
        .frame(width: 250)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Query private var scanLocations: [ScanLocation]
    @AppStorage(Constants.UserDefaultsKeys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(Constants.UserDefaultsKeys.manifestURL) private var manifestURL = ""
    @State private var launchAtLogin = false
    @State private var newPath = ""
    @State private var newFormat: PluginFormat = .vst3

    var body: some View {
        TabView {
            // Scan Paths
            Form {
                Section("Default Scan Locations") {
                    ForEach(scanLocations.filter(\.isDefault)) { location in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { location.isEnabled },
                                set: { location.isEnabled = $0 }
                            )) {
                                HStack {
                                    PluginFormatBadge(format: location.format)
                                    Text(location.path)
                                        .font(.caption.monospaced())
                                }
                            }
                        }
                    }
                }

                Section("Custom Scan Locations") {
                    ForEach(scanLocations.filter { !$0.isDefault }) { location in
                        HStack {
                            PluginFormatBadge(format: location.format)
                            Text(location.path)
                                .font(.caption.monospaced())
                            Spacer()
                            Button(role: .destructive) {
                                if let context = location.modelContext {
                                    context.delete(location)
                                    try? context.save()
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        Picker("Format", selection: $newFormat) {
                            ForEach(PluginFormat.allCases) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .frame(width: 100)
                        TextField("Path", text: $newPath)
                            .font(.caption.monospaced())
                        Button("Add") {
                            guard !newPath.isEmpty else { return }
                            let location = ScanLocation(path: newPath, format: newFormat)
                            appState.modelContainer.mainContext.insert(location)
                            try? appState.modelContainer.mainContext.save()
                            newPath = ""
                        }
                    }
                }
            }
            .tabItem { Label("Scan Paths", systemImage: "folder.badge.gearshape") }

            // General
            Form {
                Section("Notifications") {
                    Toggle("Enable notifications for plugin changes", isOn: $notificationsEnabled)
                }

                Section("Update Manifest") {
                    TextField("Remote manifest URL (optional)", text: $manifestURL)
                        .font(.caption.monospaced())
                    Text("Provide a URL to a JSON manifest with latest plugin versions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Startup") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in
                            do {
                                if enabled {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                launchAtLogin = !enabled
                            }
                        }
                }
            }
            .tabItem { Label("General", systemImage: "gearshape") }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
