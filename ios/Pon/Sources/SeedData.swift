import Foundation
import SwiftData

enum SeedData {
    @MainActor
    static func insertIfEmpty(context: ModelContext) {
        let descriptor = FetchDescriptor<Contract>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let contracts: [(title: String, client: String, type: String, category: String, amount: Int, status: String, start: String, end: String?)] = [
            ("ウェブサイト制作業務委託契約", "株式会社ABC", "system_dev", "outsourcing", 500_000, "active", "2026-01-15", "2026-07-15"),
            ("秘密保持契約", "田中太郎", "mutual_nda", "nda", 0, "signed", "2026-02-01", nil),
            ("月額保守契約", "DEFテクノロジー", "maintenance", "service", 50_000, "active", "2026-01-01", "2027-01-01"),
            ("UIコンサルティング契約", "GHIデザイン", "consulting", "service", 200_000, "expired", "2025-06-01", "2025-12-31"),
            ("モバイルアプリ開発", "JKLスタートアップ", "system_dev", "outsourcing", 1_200_000, "draft", "2026-04-01", "2026-09-30"),
        ]

        for (index, c) in contracts.enumerated() {
            let start = dateFormatter.date(from: c.start) ?? .now
            let end = c.end.flatMap { dateFormatter.date(from: $0) }
            let contract = Contract(
                title: c.title,
                clientName: c.client,
                contractType: c.type,
                contractCategory: c.category,
                amount: c.amount,
                currency: "JPY",
                startDate: start,
                endDate: end
            )
            contract.status = c.status
            contract.contractNumber = Contract.generateNumber(date: start, count: index)
            context.insert(contract)
        }
    }
}
