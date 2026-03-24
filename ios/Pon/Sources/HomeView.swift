import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Contract.createdAt, order: .reverse) private var all: [Contract]
    @Binding var showNewContract: Bool

    private var active: [Contract] { all.filter { $0.status == "active" || $0.status == "signed" } }
    private var drafts: [Contract] { all.filter { $0.status == "draft" } }
    private var totalAmount: Int { active.filter { $0.currency == "JPY" }.reduce(0) { $0 + $1.amount } }

    @State private var filter: String = ""

    private var filtered: [Contract] {
        if filter.isEmpty { return all }
        return all.filter { $0.status == filter }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Tagline
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("決まった、ポン。")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { showNewContract = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.pon)
                        }
                    }

                    // Stats
                    HStack(spacing: 10) {
                        StatCard(label: "アクティブ", value: "\(active.count)", color: Color.pon)
                        StatCard(label: "下書き", value: "\(drafts.count)", color: .secondary)
                        StatCard(label: "契約総額", value: totalAmount > 0 ? "\u{00A5}\(totalAmount.formatted())" : "-", color: Color.ponSigned)
                    }

                    // Status filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            filterPill("", "すべて")
                            filterPill("draft", "下書き")
                            filterPill("sent", "送付済")
                            filterPill("signed", "署名済")
                            filterPill("active", "有効")
                            filterPill("expired", "期限切れ")
                        }
                    }

                    // Contract list
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(filtered, id: \.id) { contract in
                            NavigationLink {
                                ContractDetailView(contract: contract)
                            } label: {
                                ContractRow(contract: contract)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color.ponBg)
            .navigationTitle("ポン")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func filterPill(_ value: String, _ label: String) -> some View {
        let sel = filter == value
        let c: Color = value.isEmpty ? Color.pon : Color.statusColor(for: value)
        return Button { filter = value } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(sel ? c.opacity(0.15) : .white.opacity(0.03))
                .foregroundStyle(sel ? c : Color.secondary)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(sel ? c : .white.opacity(0.06), lineWidth: 1))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "signature")
                .font(.system(size: 40)).foregroundStyle(.quaternary)
            Text("契約がありません").font(.system(size: 14)).foregroundStyle(.tertiary)
            Button { showNewContract = true } label: {
                Text("最初の契約を作成")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.pon, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

// MARK: - StatCard

struct StatCard: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                .textCase(.uppercase).tracking(0.5)
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).glassCard()
    }
}

// MARK: - ContractRow

struct ContractRow: View {
    let contract: Contract
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.typeColor(for: contract.contractType).opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: contract.statusIcon).font(.system(size: 18))
                    .foregroundStyle(Color.statusColor(for: contract.status))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(contract.title.isEmpty ? "無題" : contract.title)
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(contract.clientName).font(.caption).foregroundStyle(.tertiary)
                    Text(contract.typeLabel)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.typeColor(for: contract.contractType).opacity(0.12))
                        .foregroundStyle(Color.typeColor(for: contract.contractType))
                        .clipShape(Capsule())
                    Text(contract.statusLabel)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.statusColor(for: contract.status).opacity(0.12))
                        .foregroundStyle(Color.statusColor(for: contract.status))
                        .clipShape(Capsule())
                }
            }
            Spacer(minLength: 4)
            if contract.amount > 0 {
                Text(contract.formattedAmount)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ponSigned)
            }
        }
        .padding(12).glassCard()
    }
}
