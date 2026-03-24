import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    static let proProductID = "com.enablerdao.pon.pro"

    @Published var isPro = false
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    @Published var proProduct: Product?
    @Published var expirationDate: Date?

    private var transactionListener: Task<Void, Never>?

    var formattedPrice: String { proProduct?.displayPrice ?? "¥480/月" }

    init() {
        transactionListener = listenForTransactions()
        Task {
            await fetchProduct()
            await updateSubscriptionStatus()
        }
    }

    deinit { transactionListener?.cancel() }

    func fetchProduct() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            print("[SubscriptionManager] fetchProduct error: \(error)")
        }
    }

    func updateSubscriptionStatus() async {
        var foundPro = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if tx.productID == Self.proProductID && tx.revocationDate == nil {
                foundPro = true
                expirationDate = tx.expirationDate
                break
            }
        }
        isPro = foundPro
        if !foundPro { expirationDate = nil }
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
