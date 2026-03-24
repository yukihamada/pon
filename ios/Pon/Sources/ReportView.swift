import SwiftUI
import SwiftData
import Charts

struct ReportView: View {
    @Query(sort: \Contract.createdAt, order: .reverse) private var all: [Contract]
    @State private var year = Calendar.current.component(.year, from: .now)

    private var yearContracts: [Contract] {
        all.filter { Calendar.current.component(.year, from: $0.createdAt) == year }
    }
    private var activeCount: Int { yearContracts.filter { $0.status == "active" || $0.status == "signed" }.count }
    private var totalAmt: Int { yearContracts.filter { $0.currency == "JPY" }.reduce(0) { $0 + $1.amount } }

    private var monthlyData: [(month: Int, count: Int)] {
        var d: [Int: Int] = [:]
        for c in yearContracts { d[Calendar.current.component(.month, from: c.createdAt), default: 0] += 1 }
        return (1...12).map { (month: $0, count: d[$0] ?? 0) }
    }

    private var typeData: [(type: String, count: Int)] {
        var d: [String: Int] = [:]
        for c in yearContracts { d[c.contractType, default: 0] += 1 }
        return d.sorted { $0.value > $1.value }.map { (type: $0.key, count: $0.value) }
    }

    private var statusData: [(status: String, count: Int)] {
        var d: [String: Int] = [:]
        for c in yearContracts { d[c.status, default: 0] += 1 }
        return d.sorted { $0.value > $1.value }.map { (status: $0.key, count: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Year selector
                    HStack {
                        Button { year -= 1 } label: { Image(systemName: "chevron.left").foregroundStyle(.secondary) }
                        Spacer()
                        Text("\(String(year))年").font(.system(size: 16, weight: .bold))
                        Spacer()
                        Button { year += 1 } label: { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
                    }.padding(.horizontal, 16).padding(.vertical, 12).glassCard()

                    // Summary
                    HStack(spacing: 10) {
                        StatCard(label: "契約数", value: "\(yearContracts.count)", color: Color.pon)
                        StatCard(label: "有効", value: "\(activeCount)", color: Color.ponSigned)
                        StatCard(label: "総額", value: totalAmt > 0 ? "\u{00A5}\(totalAmt.formatted())" : "-", color: Color.ponAccent)
                    }

                    // Monthly chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("月別推移").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase).tracking(1)
                        Chart(monthlyData, id: \.month) {
                            BarMark(x: .value("月", "\($0.month)月"), y: .value("件", $0.count))
                                .foregroundStyle(LinearGradient(colors: [Color.pon, Color.ponAccent], startPoint: .bottom, endPoint: .top))
                                .cornerRadius(4)
                        }
                        .chartYAxis { AxisMarks { AxisValueLabel().font(.system(size: 9)).foregroundStyle(.secondary) } }
                        .chartXAxis { AxisMarks { AxisValueLabel().font(.system(size: 9)).foregroundStyle(.secondary) } }
                        .frame(height: 180)
                    }.padding(16).glassCard()

                    // Type breakdown
                    if !typeData.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("種別").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase).tracking(1)
                            ForEach(typeData, id: \.type) { item in
                                let label: String = switch item.type {
                                case "nda": "NDA"
                                case "development": "受託開発"
                                case "maintenance": "保守"
                                case "consulting": "コンサル"
                                default: item.type
                                }
                                HStack {
                                    Circle().fill(Color.typeColor(for: item.type)).frame(width: 8, height: 8)
                                    Text(label).font(.system(size: 13, weight: .medium)).frame(width: 70, alignment: .leading)
                                    Spacer()
                                    Text("\(item.count)件").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Color.typeColor(for: item.type))
                                }
                            }
                        }.padding(16).glassCard()
                    }

                    // Status breakdown
                    if !statusData.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ステータス").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase).tracking(1)
                            ForEach(statusData, id: \.status) { item in
                                let sl: String = switch item.status {
                                case "draft": "下書き"; case "sent": "送付済"; case "signed": "署名済"
                                case "active": "有効"; case "expired": "期限切れ"; case "cancelled": "取消"
                                default: item.status
                                }
                                HStack {
                                    Circle().fill(Color.statusColor(for: item.status)).frame(width: 8, height: 8)
                                    Text(sl).font(.system(size: 13, weight: .medium)).frame(width: 70, alignment: .leading)
                                    Spacer()
                                    Text("\(item.count)件").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Color.statusColor(for: item.status))
                                }
                            }
                        }.padding(16).glassCard()
                    }
                }.padding().padding(.bottom, 100)
            }
            .background(Color.ponBg)
            .navigationTitle("レポート")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
