import SwiftUI

struct OhajikiView: View {
    var ohajiki: Ohajiki
    var showOuterGlow: Bool = true
    
    @State private var ringRotation: Double = 0
    @State private var visualScale: CGFloat = 1.0
    @State private var visualOpacity: Double = 1.0
    @State private var visualBrightness: Double = 0.0
    
    private var handBallRingAngle: Angle {
        Angle(degrees: ringRotation)
    }

    var body: some View {
        ZStack {
            // --- A. 外側グロー（背景に馴染ませる） ---
            if showOuterGlow {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ohajiki.color.opacity(ohajiki.isHandBall ? 0.35 : 0.4),
                                ohajiki.color.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: ohajiki.radius * 0.4,
                            endRadius: ohajiki.radius * 1.4
                        )
                    )
                    .blur(radius: 6)
                    .allowsHitTesting(false)
            }
            
            Group {
                // --- B. 屈折レイヤー（背景を歪ませる透明なレンズ） ---
                Circle()
                    .fill(.clear)
                    .layerEffect(
                            ShaderLibrary.ohajikiRefraction(
                                .float2(ohajiki.radius * 2, ohajiki.radius * 2),
                                .float(ohajiki.radius),
                                .float(1.2),
                                .color(ohajiki.color),
                                .float(ohajiki.isHandBall ? 1.0 : 0.0)
                            ),
                            maxSampleOffset: CGSize(width: 20, height: 20)
                        )
                
                // --- C. ベースカラー（発色担当） ---
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: ohajiki.color.opacity(ohajiki.isHandBall ? 0.12 : 0.18), location: 0.0),
                                .init(color: ohajiki.color.opacity(ohajiki.isHandBall ? 0.3 : 0.35), location: 1.0)
                            ],
                            center: .center, startRadius: 0, endRadius: ohajiki.radius
                        )
                    )
                    .blendMode(.screen)
                
                // --- D. 虹色の縁 (手玉専用) ---
                if ohajiki.isHandBall {
                    ZStack {
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [.blue, .purple, .cyan, .green, .yellow, .orange, .red, .blue],
                                    center: .center
                                ),
                                lineWidth: 3.0
                            )
                            .blur(radius: 2)
                        
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [.blue, .purple, .cyan, .green, .yellow, .orange, .red, .blue],
                                    center: .center
                                ),
                                lineWidth: 1.0
                            )
                    }
                    .opacity(0.7)
                    .blendMode(.plusLighter)
                    .rotationEffect(handBallRingAngle)
                }
                
                // --- E. ハイライト（表面のツヤ） ---
                highlightLayer
                
                // --- F. 内側の発光（おはじき全体が光っている感） ---
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ohajiki.color.opacity(0.3),
                                ohajiki.color.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: ohajiki.radius * 0.9
                        )
                    )
                    .blendMode(.plusLighter)
            }
            .brightness(0.8 + visualBrightness)
        }
        .frame(width: ohajiki.radius * 2, height: ohajiki.radius * 2)
        .scaleEffect(visualScale)
        .opacity(visualOpacity)
        .onAppear {
            setupAnimations()
        }
        .onChange(of: ohajiki.isExpiring) { _, newValue in
            if newValue { startExpiringAnimation() }
        }
    }

    private func setupAnimations() {
        if ohajiki.isHandBall {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
        if ohajiki.isExpiring {
            startExpiringAnimation()
        }
    }

    // ハイライト層（以前のコードを維持しつつ透明感を微調整）
    private var highlightLayer: some View {
        GeometryReader { proxy in
            let r = min(proxy.size.width, proxy.size.height) / 2
            ZStack {
                // 左上の鋭い光
                Circle()
                    .fill(LinearGradient(colors: [.white.opacity(0.9), .clear], startPoint: .topLeading, endPoint: .center))
                    .mask(crescentMask(r: r, offset: 0.05, direction: .topLeading))
                    .blur(radius: 0.5)
                    .blendMode(.plusLighter)

                // 左上ハイライトの反射光（右下・細め）
                Circle()
                    .fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .bottomTrailing, endPoint: .center))
                    .mask(crescentMask(r: r, offset: 0.025, direction: .bottomTrailing))
                    .blur(radius: 0.2)
                    .blendMode(.plusLighter)

                // 右下の柔らかな照り返し
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.4), .clear], center: .bottomTrailing, startRadius: 0, endRadius: r * 0.8))
                    .mask(crescentMask(r: r, offset: 0.12, direction: .bottomTrailing))
                    .blur(radius: 3)
            }
        }
    }

    private enum MaskDirection { case topLeading, bottomTrailing }
    private func crescentMask(r: CGFloat, offset: CGFloat, direction: MaskDirection) -> some View {
        let off = r * offset
        return ZStack {
            Circle()
            Circle()
                .offset(x: direction == .topLeading ? off : -off, y: direction == .topLeading ? off : -off)
                .blendMode(.destinationOut)
        }.compositingGroup()
    }
    
    private func startExpiringAnimation() {
        let duration = ohajiki.expiryDuration
        withAnimation(.easeOut(duration: duration)) {
            visualScale = 1.3
            visualOpacity = 0.0
            visualBrightness = 0.2
        }
    }
}
