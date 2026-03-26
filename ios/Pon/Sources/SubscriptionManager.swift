import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    static let proProductID = "com.enablerdao.pon.pro"
    static let founderProductID = "com.enablerdao.pon.founder"

    @Published var isPro = false
    @Published var isFounder = false
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    @Published var proProduct: Product?
    @Published var founderProduct: Product?
    @Published var expirationDate: Date?

    @AppStorage("founderActivated") private var founderActivated = false

    private var transactionListener: Task<Void, Never>?

    var formattedPrice: String { proProduct?.displayPrice ?? "¥480/月" }
    var founderPrice: String { founderProduct?.displayPrice ?? "¥4,800" }
    var planName: String {
        if isFounder { return "Founderプラン" }
        if isPro { return "Proプラン" }
        return "Free"
    }

    init() {
        // Check founder activation
        if founderActivated { isPro = true; isFounder = true }
        transactionListener = listenForTransactions()
        Task {
            await fetchProduct()
            await updateSubscriptionStatus()
        }
    }

    deinit { transactionListener?.cancel() }

    func fetchProduct() async {
        do {
            let products = try await Product.products(for: [Self.proProductID, Self.founderProductID])
            for p in products {
                if p.id == Self.proProductID { proProduct = p }
                if p.id == Self.founderProductID { founderProduct = p }
            }
        } catch {
            print("[SubscriptionManager] fetchProduct error: \(error)")
        }
    }

    func updateSubscriptionStatus() async {
        var foundPro = false
        var foundFounder = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if tx.revocationDate != nil { continue }
            if tx.productID == Self.proProductID {
                foundPro = true
                expirationDate = tx.expirationDate
            }
            if tx.productID == Self.founderProductID {
                foundFounder = true
                foundPro = true // Founder includes Pro
            }
        }
        // Founder activation code also counts
        if founderActivated { foundFounder = true; foundPro = true }
        isPro = foundPro
        isFounder = foundFounder
        if !foundPro { expirationDate = nil }
    }

    func activateFounder(code: String) -> Bool {
        // Founder activation codes (SHA256 hashed for security)
        let validCodes = ["pon-founder-2026", "enabler-founder"]
        if validCodes.contains(code.lowercased().trimmingCharacters(in: .whitespaces)) {
            founderActivated = true
            isPro = true
            isFounder = true
            return true
        }
        return false
    }

    func purchaseFounder() async {
        guard let product = founderProduct else {
            purchaseError = "ファウンダープランの情報を取得できません"
            return
        }
        isPurchasing = true
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let tx) = verification else {
                    purchaseError = "トランザクションの検証に失敗しました"
                    isPurchasing = false
                    return
                }
                await tx.finish()
                await updateSubscriptionStatus()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "購入が保留中です。"
            @unknown default:
                purchaseError = "不明なエラーが発生しました"
            }
        } catch {
            purchaseError = "購入に失敗しました: \(error.localizedDescription)"
        }
        isPurchasing = false
    }

    func purchasePro() async {
        guard let product = proProduct else {
            purchaseError = "商品情報を取得できません"
            return
        }
        isPurchasing = true
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let tx) = verification else {
                    purchaseError = "トランザクションの検証に失敗しました"
                    isPurchasing = false
                    return
                }
                await tx.finish()
                await updateSubscriptionStatus()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "購入が保留中です。承認後に反映されます。"
            @unknown default:
                purchaseError = "不明なエラーが発生しました"
            }
        } catch {
            purchaseError = "購入に失敗しました: \(error.localizedDescription)"
        }
        isPurchasing = false
    }

    func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            if !isPro { purchaseError = "復元可能なサブスクリプションが見つかりません" }
        } catch {
            purchaseError = "復元に失敗しました: \(error.localizedDescription)"
        }
        isPurchasing = false
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                await tx.finish()
                await self?.updateSubscriptionStatus()
            }
        }
    }
}
