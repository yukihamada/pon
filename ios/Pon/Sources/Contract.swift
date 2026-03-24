import Foundation
import SwiftData

@Model
final class Contract {
    var id: String
    var contractNumber: String       // PON-YYYYMM-NNN
    var title: String
    var clientName: String
    var clientEmail: String
    var contractType: String         // e.g. system_dev, mutual_nda, goods, consulting
    var contractCategory: String     // e.g. outsourcing, nda, sales, rental, employment, ip, service
    var status: String               // draft, sent, signed, active, expired, cancelled
    var amount: Int                  // 0 = TBD / pro bono
    var currency: String
    var startDate: Date
    var endDate: Date?               // nil = indefinite
    var memo: String
    var createdAt: Date
    var modifiedAt: Date

    // New fields: body, signatures, attachments, AI
    var bodyText: String
    var creatorSignature: Data?
    var clientSignature: Data?
    var creatorSignedAt: Date?
    var clientSignedAt: Date?
    var signingToken: String
    var attachmentPaths: String      // JSON array of file paths
    var aiGenerated: Bool

    // Computed
    var signURL: String { "https://pon-sign.fly.dev/sign/\(signingToken)" }
    var isBothSigned: Bool { creatorSignature != nil && clientSignature != nil }
    var attachmentsList: [String] {
        guard !attachmentPaths.isEmpty,
              let data = attachmentPaths.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return arr
    }

    init(
        title: String,
        clientName: String,
        clientEmail: String = "",
        contractType: String = "system_dev",
        contractCategory: String = "outsourcing",
        amount: Int = 0,
        currency: String = "JPY",
        startDate: Date = .now,
        endDate: Date? = nil,
        memo: String = "",
        bodyText: String = "",
        aiGenerated: Bool = false
    ) {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let uuid = UUID().uuidString.prefix(6)
        self.id = "pon_\(ts)_\(uuid)"
        self.contractNumber = ""
        self.title = title
        self.clientName = clientName
        self.clientEmail = clientEmail
        self.contractType = contractType
        self.contractCategory = contractCategory
        self.status = "draft"
        self.amount = amount
        self.currency = currency
        self.startDate = startDate
        self.endDate = endDate
        self.memo = memo
        self.createdAt = .now
        self.modifiedAt = .now
        self.bodyText = bodyText
        self.creatorSignature = nil
        self.clientSignature = nil
        self.creatorSignedAt = nil
        self.clientSignedAt = nil
        self.signingToken = UUID().uuidString
        self.attachmentPaths = "[]"
        self.aiGenerated = aiGenerated
    }

    // MARK: - Display

    var formattedAmount: String {
        if amount == 0 { return "未定" }
        if currency == "USD" { return "$\(amount / 100).\(String(format: "%02d", amount % 100))" }
        return "\u{00A5}\(amount.formatted())"
    }

    var typeLabel: String {
        if let tmpl = ContractTemplate.builtIn.first(where: { $0.id == contractType }) {
            return tmpl.name
        }
        // Legacy fallback
        switch contractType {
        case "nda": return "NDA"
        case "development": return "受託開発"
        case "maintenance": return "保守"
        case "consulting": return "コンサル"
        case "sales": return "売買"
        default: return contractType
        }
    }

    var categoryLabel: String {
        ContractCategory.all.first { $0.id == contractCategory }?.name ?? contractCategory
    }

    var statusLabel: String {
        switch status {
        case "draft": return "下書き"
        case "sent": return "送付済"
        case "signed": return "署名済"
        case "active": return "有効"
        case "expired": return "期限切れ"
        case "cancelled": return "取消"
        default: return status
        }
    }

    var isExpired: Bool { endDate.map { $0 < .now } ?? false }
    var isActive: Bool { status == "active" && !isExpired }

    var statusIcon: String {
        switch status {
        case "draft": return "doc.badge.ellipsis"
        case "sent": return "paperplane.fill"
        case "signed": return "checkmark.seal.fill"
        case "active": return "bolt.fill"
        case "expired": return "clock.badge.exclamationmark"
        case "cancelled": return "xmark.circle.fill"
        default: return "doc"
        }
    }

    static func generateNumber(date: Date, count: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMM"
        return "PON-\(f.string(from: date))-\(String(format: "%03d", count + 1))"
    }

    static let contractTypes: [String] = ContractCategory.all.flatMap { $0.templates.map { $0.id } }

    func addAttachment(_ path: String) {
        var list = attachmentsList
        list.append(path)
        if let data = try? JSONEncoder().encode(list), let str = String(data: data, encoding: .utf8) {
            attachmentPaths = str
        }
    }

    func removeAttachment(at index: Int) {
        var list = attachmentsList
        guard index >= 0 && index < list.count else { return }
        list.remove(at: index)
        if let data = try? JSONEncoder().encode(list), let str = String(data: data, encoding: .utf8) {
            attachmentPaths = str
        }
    }
    static let statuses = ["draft", "sent", "signed", "active", "expired", "cancelled"]
}
