import SwiftUI

struct SettingsView: View {
    @State private var preferences = UserPreferences.shared

    var body: some View {
        TabView {
            GeneralSettingsTab(preferences: preferences)
                .tabItem { Label("General", systemImage: "gear") }

            InsetSettingsTab(preferences: preferences)
                .tabItem { Label("Insets", systemImage: "arrow.up.left.and.arrow.down.right") }

            PresetSettingsTab(preferences: preferences)
                .tabItem { Label("Presets (Advanced)", systemImage: "grid") }

            ShortcutsSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 520, height: 400)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @Bindable var preferences: UserPreferences

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Auto-maximize when selection fills grid", isOn: $preferences.autoMaximize)
                Toggle("Target presets to monitor of mouse", isOn: $preferences.targetPresetsToMonitorOfMouse)
                Toggle("Launch mTile at login", isOn: $preferences.launchAtLogin)
            }

            Section("Window Spacing") {
                HStack {
                    Text("Spacing between windows:")
                    TextField("", value: $preferences.windowSpacing, format: .number)
                        .frame(width: 60)
                    Text("px")
                }
            }

            Section("Grid Sizes") {
                HStack {
                    Text("Sizes (e.g. 8x6, 6x4, 4x4):")
                    TextField("", text: $preferences.gridSizes)
                        .frame(minWidth: 200)
                }
                Text("These are the grid buttons shown in the overlay and apply immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Global Shortcuts") {
                Toggle("Enable preset shortcuts globally", isOn: $preferences.globalPresets)
                Toggle("Enable move/resize shortcuts globally", isOn: $preferences.moveResizeEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: preferences.launchAtLogin) { _, newValue in
            let applied = LoginItemService.shared.setEnabled(newValue)
            if !applied {
                // Roll back UI + persisted setting when registration fails.
                preferences.launchAtLogin = LoginItemService.shared.isEnabled
            }
        }
        .onChange(of: preferences.gridSizes) { _, _ in
            AppCoordinator.shared?.refreshGridPresetsFromSettings()
        }
        .onChange(of: preferences.globalPresets) { _, _ in
            AppCoordinator.shared?.refreshGlobalShortcutGroupsFromSettings()
        }
        .onChange(of: preferences.moveResizeEnabled) { _, _ in
            AppCoordinator.shared?.refreshGlobalShortcutGroupsFromSettings()
        }
    }
}

// MARK: - Insets Tab

struct InsetSettingsTab: View {
    @Bindable var preferences: UserPreferences

    var body: some View {
        Form {
            Section("About Insets") {
                Text("Insets reserve space on monitor edges so tiled windows stay away from menu bars, notches, docks, or your own desired margins.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Primary Monitor Insets") {
                insetFields(
                    top: $preferences.insetsPrimaryTop,
                    right: $preferences.insetsPrimaryRight,
                    bottom: $preferences.insetsPrimaryBottom,
                    left: $preferences.insetsPrimaryLeft
                )
            }

            Section("Secondary Monitor Insets") {
                insetFields(
                    top: $preferences.insetsSecondaryTop,
                    right: $preferences.insetsSecondaryRight,
                    bottom: $preferences.insetsSecondaryBottom,
                    left: $preferences.insetsSecondaryLeft
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func insetFields(
        top: Binding<Int>,
        right: Binding<Int>,
        bottom: Binding<Int>,
        left: Binding<Int>
    ) -> some View {
        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Top:")
                TextField("", value: top, format: .number)
                    .frame(width: 60)
                Text("px")
            }
            GridRow {
                Text("Right:")
                TextField("", value: right, format: .number)
                    .frame(width: 60)
                Text("px")
            }
            GridRow {
                Text("Bottom:")
                TextField("", value: bottom, format: .number)
                    .frame(width: 60)
                Text("px")
            }
            GridRow {
                Text("Left:")
                TextField("", value: left, format: .number)
                    .frame(width: 60)
                Text("px")
            }
        }
    }
}

// MARK: - Presets Tab

struct PresetSettingsTab: View {
    @Bindable var preferences: UserPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Resize Presets")
                    .font(.headline)

                Text("Advanced: optional. You only need this if you bind preset shortcuts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Format: GridSize Selection [, Selection | GridSize Selection ...]")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Example: 4x4 1:3 2:4, 1:2 3:4, 1:1 4:4")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(1...30, id: \.self) { index in
                    HStack {
                        Text("Preset \(index):")
                            .frame(width: 70, alignment: .trailing)
                            .font(.system(.body, design: .monospaced))

                        TextField("e.g. 4x4 1:1 2:2", text: Binding(
                            get: { preferences.resizePreset(index) },
                            set: { preferences.setResizePreset(index, value: $0) }
                        ))
                        .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Shortcuts Tab

struct ShortcutsSettingsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Text("Shortcut recording will be available via the KeyboardShortcuts package.")
                .foregroundStyle(.secondary)

            Text("Default: ⌘⌥G to toggle overlay")
                .font(.callout)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
