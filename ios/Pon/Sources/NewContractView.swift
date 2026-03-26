import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct NewContractView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Contract.createdAt, order: .reverse) private var all: [Contract]

    // Step state
    @State private var step = 1  // 1: type, 2: parties+amount, 3: template+edit, 4: confirm

    // Contract fields
    @State private var selectedCategory: ContractCategory?
    @State private var selectedTemplate: ContractTemplate?
    @State private var contractType = ""
    @State private var title = ""
    @State private var clientName = ""
    @State private var clientEmail = ""
    @State private var amount = ""
    @State private var currency = "JPY"
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var memo = ""
    @State private var bodyText = ""
    @State private var aiGenerated = false
    @State private var showCelebration = false

    // Attachments
    @State private var showFilePicker = false
    @State private var attachmentNames: [String] = []

    // AI
    @AppStorage("aiGenerationCount") private var aiGenCount = 0
    @State private var showAIGenerator = false

    private static let titleMax = 100
    private static let clientMax = 100
    private static let amountMax = 999_999_999

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ponBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress bar
                    progressBar

                    ScrollView {
                        VStack(spacing: 16) {
                            switch step {
                            case 1: stepOneType
                            case 2: stepTwoParties
                            case 3: stepThreeTemplate
                            case 4: stepFourConfirm
                            default: EmptyView()
                            }
                        }
                        .padding()
                        .animation(.easeInOut(duration: 0.3), value: step)
                    }

                    // Bottom nav buttons
                    bottomBar
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(.secondary)
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
            .sheet(isPresented: $showAIGenerator) {
                AIContractGeneratorView()
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf, .image, .plainText], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    for url in urls {
                        attachmentNames.append(url.lastPathComponent)
                    }
                }
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case 1: return "契約種別"
        case 2: return "基本情報"
        case 3: return "契約内容"
        case 4: return "確認"
        default: return "新規契約"
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(1...4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= step ? Color.pon : Color.white.opacity(0.06))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Step 1: Contract Type (Category -> Sub-template)

    private var stepOneType: some View {
        VStack(alignment: .leading, spacing: 16) {
            // AI Generator shortcut
            Button {
                showAIGenerator = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.ponAccent.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.ponAccent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AIで生成")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.ponAccent)
                        Text("情報を入力するだけで完全な契約書を自動生成")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(Color.ponAccent.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.ponAccent.opacity(0.2), lineWidth: 1))
            }

            HStack {
                Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5)
                Text("または手動で選択").font(.system(size: 11)).foregroundStyle(.tertiary).fixedSize()
                Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5)
            }

            if selectedCategory == nil {
                // Phase 1: Category selection
                Text("どんな契約を結びますか？")
                    .font(.system(size: 20, weight: .bold))

                ForEach(ContractCategory.all) { cat in
                    categoryCard(cat)
                }
            } else {
                // Phase 2: Sub-template selection
                Button {
                    withAnimation { selectedCategory = nil; selectedTemplate = nil; contractType = "" }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text("カテゴリに戻る").font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.pon)
                }

                if let cat = selectedCategory {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.categoryColor(for: cat.id).opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: cat.icon).font(.system(size: 16)).foregroundStyle(Color.categoryColor(for: cat.id))
                        }
                        Text(cat.name).font(.system(size: 20, weight: .bold))
                    }

                    Text("テンプレートを選択してください")
                        .font(.system(size: 13)).foregroundStyle(.secondary)

                    ForEach(cat.templates) { tmpl in
                        templateCard(tmpl, category: cat)
                    }
                }
            }
        }
    }

    private func categoryCard(_ cat: ContractCategory) -> some View {
        let c = Color.categoryColor(for: cat.id)
        return Button {
            withAnimation { selectedCategory = cat }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(c.opacity(0.12)).frame(width: 48, height: 48)
                    Image(systemName: cat.icon).font(.system(size: 20)).foregroundStyle(c)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(cat.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text(cat.description).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(cat.templates.count)テンプレート")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(c)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(c.opacity(0.1))
                    .clipShape(Capsule())
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.06), lineWidth: 0.5))
        }
    }

    private func templateCard(_ tmpl: ContractTemplate, category cat: ContractCategory) -> some View {
        let sel = selectedTemplate?.id == tmpl.id
        let c = Color.categoryColor(for: cat.id)
        return Button {
            selectedTemplate = tmpl
            contractType = tmpl.id
            title = tmpl.name
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(sel ? c.opacity(0.2) : .white.opacity(0.04))
                        .frame(width: 28, height: 28)
                    if sel {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(c)
                    } else {
                        Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1.5).frame(width: 18, height: 18)
                    }
                }
                Text(tmpl.name)
                    .font(.system(size: 14, weight: sel ? .semibold : .regular))
                    .foregroundStyle(sel ? .white : .secondary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(sel ? c.opacity(0.06) : .white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(sel ? c : .white.opacity(0.06), lineWidth: sel ? 1.5 : 0.5))
        }
    }

    // MARK: - Step 2: Parties & Amount

    private var stepTwoParties: some View {
        VStack(spacing: 16) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("契約タイトル")
                TextField("ウェブサイト制作業務委託契約", text: $title)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(14).background(Color.ponCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.06)))
                    .onChange(of: title) { _, v in if v.count > Self.titleMax { title = String(v.prefix(Self.titleMax)) } }
            }.padding(16).glassCard()

            // Client
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("相手方")
                TextField("クライアント名", text: $clientName).inputStyle()
                    .onChange(of: clientName) { _, v in if v.count > Self.clientMax { clientName = String(v.prefix(Self.clientMax)) } }
                TextField("メールアドレス (任意)", text: $clientEmail).inputStyle()
                    .keyboardType(.emailAddress).textContentType(.emailAddress)
            }.padding(16).glassCard()

            // Amount
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("契約金額")
                HStack(spacing: 12) {
                    TextField("0", text: $amount)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ponSigned).keyboardType(.numberPad).frame(maxWidth: .infinity)
                        .onChange(of: amount) { _, v in
                            let c = v.replacingOccurrences(of: ",", with: "")
                            if let n = Int(c), n > Self.amountMax { amount = String(Self.amountMax) }
                        }
                    Picker("", selection: $currency) {
                        Text("JPY").tag("JPY"); Text("USD").tag("USD")
                    }.pickerStyle(.segmented).frame(width: 120)
                }
            }.padding(16).glassCard()

            // Dates
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("期間")
                DatePicker("開始日", selection: $startDate, displayedComponents: .date).tint(Color.pon)
                Toggle("終了日あり", isOn: $hasEndDate).tint(Color.pon)
                if hasEndDate {
                    DatePicker("終了日", selection: $endDate, displayedComponents: .date).tint(Color.pon)
                }
            }.padding(16).glassCard()
        }
    }

    // MARK: - Step 3: Template & Edit

    private var stepThreeTemplate: some View {
        VStack(spacing: 16) {
            // Generate from template button
            if bodyText.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("テンプレートから生成")
                    Text("種別に合った契約書テンプレートを自動生成します")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    Button {
                        generateFromTemplate()
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("テンプレートを適用")
                        }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.pon).clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // AI option
                    Button {
                        generateWithAI()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles").foregroundStyle(Color.ponAccent)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("AIで契約書を作成")
                                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.ponAccent)
                                if aiGenCount > 0 {
                                    Text("Pro限定 (無料枠使用済み)")
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                } else {
                                    Text("初回1回無料")
                                        .font(.system(size: 10)).foregroundStyle(Color.ponSigned)
                                }
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.ponAccent.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ponAccent.opacity(0.15)))
                    }
                    .disabled(aiGenCount > 0) // Pro check would go here
                }.padding(16).glassCard()
            }

            // Editable body
            if !bodyText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        sectionLabel("契約書本文")
                        Spacer()
                        if aiGenerated {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles").font(.system(size: 10))
                                Text("AI生成").font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(Color.ponAccent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.ponAccent.opacity(0.1)).clipShape(Capsule())
                        }
                    }
                    Text("内容は自由に編集できます")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)

                    TextEditor(text: $bodyText)
                        .font(.system(size: 13))
                        .frame(minHeight: 400)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(Color.ponCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.06)))

                    Button {
                        bodyText = ""
                        aiGenerated = false
                    } label: {
                        Label("テンプレートを変更", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    }
                }.padding(16).glassCard()
            }

            // Attachments
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("添付ファイル")
                if !attachmentNames.isEmpty {
                    ForEach(Array(attachmentNames.enumerated()), id: \.offset) { idx, name in
                        HStack {
                            Image(systemName: "paperclip").foregroundStyle(.secondary)
                            Text(name).font(.system(size: 13)).lineLimit(1)
                            Spacer()
                            Button { attachmentNames.remove(at: idx) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color.ponCard)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                Button { showFilePicker = true } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("ファイルを添付")
                    }
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.pon)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.pon.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }.padding(16).glassCard()

            // Memo
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("メモ (社内用)")
                TextField("備考...", text: $memo, axis: .vertical).lineLimit(2...4).inputStyle()
            }.padding(16).glassCard()
        }
    }

    // MARK: - Step 4: Confirm

    private var stepFourConfirm: some View {
        VStack(spacing: 16) {
            // Summary card
            VStack(spacing: 0) {
                confirmRow("カテゴリ", selectedCategory?.name ?? "", Color.categoryColor(for: selectedCategory?.id ?? ""))
                confirmRow("種別", typeLabel(contractType), Color.typeColor(for: contractType))
                confirmRow("タイトル", title)
                confirmRow("相手方", clientName)
                if !clientEmail.isEmpty { confirmRow("メール", clientEmail) }
                confirmRow("金額", amountDisplay)
                confirmRow("開始日", dateStr(startDate))
                if hasEndDate { confirmRow("終了日", dateStr(endDate)) }
                confirmRow("契約書本文", bodyText.isEmpty ? "未作成" : "\(bodyText.prefix(30))...", bodyText.isEmpty ? .secondary : nil)
                if !attachmentNames.isEmpty { confirmRow("添付", "\(attachmentNames.count)ファイル") }
                if aiGenerated { confirmRow("AI生成", "はい", Color.ponAccent) }
            }.glassCard()

            // Preview body text
            if !bodyText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("契約書プレビュー")
                    Text(bodyText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(20)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.ponCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }.padding(16).glassCard()
            }
        }
    }

    private func confirmRow(_ label: String, _ value: String, _ color: Color? = nil) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer()
            if let color {
                Text(value).font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.12)).foregroundStyle(color).clipShape(Capsule())
            } else {
                Text(value).font(.system(size: 13, weight: .medium)).lineLimit(1)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.04)).frame(height: 0.5) }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step > 1 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Text("戻る")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.06)))
                }
            }

            Button {
                if step < 4 {
                    withAnimation { step += 1 }
                } else {
                    save()
                }
            } label: {
                Text(step == 4 ? "契約を作成" : "次へ")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(canProceed ? Color.pon : Color.pon.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canProceed)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var canProceed: Bool {
        switch step {
        case 1: return selectedTemplate != nil && !contractType.isEmpty
        case 2: return !title.isEmpty && !clientName.isEmpty
        case 3: return true // body is optional (can be added later)
        case 4: return true
        default: return false
        }
    }

    // MARK: - Template Generation

    private func generateFromTemplate() {
        guard let tmpl = selectedTemplate ?? ContractTemplate.builtIn.first(where: { $0.id == contractType }) else { return }
        bodyText = tmpl.fillPlaceholders(
            title: title,
            creatorName: "Yuki Hamada",
            clientName: clientName,
            amount: amountDisplay,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil
        )
    }

    private func generateWithAI() {
        // For MVP: enhanced template generation with more detail
        guard aiGenCount == 0 else { return } // Pro check
        generateFromTemplate()
        // Add AI-enhanced header
        let header = "【AI生成契約書】\n本契約書はAIにより生成されました。内容を確認・修正のうえご使用ください。\n\n"
        bodyText = header + bodyText
        aiGenerated = true
        aiGenCount += 1
    }

    // MARK: - Save

    private func save() {
        let amt = min(Int(amount.replacingOccurrences(of: ",", with: "")) ?? 0, Self.amountMax)
        let c = Contract(
            title: String(title.prefix(Self.titleMax)),
            clientName: String(clientName.prefix(Self.clientMax)),
            clientEmail: clientEmail,
            contractType: contractType,
            contractCategory: selectedCategory?.id ?? "outsourcing",
            amount: amt,
            currency: currency,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            memo: memo,
            bodyText: bodyText,
            aiGenerated: aiGenerated
        )
        c.contractNumber = Contract.generateNumber(date: startDate, count: all.count)
        for name in attachmentNames { c.addAttachment(name) }
        context.insert(c)
        // Sync to server so the web signing URL works
        syncContractToServer(c)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        SoundPlayer.shared.play("pon")
        showCelebration = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
    }

    private func syncContractToServer(_ c: Contract) {
        guard let url = URL(string: "https://pon.enablerdao.com/api/contracts") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]
        var body: [String: Any] = [
            "token": c.signingToken,
            "title": c.title,
            "client_name": c.clientName,
            "contract_type": c.contractType,
            "amount": c.amount,
            "currency": c.currency,
            "body_text": c.bodyText.isEmpty ? "(本文未入力)" : c.bodyText,
            "creator_name": UserDefaults.standard.string(forKey: "ownerName") ?? "作成者",
            "start_date": df.string(from: c.startDate),
        ]
        if !c.clientEmail.isEmpty { body["client_email"] = c.clientEmail }
        if let end = c.endDate { body["end_date"] = df.string(from: end) }
        let creatorEmail = UserDefaults.standard.string(forKey: "ownerEmail") ?? ""
        if !creatorEmail.isEmpty { body["creator_email"] = creatorEmail }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: - Helpers

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            .textCase(.uppercase).tracking(1)
    }

    private func typeLabel(_ t: String) -> String {
        if let tmpl = ContractTemplate.builtIn.first(where: { $0.id == t }) {
            return tmpl.name
        }
        return t
    }

    private var amountDisplay: String {
        let cleaned = amount.replacingOccurrences(of: ",", with: "")
        guard let n = Int(cleaned), n > 0 else { return "未定" }
        return currency == "JPY" ? "\(n.formatted())円" : "$\(n.formatted())"
    }

    private func dateStr(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy年M月d日"; return f.string(from: d)
    }
}

// MARK: - Input Style

extension View {
    func inputStyle() -> some View {
        self.font(.system(size: 14))
            .padding(12)
            .background(Color.ponCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.06)))
    }
}
