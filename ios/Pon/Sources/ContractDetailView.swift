import SwiftUI
import SwiftData
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ContractDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var contract: Contract
    @State private var showDeleteConfirm = false
    @State private var showSignature = false
    @State private var signatureImage: UIImage?
    @State private var showSignLinkCopied = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var isSyncing = false
    @State private var syncMessage: String? = nil

    private let nextStatus: [String: String] = [
        "draft": "sent", "sent": "signed", "signed": "active"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status hero
                VStack(spacing: 8) {
                    Image(systemName: contract.statusIcon)
                        .font(.system(size: 36))
                        .foregroundStyle(Color.statusColor(for: contract.status))
                    Text(contract.statusLabel)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.statusColor(for: contract.status))
                    if contract.amount > 0 {
                        Text(contract.formattedAmount)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.ponSigned)
                    }
                    // Both signed celebration
                    if contract.isBothSigned {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("契約完了")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ponSigned)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.ponSigned.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 20).frame(maxWidth: .infinity).glassCard()

                // Signing status
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("署名状況")
                    HStack {
                        Image(systemName: contract.creatorSignature != nil ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(contract.creatorSignature != nil ? Color.ponSigned : .secondary)
                        Text("自分:")
                            .font(.system(size: 13))
                        Text(contract.creatorSignature != nil ? "署名済み" : "未署名")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(contract.creatorSignature != nil ? Color.ponSigned : .secondary)
                        if let date = contract.creatorSignedAt {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    HStack {
                        Image(systemName: contract.clientSignature != nil ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(contract.clientSignature != nil ? Color.ponSigned : .secondary)
                        Text("相手:")
                            .font(.system(size: 13))
                        Text(contract.clientSignature != nil ? "署名済み" : "未署名")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(contract.clientSignature != nil ? Color.ponSigned : .secondary)
                        if let date = contract.clientSignedAt {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Creator signature image preview
                    if let sigData = contract.creatorSignature, let img = UIImage(data: sigData) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                    }
                }.padding(16).glassCard()

                // Sign button
                if contract.creatorSignature == nil {
                    Button {
                        showSignature = true
                    } label: {
                        HStack {
                            Image(systemName: "signature")
                            Text("署名する")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [Color.pon, Color.ponAccent],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .glassCard()
                }

                // Request client signature
                if contract.creatorSignature != nil && contract.clientSignature == nil {
                    ShareLink(item: contract.signURL) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("相手に署名を依頼")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.ponAccent)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.ponAccent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .glassCard()
                }

                // Sync to server button
                VStack(spacing: 8) {
                    Button {
                        syncContractToServer()
                    } label: {
                        HStack {
                            if isSyncing {
                                ProgressView().scaleEffect(0.8).tint(Color.ponAccent)
                            } else {
                                Image(systemName: syncMessage == "✓" ? "checkmark.circle.fill" : "icloud.and.arrow.up")
                            }
                            Text(isSyncing ? "同期中..." : syncMessage ?? "サーバーに同期")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(syncMessage == "✓" ? Color.ponSigned : Color.ponAccent)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background((syncMessage == "✓" ? Color.ponSigned : Color.ponAccent).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isSyncing)
                    Text("署名URLをWebで使えるようにします")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }.padding(16).glassCard()

                // Web signing link
                VStack(spacing: 10) {
                    Button {
                        generateSigningLink()
                    } label: {
                        HStack {
                            Image(systemName: showSignLinkCopied ? "checkmark.circle.fill" : "link.badge.plus")
                            Text(showSignLinkCopied ? "リンクをコピーしました！" : "署名依頼リンクを生成")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(showSignLinkCopied ? Color.ponSigned : Color.pon)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(showSignLinkCopied ? Color.ponSigned.opacity(0.12) : Color.pon.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text("リンクを開くとブラウザで契約内容の確認・署名ができます")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(16).glassCard()
                .sheet(isPresented: $showShareSheet) {
                    if let url = shareURL {
                        ShareSheet(items: [url])
                    }
                }

                // Details
                VStack(spacing: 0) {
                    detailRow("タイトル", contract.title)
                    detailRow("相手方", contract.clientName)
                    if !contract.clientEmail.isEmpty { detailRow("メール", contract.clientEmail) }
                    detailRow("種別", contract.typeLabel, Color.typeColor(for: contract.contractType))
                    detailRow("番号", contract.contractNumber, nil, true)
                    detailRow("開始日", contract.startDate.formatted(date: .long, time: .omitted))
                    if let end = contract.endDate {
                        detailRow("終了日", end.formatted(date: .long, time: .omitted))
                    }
                    detailRow("通貨", contract.currency)
                    if contract.aiGenerated { detailRow("AI生成", "はい", Color.ponAccent) }
                    if !contract.memo.isEmpty { detailRow("メモ", contract.memo) }
                }.glassCard()

                // Contract body text
                if !contract.bodyText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("契約書本文")
                        Text(contract.bodyText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.ponCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }.padding(16).glassCard()
                }

                // Attachments
                if !contract.attachmentsList.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("添付ファイル")
                        ForEach(contract.attachmentsList, id: \.self) { name in
                            HStack {
                                Image(systemName: "paperclip")
                                    .foregroundStyle(Color.ponAccent)
                                Text(name)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.ponCard)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }.padding(16).glassCard()
                }

                // Status progression
                if let next = nextStatus[contract.status] {
                    let nextLabel: String = switch next {
                    case "sent": "送付済みにする"
                    case "signed": "署名済みにする"
                    case "active": "有効にする"
                    default: next
                    }
                    Button {
                        contract.status = next
                        contract.modifiedAt = .now
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text(nextLabel)
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient(colors: [Color.pon, Color.ponAccent],
                                                   startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .glassCard()
                }

                // Share / Cancel / Delete
                HStack(spacing: 12) {
                    ShareLink(item: contractText) {
                        Label("共有", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.pon.opacity(0.12))
                            .foregroundStyle(Color.pon)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if contract.status != "cancelled" {
                        Button {
                            contract.status = "cancelled"
                            contract.modifiedAt = .now
                        } label: {
                            Label("取消", systemImage: "xmark.circle")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.ponDanger.opacity(0.12))
                                .foregroundStyle(Color.ponDanger)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("削除", systemImage: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }.glassCard()
            }
            .padding()
        }
        .background(Color.ponBg)
        .navigationTitle("契約詳細")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("この契約を削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("削除する", role: .destructive) { context.delete(contract); dismiss() }
        }
        .sheet(isPresented: $showSignature) {
            SignatureView(signatureImage: $signatureImage)
        }
        .onChange(of: signatureImage) { _, newImage in
            guard let newImage, let pngData = newImage.pngData() else { return }
            contract.creatorSignature = pngData
            contract.creatorSignedAt = .now
            contract.modifiedAt = .now
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            // Sync creator signature to server
            let b64 = "data:image/png;base64," + pngData.base64EncodedString()
            syncSignatureToServer(token: contract.signingToken, signer: "creator", signature: b64)
        }
        .onAppear {
            fetchStatusFromServer()
        }
    }

    private func generateSigningLink() {
        let urlString = contract.signURL  // https://pon-sign.fly.dev/sign/{signingToken}
        UIPasteboard.general.string = urlString
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { showSignLinkCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let url = URL(string: urlString) {
                shareURL = url
                showShareSheet = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showSignLinkCopied = false }
        }
    }

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            .textCase(.uppercase).tracking(1)
    }

    private func detailRow(_ label: String, _ value: String, _ color: Color? = nil, _ mono: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer()
            if let color {
                Text(value).font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.12)).foregroundStyle(color).clipShape(Capsule())
            } else if mono {
                Text(value).font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.pon)
            } else {
                Text(value).font(.system(size: 13, weight: .medium)).lineLimit(2)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.04)).frame(height: 0.5) }
    }

    private func syncContractToServer() {
        guard let url = URL(string: "https://pon-sign.fly.dev/api/contracts") else { return }
        isSyncing = true
        syncMessage = nil
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]
        var body: [String: Any] = [
            "token": contract.signingToken,
            "title": contract.title,
            "client_name": contract.clientName,
            "contract_type": contract.contractType,
            "amount": contract.amount,
            "currency": contract.currency,
            "body_text": contract.bodyText.isEmpty ? "(本文未入力)" : contract.bodyText,
            "creator_name": UserDefaults.standard.string(forKey: "ownerName") ?? "作成者",
            "start_date": df.string(from: contract.startDate),
        ]
        if !contract.clientEmail.isEmpty { body["client_email"] = contract.clientEmail }
        if let end = contract.endDate { body["end_date"] = df.string(from: end) }
        let creatorEmail = UserDefaults.standard.string(forKey: "ownerEmail") ?? ""
        if !creatorEmail.isEmpty { body["creator_email"] = creatorEmail }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { _, res, err in
            let success: Bool
            if let http = res as? HTTPURLResponse {
                success = http.statusCode == 201 || http.statusCode == 200 || http.statusCode == 409
            } else {
                success = false
            }

            // After contract is synced, also send creator signature if it exists
            if success, let sigData = contract.creatorSignature {
                let b64 = "data:image/png;base64," + sigData.base64EncodedString()
                syncSignatureToServer(token: contract.signingToken, signer: "creator", signature: b64)
            }

            DispatchQueue.main.async {
                isSyncing = false
                syncMessage = success ? "✓" : "再試行してください"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { syncMessage = nil }
            }
        }.resume()
    }

    private func syncSignatureToServer(token: String, signer: String, signature: String) {
        guard let url = URL(string: "https://pon-sign.fly.dev/api/sign/\(token)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["signer": signer, "signature": signature])
        URLSession.shared.dataTask(with: req).resume()
    }

    private func fetchStatusFromServer() {
        guard let url = URL(string: "https://pon-sign.fly.dev/api/contracts/\(contract.id)") else { return }
        // Try by id first; the server contract may not match local id, so also try token-based lookup
        // For now we check via sign page endpoint which uses token
        guard let statusUrl = URL(string: "https://pon-sign.fly.dev/api/contracts/token/\(contract.signingToken)") else { return }
        URLSession.shared.dataTask(with: URLRequest(url: statusUrl)) { data, _, _ in
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            DispatchQueue.main.async {
                if let status = json["status"] as? String {
                    contract.status = status == "completed" ? "signed" : contract.status
                }
                if let clientSig = json["client_signature"] as? String, !clientSig.isEmpty,
                   contract.clientSignature == nil,
                   let sigData = Data(base64Encoded: clientSig.replacingOccurrences(of: "data:image/png;base64,", with: "")) {
                    contract.clientSignature = sigData
                    contract.clientSignedAt = .now
                    contract.modifiedAt = .now
                }
            }
        }.resume()
    }

    private var contractText: String {
        var text = """
        ポン 契約書
        ────────────
        番号: \(contract.contractNumber)
        タイトル: \(contract.title)
        相手方: \(contract.clientName)
        種別: \(contract.typeLabel)
        金額: \(contract.formattedAmount)
        期間: \(contract.startDate.formatted(date: .long, time: .omitted))\(contract.endDate.map { " 〜 " + $0.formatted(date: .long, time: .omitted) } ?? " 〜 無期限")
        ステータス: \(contract.statusLabel)
        """
        if !contract.bodyText.isEmpty {
            text += "\n────────────\n\(contract.bodyText)"
        }
        text += "\n────────────\nGenerated by PON"
        return text
    }
}
