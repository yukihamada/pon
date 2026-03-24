import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let pon = Color(hex: "7B2FBE")
    static let ponAccent = Color(hex: "4CC9F0")
    static let ponSigned = Color(hex: "06D6A0")
    static let ponWarn = Color(hex: "FFD60A")
    static let ponDanger = Color(hex: "EF233C")
    static let ponCard = Color(hex: "16213E")
    static let ponBg = Color(hex: "0F0F1A")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }

    static func statusColor(for status: String) -> Color {
        switch status {
        case "draft": return .secondary
        case "sent": return .ponAccent
        case "signed": return .ponSigned
        case "active": return .pon
        case "expired": return .ponWarn
        case "cancelled": return .ponDanger
        default: return .secondary
        }
    }

    static func typeColor(for type: String) -> Color {
        // Find which category the type belongs to
        let categoryId = ContractCategory.all.first { cat in cat.templates.contains { $0.id == type } }?.id ?? type
        return categoryColor(for: categoryId)
    }

    static func categoryColor(for categoryId: String) -> Color {
        switch categoryId {
        case "outsourcing": return .pon
        case "nda": return .ponWarn
        case "sales": return Color(hex: "F77F00")
        case "rental": return .ponAccent
        case "employment": return Color(hex: "F72585")
        case "ip": return Color(hex: "8338EC")
        case "service": return .ponSigned
        default: return .secondary
        }
    }
}

// MARK: - Glass Card

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
    }
}
extension View { func glassCard() -> some View { modifier(GlassCard()) } }

// MARK: - Tabs

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showNewContract = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(showNewContract: $showNewContract)
                    .tag(0)
                    .tabItem { Label("ホーム", systemImage: "house.fill") }
                ContractListView()
                    .tag(1)
                    .tabItem { Label("一覧", systemImage: "doc.on.doc.fill") }
                ReportView()
                    .tag(2)
                    .tabItem { Label("レポート", systemImage: "chart.bar.fill") }
                SettingsView()
                    .tag(3)
                    .tabItem { Label("設定", systemImage: "gearshape.fill") }
            }
            .tint(Color.pon)

            // FAB - signature/stamp
            Button { showNewContract = true } label: {
                ZStack {
                    Circle().fill(.ultraThinMaterial).frame(width: 68, height: 68)
                    Circle()
                        .fill(LinearGradient(colors: [Color.pon, Color.ponAccent],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)
                    Image(systemName: "signature")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.pon.opacity(0.35), radius: 16, y: 6)
            }
            .offset(y: -4)
        }
        .sheet(isPresented: $showNewContract) {
            NewContractView()
                .interactiveDismissDisabled()
        }
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark).modelContainer(for: Contract.self, inMemory: true)
}
