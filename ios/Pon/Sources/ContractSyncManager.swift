import Foundation
import SwiftData

/// Syncs all local contracts to the server on app launch.
/// - Creates contracts on server if not yet synced
/// - Sends creator signature if signed locally
/// - Fetches client signature from server if signed on web
@MainActor
class ContractSyncManager {
    static let shared = ContractSyncManager()
    private let baseURL = "https://pon.enablerdao.com"

    func syncAll(context: ModelContext) {
        let descriptor = FetchDescriptor<Contract>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let contracts = try? context.fetch(descriptor) else { return }

        for contract in contracts {
            syncContract(contract)
        }
    }

    private func syncContract(_ contract: Contract) {
        // Step 1: Create contract on server (will 409 if already exists)
        guard let url = URL(string: "\(baseURL)/api/contracts") else { return }
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

        URLSession.shared.dataTask(with: req) { [weak self] _, res, _ in
            guard let http = res as? HTTPURLResponse,
                  http.statusCode == 201 || http.statusCode == 200 || http.statusCode == 409 else { return }

            // Step 2: Send creator signature if exists
            if let sigData = contract.creatorSignature {
                let b64 = "data:image/png;base64," + sigData.base64EncodedString()
                self?.sendSignature(token: contract.signingToken, signer: "creator", signature: b64)
            }

            // Step 3: Fetch server status (client may have signed on web)
            self?.fetchServerStatus(contract: contract)
        }.resume()
    }

    private func sendSignature(token: String, signer: String, signature: String) {
        guard let url = URL(string: "\(baseURL)/api/sign/\(token)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["signer": signer, "signature": signature])
        URLSession.shared.dataTask(with: req).resume()
    }

    private func fetchServerStatus(contract: Contract) {
        guard let url = URL(string: "\(baseURL)/api/contracts/token/\(contract.signingToken)") else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { data, _, _ in
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            DispatchQueue.main.async {
                // Update local status from server
                if let status = json["status"] as? String, status == "completed" {
                    contract.status = "signed"
                }
                // Pull client signature from server
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
}
