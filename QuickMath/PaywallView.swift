import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private let benefits = [
        ("calendar", "Full save history calendar with monthly and yearly totals"),
        ("shield.lefthalf.filled", "Streak insurance: one freeze token per month plus milestone badges"),
        ("bell.badge", "Daily save reminder at your chosen time and CSV export")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "stairs")
                                .font(.system(size: 52))
                                .foregroundStyle(Color.qmAccent)
                                .padding(.top, 8)
                            Text("Ladder Pro")
                                .font(.system(size: 28, weight: .bold))
                            Text("\(store.displayPrice) / month. Auto-renews until you cancel.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Benefits
                        VStack(spacing: 0) {
                            ForEach(Array(benefits.enumerated()), id: \.offset) { idx, benefit in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: benefit.0)
                                        .foregroundStyle(Color.qmAccent)
                                        .font(.title3)
                                        .frame(width: 28)
                                    Text(benefit.1)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                                if idx < benefits.count - 1 {
                                    Divider().padding(.leading, 42)
                                }
                            }
                        }
                        .qmCard()

                        // Actions
                        VStack(spacing: 12) {
                            Button {
                                Haptics.tap()
                                Task { await store.purchase() }
                            } label: {
                                if store.purchaseInFlight {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Unlock Ladder Pro")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .prominentButton()
                            .disabled(store.purchaseInFlight)

                            Button {
                                Task { await store.restore() }
                            } label: {
                                Text("Restore Purchase")
                                    .frame(maxWidth: .infinity)
                            }
                            .softButton()
                        }

                        // Disclosure
                        VStack(spacing: 8) {
                            Text("Ladder Pro is an auto-renewable subscription at \(store.displayPrice)/month. Payment is charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. You can manage and cancel subscriptions in your App Store account settings.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 20) {
                                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                    .font(.caption)
                                    .foregroundStyle(Color.qmAccent)
                                Link("Privacy", destination: URL(string: "https://shimondeitel.github.io/ladder-site/privacy.html")!)
                                    .font(.caption)
                                    .foregroundStyle(Color.qmAccent)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.qmAccent)
                }
            }
            .onChange(of: store.isPro) { _, newVal in
                if newVal { dismiss() }
            }
        }
    }
}
