import SwiftUI

struct SignatureView: View {
    @Binding var signatureImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var paths: [[CGPoint]] = []
    @State private var currentPath: [CGPoint] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("指またはApple Pencilで署名してください")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                // Canvas
                GeometryReader { geo in
                    ZStack {
                        // White background
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)

                        // Signature line
                        Path { path in
                            let y = geo.size.height * 0.75
                            path.move(to: CGPoint(x: 20, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width - 20, y: y))
                        }
                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                        // Drawn paths
                        Canvas { context, _ in
                            for stroke in paths {
                                drawSmooth(stroke, in: &context)
                            }
                            if !currentPath.isEmpty {
                                drawSmooth(currentPath, in: &context)
                            }
                        }

                        // Touch capture
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        currentPath.append(value.location)
                                    }
                                    .onEnded { _ in
                                        if !currentPath.isEmpty {
                                            paths.append(currentPath)
                                            currentPath = []
                                        }
                                    }
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding()
                .frame(height: 260)

                HStack(spacing: 16) {
                    Button {
                        paths = []
                        currentPath = []
                    } label: {
                        Label("クリア", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.ponDanger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ponDanger.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        captureSignature()
                    } label: {
                        Label("完了", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [Color.pon, Color.ponAccent],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(paths.isEmpty)
                    .opacity(paths.isEmpty ? 0.5 : 1)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .background(Color.ponBg)
            .navigationTitle("署名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func drawSmooth(_ points: [CGPoint], in context: inout GraphicsContext) {
        guard points.count > 1 else { return }
        var path = Path()
        path.move(to: points[0])

        if points.count == 2 {
            path.addLine(to: points[1])
        } else {
            for i in 1..<points.count {
                let mid = CGPoint(
                    x: (points[i - 1].x + points[i].x) / 2,
                    y: (points[i - 1].y + points[i].y) / 2
                )
                if i == 1 {
                    path.addLine(to: mid)
                } else {
                    path.addQuadCurve(to: mid, control: points[i - 1])
                }
            }
            path.addLine(to: points.last!)
        }

        context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    @MainActor
    private func captureSignature() {
        let size = CGSize(width: 600, height: 300)
        let renderer = ImageRenderer(content: signatureCanvas(size: size))
        renderer.scale = 2
        if let image = renderer.uiImage {
            signatureImage = image
        }
        dismiss()
    }

    private func signatureCanvas(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            // Scale paths to output size
            let currentWidth: CGFloat = UIScreen.main.bounds.width - 32 // approximate canvas width
            let currentHeight: CGFloat = 228 // approximate canvas height (260 - padding)
            let scaleX = canvasSize.width / max(currentWidth, 1)
            let scaleY = canvasSize.height / max(currentHeight, 1)

            for stroke in paths {
                let scaled = stroke.map { CGPoint(x: $0.x * scaleX, y: $0.y * scaleY) }
                drawSmooth(scaled, in: &context)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(.white)
    }
}
