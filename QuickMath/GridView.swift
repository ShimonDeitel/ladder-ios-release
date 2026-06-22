import SwiftUI
import SwiftData

/// Primary entry/action screen — shows the laddered daily save target and lets the user log it.
struct GridView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var confettiVisible = false
    @State private var bounceAmount: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                VStack(spacing: 28) {
                    Spacer(minLength: 16)
                    ladderVisual
                    targetCard
                    actionArea
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Daily Save")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.qmAccent)
                }
            }
        }
    }

    // MARK: - Ladder visual (ascending steps)

    private var ladderVisual: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                let past = appModel.days.filter { $0.didSave }.count
                let isSaved = i < past
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSaved ? Color.qmAccent : Color.qmHair)
                    .frame(width: 44, height: CGFloat(24 + i * 16))
                    .overlay(
                        Group {
                            if i == 4 {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white)
                                    .offset(y: -8)
                            }
                        },
                        alignment: .top
                    )
            }
        }
        .frame(height: 100)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appModel.currentStreak)
    }

    // MARK: - Target card

    private var targetCard: some View {
        VStack(spacing: 10) {
            Text("Save today:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(appModel.todayTarget, format: .currency(code: "USD"))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(Color.qmAccent)
                .scaleEffect(bounceAmount)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: bounceAmount)
            if let plan = appModel.activePlan {
                Text(plan.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .qmCard()
    }

    // MARK: - Action area

    @ViewBuilder
    private var actionArea: some View {
        if let day = appModel.todayDay, day.didSave {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.qmCorrect)
                        .font(.title2)
                    Text("Saved! Streak: \(appModel.currentStreak) days")
                        .font(.headline)
                        .foregroundStyle(Color.qmCorrect)
                }
                Button {
                    Haptics.warning()
                    appModel.undoTodaySaved()
                } label: {
                    Text("Undo")
                        .frame(maxWidth: .infinity)
                }
                .softButton()
            }
            .qmCard()
        } else {
            VStack(spacing: 12) {
                Button {
                    Haptics.success()
                    bounceAmount = 1.15
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        bounceAmount = 1.0
                    }
                    appModel.logTodaySaved()
                } label: {
                    Text("I saved it!")
                        .frame(maxWidth: .infinity)
                }
                .prominentButton()

                Text("Tap once you've set aside \(appModel.todayTarget, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
