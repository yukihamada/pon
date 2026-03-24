import SwiftUI

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ContractTemplate?) -> Void
    let onAIGenerate: () -> Void

    @AppStorage("aiGenerationCount") private var aiGenerationCount = 0
    @State private var selectedCategory: ContractCategory?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let cat = selectedCategory {
                        // Sub-template list
                        Button {
                            withAnimation { selectedCategory = nil }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                                Text("カテゴリに戻る").font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(Color.pon)
                            .padding(.horizontal)
                        }

                        HStack(spacing: 10) {
                            Image(systemName: cat.icon)
                                .foregroundStyle(Color.categoryColor(for: cat.id))
                            Text(cat.name)
                                .font(.system(size: 17, weight: .bold))
                        }
                        .padding(.horizontal)

                        ForEach(cat.templates) { template in
                            Button {
                                onSelect(template)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Text(template.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(14)
                                .background(.white.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.06)))
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Category grid
                        Text("テンプレートを選択して契約書を素早く作成できます。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: 12) {
                            aiCard

                            ForEach(ContractCategory.all) { cat in
                                categoryGridCard(cat)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.ponBg)
            .navigationTitle("テンプレート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aiCard: some View {
        Button {
            onAIGenerate()
            dismiss()
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pon, Color.ponAccent],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ).opacity(0.2)
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.pon, Color.ponAccent],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
                Text("AIで作成")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                if aiGenerationCount == 0 {
                    Text("初回無料")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.ponSigned)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.ponSigned.opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Text("Pro")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.ponWarn)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.ponWarn.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .glassCard()
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.pon.opacity(0.4), Color.ponAccent.opacity(0.4)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 1
                    )
            )
        }
    }

    private func categoryGridCard(_ cat: ContractCategory) -> some View {
        let c = Color.categoryColor(for: cat.id)
        return Button {
            withAnimation { selectedCategory = cat }
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(c.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: cat.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(c)
                }
                Text(cat.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                Text("\(cat.templates.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .glassCard()
        }
    }
}
