import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("quickmath.theme") private var themeRaw = AppTheme.system.rawValue
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var reminderHour = 9
    @State private var reminderMinute = 0
    @State private var remindersEnabled = false

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                Form {
                    // Pro section
                    Section("Pro") {
                        if store.isPro {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.qmCorrect)
                                Text("Ladder Pro — Active")
                                    .foregroundStyle(.primary)
                            }
                            Link("Manage Subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                                .foregroundStyle(Color.qmAccent)
                        } else {
                            Button("Unlock Ladder Pro") {
                                showPaywall = true
                            }
                            .foregroundStyle(Color.qmAccent)
                            Button("Restore Purchase") {
                                Task { await store.restore() }
                            }
                            .foregroundStyle(Color.qmAccent)
                        }
                    }

                    // Reminders (Pro)
                    if store.isPro {
                        Section("Daily Reminder") {
                            Toggle("Enable Reminder", isOn: $remindersEnabled)
                                .tint(Color.qmAccent)
                                .onChange(of: remindersEnabled) { _, val in
                                    if val {
                                        Task {
                                            let granted = await Reminders.requestAuthorization()
                                            if granted {
                                                Reminders.schedule(hour: reminderHour, minute: reminderMinute)
                                            } else {
                                                remindersEnabled = false
                                            }
                                        }
                                    } else {
                                        Reminders.cancel()
                                    }
                                }
                            if remindersEnabled {
                                DatePicker("Time", selection: Binding(
                                    get: {
                                        Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
                                    },
                                    set: { newDate in
                                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                        reminderHour = comps.hour ?? 9
                                        reminderMinute = comps.minute ?? 0
                                        Reminders.schedule(hour: reminderHour, minute: reminderMinute)
                                    }
                                ), displayedComponents: .hourAndMinute)
                                .tint(Color.qmAccent)
                            }
                        }
                    }

                    // Appearance
                    Section("Appearance") {
                        Picker("Theme", selection: $themeRaw) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.label).tag(theme.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Legal
                    Section("Legal") {
                        Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/ladder-site/privacy.html")!)
                            .foregroundStyle(Color.qmAccent)
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .foregroundStyle(Color.qmAccent)
                    }

                    // Data
                    Section("Data") {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete All Data")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.qmAccent)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(store)
            }
            .confirmationDialog("Delete all saved data?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    appModel.deleteAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }
}
