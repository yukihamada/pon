import SwiftUI
import UIKit

struct ContractShareSheet: View {
    let contract: Contract
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var signURL: String { contract.signURL }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Success icon
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.ponSigned)

                Text("契約書を作成しました")
                    .font(.system(size: 22, weight: .bold))

                Text("署名済みの契約書がサーバーにアップロードされました。\n下のリンクを相手に送って署名してもらいましょう。")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // URL display
                VStack(spacing: 8) {
                    Text(signURL)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.ponAccent)
                        .lineLimit(2)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.ponAccent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        UIPasteboard.general.string = signURL
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            Text(copied ? "コピーしました" : "リンクをコピー")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(copied ? Color.ponSigned : Color.pon)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background((copied ? Color.ponSigned : Color.pon).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)

                // Share button
                ShareLink(item: URL(string: signURL)!) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("相手に送る")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [Color.pon, Color.ponAccent],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
            }
            .background(Color.ponBg)
            .navigationTitle("署名完了")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
