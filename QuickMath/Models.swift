import SwiftUI
import SwiftData

// MARK: - SwiftData Models

@Model
final class SaveDay {
    var id: UUID
    var date: Date
    var targetAmount: Double
    var savedAmount: Double
    var didSave: Bool
    var streakCount: Int

    init(id: UUID = UUID(), date: Date, targetAmount: Double, savedAmount: Double = 0, didSave: Bool = false, streakCount: Int = 0) {
        self.id = id
        self.date = date
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.didSave = didSave
        self.streakCount = streakCount
    }
}

@Model
final class LadderPlan {
    var id: UUID
    var name: String
    var startAmount: Double
    var stepAmount: Double
    var cadence: String   // "daily"
    var startDate: Date
    var isActive: Bool

    init(id: UUID = UUID(), name: String, startAmount: Double, stepAmount: Double, cadence: String = "daily", startDate: Date = Date(), isActive: Bool = true) {
        self.id = id
        self.name = name
        self.startAmount = startAmount
        self.stepAmount = stepAmount
        self.cadence = cadence
        self.startDate = startDate
        self.isActive = isActive
    }
}

@Model
final class SaveMilestone {
    var id: UUID
    var label: String
    var thresholdAmount: Double
    var reachedDate: Date?

    init(id: UUID = UUID(), label: String, thresholdAmount: Double, reachedDate: Date? = nil) {
        self.id = id
        self.label = label
        self.thresholdAmount = thresholdAmount
        self.reachedDate = reachedDate
    }
}

// MARK: - AppModel

@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var days: [SaveDay] = []
    @Published private(set) var activePlan: LadderPlan? = nil
    @Published private(set) var milestones: [SaveMilestone] = []

    init(container: ModelContainer) {
        self.container = container
        reload()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([SaveDay.self, LadderPlan.self, SaveMilestone.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [fallback])) ?? {
                fatalError("Cannot create ModelContainer: \(error)")
            }()
        }
    }

    func reload() {
        let ctx = container.mainContext
        let dayDesc = FetchDescriptor<SaveDay>(sortBy: [SortDescriptor(\.date)])
        let planDesc = FetchDescriptor<LadderPlan>()
        let mileDesc = FetchDescriptor<SaveMilestone>(sortBy: [SortDescriptor(\.thresholdAmount)])
        days = (try? ctx.fetch(dayDesc)) ?? []
        let plans = (try? ctx.fetch(planDesc)) ?? []
        activePlan = plans.first(where: { $0.isActive })
        milestones = (try? ctx.fetch(mileDesc)) ?? []

        // Seed default plan + milestones if needed
        if plans.isEmpty { seedDefaultPlan() }
        if milestones.isEmpty { seedMilestones() }
    }

    func refresh() { reload() }

    // MARK: - Plan seeding

    private func seedDefaultPlan() {
        let plan = LadderPlan(name: "52-Week Classic", startAmount: 1.0, stepAmount: 1.0, cadence: "daily", startDate: Calendar.current.startOfDay(for: Date()), isActive: true)
        container.mainContext.insert(plan)
        try? container.mainContext.save()
        activePlan = plan
    }

    private func seedMilestones() {
        let defs: [(String, Double)] = [
            ("First Save", 1), ("10 Saved", 10), ("$50 Club", 50),
            ("$100 Saved", 100), ("$250 Milestone", 250), ("$500 Halfway", 500),
            ("$1,000 Champion", 1000), ("$1,378 Complete", 1378)
        ]
        for (label, amount) in defs {
            let m = SaveMilestone(label: label, thresholdAmount: amount)
            container.mainContext.insert(m)
        }
        try? container.mainContext.save()
        reload()
    }

    // MARK: - Today's save target

    var todayTarget: Double {
        guard let plan = activePlan else { return 1.0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: plan.startDate)
        let today = cal.startOfDay(for: Date())
        let dayIndex = cal.dateComponents([.day], from: start, to: today).day ?? 0
        return plan.startAmount + Double(max(0, dayIndex)) * plan.stepAmount
    }

    var todayDay: SaveDay? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return days.first(where: { cal.isDate($0.date, inSameDayAs: today) })
    }

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())
        while true {
            guard let day = days.first(where: { cal.isDate($0.date, inSameDayAs: checkDate) }) else { break }
            if !day.didSave { break }
            streak += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }

    var totalSaved: Double {
        days.filter { $0.didSave }.reduce(0) { $0 + $1.savedAmount }
    }

    // MARK: - Log today's save

    func logTodaySaved() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let target = todayTarget
        let streak = currentStreak + 1

        if let existing = todayDay {
            existing.didSave = true
            existing.savedAmount = target
            existing.streakCount = streak
        } else {
            let day = SaveDay(date: today, targetAmount: target, savedAmount: target, didSave: true, streakCount: streak)
            container.mainContext.insert(day)
        }
        try? container.mainContext.save()
        checkMilestones()
        reload()
    }

    func undoTodaySaved() {
        guard let day = todayDay else { return }
        day.didSave = false
        day.savedAmount = 0
        try? container.mainContext.save()
        reload()
    }

    // MARK: - Milestones

    private func checkMilestones() {
        let total = totalSaved
        let ctx = container.mainContext
        for m in milestones where m.reachedDate == nil && total >= m.thresholdAmount {
            m.reachedDate = Date()
        }
        try? ctx.save()
    }

    // MARK: - Delete all data

    func deleteAllData() {
        let ctx = container.mainContext
        for d in days { ctx.delete(d) }
        for p in (try? ctx.fetch(FetchDescriptor<LadderPlan>())) ?? [] { ctx.delete(p) }
        for m in milestones { ctx.delete(m) }
        try? ctx.save()
        reload()
    }

    // MARK: - CSV export (Pro)

    func csvExport() -> String {
        var lines = ["Date,Target,Saved,Streak"]
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        for d in days.sorted(by: { $0.date < $1.date }) {
            lines.append("\(fmt.string(from: d.date)),\(d.targetAmount),\(d.savedAmount),\(d.streakCount)")
        }
        return lines.joined(separator: "\n")
    }
}
