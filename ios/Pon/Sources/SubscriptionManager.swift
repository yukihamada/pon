import StoreKit
import SwiftUI
import CryptoKit
import UIKit

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
                // Verify with server
                await syncTransactionToServer(tx)
            }
            if tx.productID == Self.founderProductID {
                foundFounder = true
                foundPro = true
                await syncTransactionToServer(tx)
            }
        }
        // Founder activation code also counts
        if founderActivated { foundFounder = true; foundPro = true }
        isPro = foundPro
        isFounder = foundFounder
        if !foundPro { expirationDate = nil }
    }

    private func syncTransactionToServer(_ tx: StoreKit.Transaction) async {
        guard let url = URL(string: "https://pon.enablerdao.com/api/subscription/verify") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let userId = deviceUserId
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime]

        var body: [String: Any] = [
            "user_id": userId,
            "product_id": tx.productID,
            "transaction_id": String(tx.id),
            "original_transaction_id": String(tx.originalID),
        ]
        if let exp = tx.expirationDate {
            body["expires_date"] = df.string(from: exp)
        }
        if let jwsData = try? tx.jsonRepresentation, let jwsStr = String(data: jwsData, encoding: .utf8) {
            body["jws_representation"] = jwsStr
        }

        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        // Fire and forget — don't block UI on network
        let _ = try? await URLSession.shared.data(for: req)
    }

    /// Stable device-based user ID (persists across app reinstalls via Keychain would be better,
    /// but UserDefaults + identifierForVendor is good enough for MVP)
    private var deviceUserId: String {
        if let saved = UserDefaults.standard.string(forKey: "pon_user_id") {
            return saved
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: "pon_user_id")
        return id
    }

    func activateFounder(code: String) -> Bool {
        // Validate via SHA256 hash comparison
        let input = code.lowercased().trimmingCharacters(in: .whitespaces)
        guard let data = input.data(using: .utf8) else { return false }
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let validHashes = [
            "0e6d988db1a517a85178adc25b89465ed4771bd8af539065beb42e948819a7ee",
            "16920e6e4defed0500c34615bfac5d851ef21eaa6b72cd5779cefca75b6f7dd9"
        ]
        if validHashes.contains(hex) {
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
