import SwiftUI
import SwiftData
import Charts

/// Pro-only: full save history calendar, milestones, and CSV export.
struct InsightsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var showExportSheet = false
    @State private var exportText = ""

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        summaryRow
                        calendarCard
                        chartCard
                        milestonesCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        exportText = appModel.csvExport()
                        showExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.qmAccent)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.qmAccent)
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ShareSheet(text: exportText)
            }
        }
    }

    // MARK: - Summary metrics

    private var summaryRow: some View {
        HStack(spacing: 12) {
            MetricTile(value: "\(appModel.currentStreak)", label: "Streak")
            MetricTile(value: "\(appModel.days.filter { $0.didSave }.count)", label: "Days Saved")
            MetricTile(value: appModel.totalSaved >= 1000
                       ? String(format: "$%.1fK", appModel.totalSaved / 1000)
                       : String(format: "$%.0f", appModel.totalSaved),
                       label: "Total")
        }
    }

    // MARK: - Calendar card

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.qmAccent)
                }
                Spacer()
                Text(monthFormatter.string(from: selectedMonth))
                    .font(.headline)
                Spacer()
                Button {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.qmAccent)
                }
            }
            CalendarGrid(month: selectedMonth, days: appModel.days)
        }
        .qmCard()
    }

    // MARK: - Chart card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Targets (Last 14 Days)")
                .font(.subheadline.weight(.medium))

            let recent = Array(appModel.days.suffix(14))
            if recent.isEmpty {
                Text("No data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Chart(recent) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Amount", day.didSave ? day.savedAmount : 0)
                    )
                    .foregroundStyle(day.didSave ? Color.qmAccent : Color.qmHair)
                }
                .frame(height: 120)
            }
        }
        .qmCard()
    }

    // MARK: - Milestones card

    private var milestonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.subheadline.weight(.medium))
            ForEach(appModel.milestones, id: \.id) { m in
                HStack {
                    Image(systemName: m.reachedDate != nil ? "checkmark.seal.fill" : "seal")
                        .foregroundStyle(m.reachedDate != nil ? Color.qmCorrect : Color.qmHair)
                    Text(m.label)
                        .font(.subheadline)
                    Spacer()
                    if let d = m.reachedDate {
                        Text(d, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(m.thresholdAmount, format: .currency(code: "USD"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .qmCard()
    }
}

// MARK: - Calendar Grid helper

private struct CalendarGrid: View {
    let month: Date
    let days: [SaveDay]

    private var daysInMonth: [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month),
              let start = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return [] }
        return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    private func didSave(on date: Date) -> Bool {
        let cal = Calendar.current
        return days.first(where: { cal.isDate($0.date, inSameDayAs: date) })?.didSave == true
    }

    private var weekdayHeaders: [String] { ["S","M","T","W","T","F","S"] }

    private var leadingBlanks: Int {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: daysInMonth.first ?? Date())
        return weekday - 1
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(weekdayHeaders, id: \.self) { h in
                Text(h)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 28) }
            ForEach(daysInMonth, id: \.self) { date in
                let saved = didSave(on: date)
                let cal = Calendar.current
                let isToday = cal.isDateInToday(date)
                ZStack {
                    Circle()
                        .fill(saved ? Color.qmAccent : (isToday ? Color.qmAccent.opacity(0.15) : Color.qmHair.opacity(0.3)))
                    Text("\(cal.component(.day, from: date))")
                        .font(.caption2.weight(isToday ? .bold : .regular))
                        .foregroundStyle(saved ? .white : .primary)
                }
                .frame(height: 28)
            }
        }
    }
}

// MARK: - Share sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
