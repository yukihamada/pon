import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Contract.createdAt, order: .reverse) private var all: [Contract]
    @State private var showDeleteAlert = false
    @State private var showProGate = false
    @StateObject private var sub = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Subscription
                Section {
                    if sub.isPro {
                        HStack {
                            Label("Proプラン", systemImage: "crown.fill").foregroundStyle(Color.pon)
                            Spacer()
                            Text("有効").foregroundStyle(Color.ponSigned).font(.subheadline.weight(.semibold))
                        }
                        if let exp = sub.expirationDate {
                            HStack {
                                Label("次回更新", systemImage: "arrow.clockwise").foregroundStyle(.secondary)
                                Spacer()
                                Text(exp, style: .date).foregroundStyle(.secondary)
                            }
                        }
                        Button { Task { await sub.restorePurchases() } } label: {
                            Label("購入を復元する", systemImage: "arrow.counterclockwise").foregroundStyle(Color.pon)
                        }
                    } else {
                        Button { showProGate = true } label: {
                            HStack {
                                Image(systemName: "crown.fill").foregroundStyle(.yellow)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Proにアップグレード").font(.subheadline.weight(.semibold))
                                    Text("無制限契約書・AIテンプレート・ウェブ署名").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(sub.formattedPrice).font(.subheadline.weight(.bold)).foregroundStyle(Color.pon)
                            }
                        }
                        Button { Task { await sub.restorePurchases() } } label: {
                            Label("購入を復元する", systemImage: "arrow.counterclockwise").foregroundStyle(Color.pon)
                        }
                    }
                } header: { Text("サブスクリプション") }

                Section {
                    HStack {
                        Label("総契約数", systemImage: "doc.on.doc.fill").foregroundStyle(Color.pon)
                        Spacer()
                        Text("\(all.count)件").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("有効契約", systemImage: "bolt.fill").foregroundStyle(Color.ponSigned)
                        Spacer()
                        Text("\(all.filter { $0.status == "active" || $0.status == "signed" }.count)件").foregroundStyle(.secondary)
                    }
                } header: { Text("統計") }

                Section {
                    sisterRow("パシャ", sub: "レシート撮影・経費管理", icon: "camera.fill", hex: "F72585", url: "https://pasha.run")
                    sisterRow("チャリン", sub: "収入記録・請求書作成", icon: "yensign.circle.fill", hex: "F77F00", url: "https://pasha.run/charin")
                    sisterRow("ポイッ", sub: "不用品の出品・査定サポート", icon: "shippingbox.fill", hex: "06D6A0", url: "https://pasha.run/poi")
                    sisterRow("サクッ", sub: "確定申告・青色申告対応", icon: "checkmark.seal.fill", hex: "3B82F6", url: "https://pasha.run/sakutsu")
                } header: { Text("姉妹アプリ") }

                Section {
                    HStack { Text("バージョン"); Spacer(); Text("1.0.0").foregroundStyle(.secondary) }
                } header: { Text("ポンについて") }
                footer: {
                    Text("ポン — 決まった、ポン。契約はポン、収入はチャリン、支出はパシャ。")
                }

                Section {
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("全データ削除", systemImage: "trash.fill")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ponBg)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .alert("全データを削除しますか？", isPresented: $showDeleteAlert) {
                Button("削除する", role: .destructive) { for c in all { context.delete(c) } }
                Button("キャンセル", role: .cancel) {}
            } message: { Text("この操作は取り消せません。") }
            .sheet(isPresented: $showProGate) {
                ProGateView().presentationDetents([.large])
            }
        }
    }

    @ViewBuilder
    private func sisterRow(_ name: String, sub: String, icon: String, hex: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Color(hex: hex)).font(.title3).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(sub).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
