import SwiftUI
import SwiftData

struct HomeView: View {
    var forceScreen: String? = nil

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showSettings = false
    @State private var showPro = false
    @State private var showLogConfirm = false
    @State private var animateCoin = false

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        // Hero streak card
                        streakCard
                        // Today's target
                        todayCard
                        // Metrics row
                        metricsRow
                        // Pro feature tile
                        proTile
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Ladder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.qmAccent)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(appModel)
            }
            .sheet(isPresented: $showPro) {
                if store.isPro {
                    InsightsView()
                        .environmentObject(appModel)
                        .environmentObject(store)
                } else {
                    PaywallView()
                        .environmentObject(store)
                }
            }
            .onAppear {
                if forceScreen == "insights" { showPro = true }
                if forceScreen == "settings" { showSettings = true }
            }
        }
    }

    // MARK: - Streak card

    private var streakCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(appModel.currentStreak) day\(appModel.currentStreak == 1 ? "" : "s")")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.qmAccent)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.qmAccent.opacity(0.1))
                        .frame(width: 72, height: 72)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.qmAccent)
                        .scaleEffect(animateCoin ? 1.15 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: animateCoin)
                }
            }
            Divider()
            HStack {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(Color.qmCorrect)
                Text("Total saved: \(appModel.totalSaved, format: .currency(code: "USD"))")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
        }
        .qmCard()
    }

    // MARK: - Today's target

    private var todayCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Target")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(appModel.todayTarget, format: .currency(code: "USD"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
                if let day = appModel.todayDay, day.didSave {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.qmCorrect)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.qmHair)
                }
            }

            if let day = appModel.todayDay, day.didSave {
                Button {
                    Haptics.warning()
                    appModel.undoTodaySaved()
                } label: {
                    Text("Undo")
                        .frame(maxWidth: .infinity)
                }
                .softButton()
            } else {
                Button {
                    Haptics.success()
                    animateCoin.toggle()
                    appModel.logTodaySaved()
                } label: {
                    Text("I saved it!")
                        .frame(maxWidth: .infinity)
                }
                .prominentButton()
            }
        }
        .qmCard()
    }

    // MARK: - Metrics row

    private var metricsRow: some View {
        HStack(spacing: 12) {
            MetricTile(value: "$\(Int(appModel.todayTarget))", label: "Today")
            MetricTile(value: "\(appModel.days.filter { $0.didSave }.count)", label: "Days Saved")
            MetricTile(value: appModel.totalSaved >= 1000
                       ? String(format: "$%.0fK+", appModel.totalSaved / 1000)
                       : String(format: "$%.0f", appModel.totalSaved),
                       label: "Total Saved")
        }
    }

    // MARK: - Pro tile

    private var proTile: some View {
        Button {
            Haptics.tap()
            showPro = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.isPro ? "History & Insights" : "Unlock Pro")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(store.isPro ? "View your full save history" : "Calendar, badges & reminders")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: store.isPro ? "chart.bar.fill" : "lock.fill")
                    .foregroundStyle(Color.qmAccent)
                    .font(.title3)
            }
        }
        .qmCard()
    }
}
