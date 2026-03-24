import SwiftUI
import StoreKit

struct ProGateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sub = SubscriptionManager.shared
    @State private var showError = false

    private let features: [(icon: String, text: String)] = [
        ("doc.on.doc.fill", "無制限の契約書作成"),
        ("wand.and.stars", "AIテンプレート自動生成"),
        ("person.wave.2.fill", "ウェブ署名（相手への送付）"),
        ("signature", "電子署名・印鑑機能"),
        ("chart.bar.fill", "契約レポート・分析"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ponBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        featuresSection.padding(.top, 28)
                        purchaseSection.padding(.top, 28)
                        footerSection.padding(.top, 16).padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.foregroundStyle(.secondary)
                }
            }
            .alert("エラー", isPresented: $showError, presenting: sub.purchaseError) { _ in
                Button("OK") { sub.purchaseError = nil }
            } message: { msg in Text(msg) }
            .onChange(of: sub.purchaseError) { _, new in showError = new != nil }
            .onChange(of: sub.isPro) { _, isPro in if isPro { dismiss() } }
        }
    }

    private var headerSection: some View {
        ZStack {
            LinearGradient(
                colors: [.pon, .ponAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 220)

            VStack(spacing: 10) {
                Image(systemName: "signature")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white)
                Text("ポン Pro")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                Text("契約管理を、もっと簡単に。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Proプランの機能")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(features, id: \.text) { feature in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.pon.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: feature.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.pon)
                        }
                        Text(feature.text).font(.subheadline)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.ponSigned)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    if feature.text != features.last?.text {
                        Divider().overlay(Color.white.opacity(0.06)).padding(.leading, 70)
                    }
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
            .padding(.horizontal, 16)
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(sub.formattedPrice)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                Text("月額・いつでもキャンセル可能")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Button {
                Task { await sub.purchasePro() }
            } label: {
                HStack(spacing: 8) {
                    if sub.isPurchasing {
                        ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "crown.fill")
                    }
                    Text(sub.isPurchasing ? "処理中..." : "Proにアップグレード")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [.pon, .ponAccent],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .disabled(sub.isPurchasing || sub.proProduct == nil)
            .padding(.horizontal, 16)

            Button {
                Task { await sub.restorePurchases() }
            } label: {
                Text("購入を復元する").font(.subheadline).foregroundStyle(Color.pon)
            }
            .disabled(sub.isPurchasing)
        }
    }

    private var footerSection: some View {
        HStack(spacing: 16) {
            Link("利用規約", destination: URL(string: "https://pon.app/terms")!)
            Text("·").foregroundStyle(.tertiary)
            Link("プライバシーポリシー", destination: URL(string: "https://pon.app/privacy")!)
        }
        .font(.caption).foregroundStyle(.secondary)
    }
}

// MARK: - Pro Banner

struct ProBanner: View {
    let message: String
    @Binding var showProGate: Bool

    var body: some View {
        Button { showProGate = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill").foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Proプランが必要です").font(.subheadline.weight(.semibold))
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("アップグレード")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.pon, in: Capsule())
            }
            .padding(14).glassCard()
        }
        .buttonStyle(.plain)
    }
}
