import SwiftUI
import SceneKit

// MARK: - 透明背景のSceneView
struct TransparentSceneView: UIViewRepresentable {
    let scene: SCNScene
    
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

// MARK: - クリア画面オーバーレイ

struct ClearOverlayView: View {
    let score: Int
    let bestScore: Int
    let maxComboCount: Int
    var isTwoPlayerMode: Bool = false
    var player1Score: Int = 0
    var player2Score: Int = 0
    let onRetry: () -> Void
    var onHome: (() -> Void)? = nil
    
    @State private var scene = ConfettiScene()
    
//    private var winnerText: String {
//        if player1Score > player2Score {
//            return "Player 1 の勝ち！"
//        } else if player2Score > player1Score {
//            return "Player 2 の勝ち！"
//        } else {
//            return "引き分け！"
//        }
//    }
    
    private var winnerColor: Color {
        if player1Score > player2Score {
            return .red
        } else if player2Score > player1Score {
            return .blue
        } else {
            return .purple
        }
    }
    
    var body: some View {
        ZStack {
            
            TransparentSceneView(scene: scene)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            // 中央にカード型ビュー
            VStack(spacing: 10) {
                Text("Clear!")
                    .font(.system(size: 92, weight: .medium, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .stroke(color: .white, width: 2)
                    .shadow(color: .white.opacity(0.8), radius: 8)
                    .padding(.bottom, -16)
                    .zIndex(1)
                
                VStack(spacing: 20) {
                if isTwoPlayerMode {
                    // 二人モード: 勝敗表示
//                    Text(winnerText)
//                        .font(.system(size: 28, weight: .bold))
//                        .foregroundColor(winnerColor)
                    
                    HStack(spacing: 24) {
                        // Player 1
                        VStack(spacing: 6) {
                            Text("Player 1")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.red)
                            Text("\(player1Score)")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(minWidth: 100)
                        
//                        Text("vs")
//                            .font(.system(size: 20, weight: .medium))
//                            .foregroundColor(.gray)
                        
                        // Player 2
                        VStack(spacing: 6) {
                            Text("Player 2")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.blue)
                            Text("\(player2Score)")
                                .font(.system(size: 46, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(minWidth: 100)
                    }
                    
                    if maxComboCount >= 2 {
                        Text("Max Combo")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                        Text("\(maxComboCount)")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                } else {
                    // 一人モード: 通常スコア表示
                    VStack(spacing: 34) {
                        VStack(spacing: 4) {
                            Text("Score")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                            Text("\(score)")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(.cyan)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Max Combo")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                            Text("\(maxComboCount)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Best Score")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                            Text("\(bestScore)")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.system(size: 33, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(height: 50)
                        .frame(width: 188)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                
                if onHome != nil {
                    Button(action: { onHome?() }) {
                        Text("Back to Home")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
                .frame(width: 400)
                .background(Color.black.opacity(0.7))
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 8)

            }

        }
        .onAppear {
            scene.showConfetti()
        }
    }
}

#Preview {
    ClearOverlayView(score: 1500, bestScore: 2000, maxComboCount: 3, onRetry: {}, onHome: {})
}
