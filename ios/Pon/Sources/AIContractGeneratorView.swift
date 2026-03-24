import SwiftUI
import SwiftData

struct AIContractGeneratorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Contract.createdAt, order: .reverse) private var all: [Contract]

    // Form state
    @State private var contractType: AIContractGenerator.ContractType = .businessCommission
    @State private var partyA = ""
    @State private var partyA_address = ""
    @State private var partyB = ""
    @State private var partyB_address = ""
    @State private var startDate = Date.now
    @State private var hasEndDate = true
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var amount = ""
    @State private var scope = ""
    @State private var deliverables = ""
    @State private var paymentTerms = ""
    @State private var specialClauses = ""

    // Preview state
    @State private var generatedText = ""
    @State private var showPreview = false
    @State private var showCelebration = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ponBg.ignoresSafeArea()

                if showPreview {
                    previewView
                } else {
                    formView
                }
            }
            .navigationTitle(showPreview ? "契約書プレビュー" : "AIで契約書を生成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showPreview ? "戻る" : "キャンセル") {
                        if showPreview {
                            withAnimation { showPreview = false }
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if showCelebration {
                    ZStack {
                        ConfettiView(colors: [Color.pon, Color.ponAccent, .white])
                        StampEffect(color: .pon)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showCelebration)
        }
    }

    // MARK: - Form View

    private var formView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // AI Badge
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.ponAccent)
                    Text("入力内容から完全な契約書を生成します")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.ponAccent.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ponAccent.opacity(0.15)))

                // Contract type
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("契約種別")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(AIContractGenerator.ContractType.allCases, id: \.self) { type in
                                Button {
                                    withAnimation(.spring(duration: 0.2)) { contractType = type }
                                } label: {
                                    Text(type.rawValue)
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(contractType == type ? Color.pon.opacity(0.15) : .white.opacity(0.03))
                                        .foregroundStyle(contractType == type ? Color.pon : .secondary)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(contractType == type ? Color.pon : .white.opacity(0.06), lineWidth: contractType == type ? 1.5 : 0.5))
                                }
                            }
                        }
                    }
                }.padding(16).glassCard()

                // Parties
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("甲（依頼者）")
                    TextField("会社名または氏名", text: $partyA).inputStyle()
                    TextField("住所（任意）", text: $partyA_address).inputStyle()

                    Divider().background(.white.opacity(0.08)).padding(.vertical, 4)

                    sectionLabel("乙（受託者）")
                    TextField("会社名または氏名", text: $partyB).inputStyle()
                    TextField("住所（任意）", text: $partyB_address).inputStyle()
                }.padding(16).glassCard()

                // Period
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("契約期間")
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date).tint(Color.pon)
                    Toggle("終了日あり", isOn: $hasEndDate).tint(Color.pon)
                    if hasEndDate {
                        DatePicker("終了日", selection: $endDate, displayedComponents: .date).tint(Color.pon)
                    }
                }.padding(16).glassCard()

                // Amount
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("金額（任意）")
                    HStack {
                        Text("¥").foregroundStyle(.secondary)
                        TextField("0", text: $amount).keyboardType(.numberPad)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ponSigned)
                    }
                    .padding(12)
                    .background(Color.ponCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.06)))
                }.padding(16).glassCard()

                // Scope & Deliverables
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("業務内容")
                    TextField("例：Webサイトのデザイン・制作業務", text: $scope, axis: .vertical)
                        .lineLimit(2...4).inputStyle()

                    sectionLabel("成果物・納品物")
                    TextField("例：デザインカンプ、HTML/CSS/JSファイル一式", text: $deliverables, axis: .vertical)
                        .lineLimit(2...4).inputStyle()
                }.padding(16).glassCard()

                // Payment terms
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("支払条件（任意）")
                    TextField("例：毎月末日締め翌月末日払い、銀行振込", text: $paymentTerms, axis: .vertical)
                        .lineLimit(2...3).inputStyle()
                }.padding(16).glassCard()

                // Special clauses
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("特約事項（任意）")
                    TextField("追加条件があれば記入...", text: $specialClauses, axis: .vertical)
                        .lineLimit(2...4).inputStyle()
                }.padding(16).glassCard()

                // Generate button
                Button {
                    generateContract()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                        Text("契約書を生成")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(
                        canGenerate
                            ? LinearGradient(colors: [Color.pon, Color.ponAccent], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.pon.opacity(0.3), Color.ponAccent.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canGenerate)
            }
            .padding()
            .padding(.bottom, 40)
        }
    }

    // MARK: - Preview View

    private var previewView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // AI badge
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 12))
                        Text("AI生成 — 内容を確認・編集のうえご利用ください")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.ponAccent)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.ponAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(generatedText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.ponCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
                .padding(.bottom, 120)
            }

            // Bottom action bar
            VStack(spacing: 12) {
                Button {
                    createContract()
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("この内容で契約書を作成")
                    }
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient(colors: [Color.pon, Color.ponAccent], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Text("作成後も内容の編集が可能です")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    private var canGenerate: Bool {
        !partyA.isEmpty && !partyB.isEmpty
    }

    private func generateContract() {
        let params = AIContractGenerator.ContractParams(
            type: contractType,
            partyA: partyA,
            partyA_address: partyA_address,
            partyB: partyB,
            partyB_address: partyB_address,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            amount: Int(amount.replacingOccurrences(of: ",", with: "")),
            scope: scope,
            deliverables: deliverables,
            paymentTerms: paymentTerms,
            specialClauses: specialClauses
        )
        generatedText = AIContractGenerator.generate(params: params)
        withAnimation { showPreview = true }
    }

    private func createContract() {
        let amtInt = Int(amount.replacingOccurrences(of: ",", with: "")) ?? 0
        let c = Contract(
            title: "\(partyB) — \(contractType.rawValue)契約",
            clientName: partyB,
            clientEmail: "",
            contractType: contractTypeID,
            contractCategory: contractCategoryID,
            amount: amtInt,
            currency: "JPY",
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            memo: "",
            bodyText: generatedText,
            aiGenerated: true
        )
        c.contractNumber = Contract.generateNumber(date: startDate, count: all.count)
        context.insert(c)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        SoundPlayer.shared.play("pon")
        showCelebration = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
    }

    private var contractTypeID: String {
        switch contractType {
        case .businessCommission: return "outsourcing_commission"
        case .nda: return "mutual_nda"
        case .systemDev: return "system_dev"
        case .consulting: return "consulting"
        case .sales: return "goods_purchase"
        case .employment: return "employment"
        case .rental: return "rental_property"
        case .service: return "service_agreement"
        }
    }

    private var contractCategoryID: String {
        switch contractType {
        case .businessCommission, .systemDev: return "outsourcing"
        case .nda: return "nda"
        case .consulting: return "service"
        case .sales: return "sales"
        case .employment: return "employment"
        case .rental: return "rental"
        case .service: return "service"
        }
    }

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            .textCase(.uppercase).tracking(1)
    }
}
