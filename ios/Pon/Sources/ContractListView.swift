import SwiftUI
import SwiftData

struct ContractListView: View {
    @Query(sort: \Contract.createdAt, order: .reverse) private var all: [Contract]
    @State private var search = ""

    private var filtered: [Contract] {
        if search.isEmpty { return all }
        let q = search.lowercased()
        return all.filter { $0.title.lowercased().contains(q) || $0.clientName.lowercased().contains(q) || $0.contractNumber.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("検索...", text: $search).font(.system(size: 14))
                    }
                    .padding(12).background(Color.ponCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08)))

                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 36)).foregroundStyle(.quaternary)
                            Text("該当なし").font(.system(size: 14)).foregroundStyle(.tertiary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 60)
                    } else {
                        ForEach(filtered, id: \.id) { c in
                            NavigationLink { ContractDetailView(contract: c) } label: { ContractRow(contract: c) }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal).padding(.bottom, 100)
            }
            .background(Color.ponBg)
            .navigationTitle("契約一覧")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
