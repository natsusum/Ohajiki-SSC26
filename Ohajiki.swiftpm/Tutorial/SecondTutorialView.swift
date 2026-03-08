//
//  SecondTutorialView.swift
//  Ohajiki
//
//  Created by 夏川宙樹 on 2025/12/10.
//

import SwiftUI
import Combine

struct SecondTutorialView: View {
    var showBackButton: Bool = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = SecondTutorialOhajikiManager()
    @StateObject private var scoreManager = ScoreManager()
    @State private var shouldNavigate = false
    @State private var animationOffset: CGFloat = 0
    @State private var animationOpacity: Double = 1.0
    @State private var isAnimating = false
    @State private var showCheckmark = false
    @State private var showCombo = false
    @State private var comboCount: Int = 0
    @State private var showScoreChange = false
    @State private var scoreChangeText: String = ""
    @State private var scoreChangeColor: Color = .white
    @State private var scoreChangeOffsetY: CGFloat = 0
    
    private var comboLabel: String {
        switch comboCount {
        case 1: return "Good!"
        case 2: return "Great!"
        case 3: return "Excellent!"
        default: return "Amazing!"
        }
    }
    
    private var comboColor: Color {
        switch comboCount {
        case 1: return .green
        case 2: return .cyan
        case 3: return .yellow
        default: return .orange
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. 背景層 (iwahaikei)
                GeometryReader { _ in
                    Image("iwahaikei")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }
                .ignoresSafeArea()
                
                if manager.boundaryRadius > 0 {
                    let centerX = geometry.size.width / 2
                    let centerY = geometry.size.height / 2
                    let wallRadius = manager.boundaryRadius
                    
                    // 2. 水面エリア
                    ZStack {
                        Image("iwahaikei")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .brightness(0.15)
                            .saturation(1.3)
                            .overlay(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.15), Color.cyan.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.1), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .frame(width: wallRadius * 2, height: wallRadius * 2)
                    .clipShape(Circle())
                    .position(x: centerX, y: centerY)
                    
                    // 3. 境界の影
                    Group {
                        Circle()
                            .stroke(Color.black.opacity(0.6), lineWidth: 20)
                            .frame(width: wallRadius * 2 + 20, height: wallRadius * 2 + 20)
                            .blur(radius: 4)
                        Circle()
                            .stroke(Color.black.opacity(0.3), lineWidth: 40)
                            .frame(width: wallRadius * 2 + 50, height: wallRadius * 2 + 50)
                            .blur(radius: 20)
                    }
                    .position(x: centerX, y: centerY)
                    .mask(
                        Rectangle()
                            .fill(Color.black)
                            .ignoresSafeArea()
                            .overlay(
                                Circle()
                                    .frame(width: wallRadius * 2, height: wallRadius * 2)
                                    .position(x: centerX, y: centerY)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )
                }
                
                // 各円を描画
                ForEach(manager.circles) { circle in
                    
                    // ドラッグ時のガイド線（光の反射風）
                    if circle.isDragging && (circle.dragOffset.width != 0 || circle.dragOffset.height != 0) {
                        let centerX = geometry.size.width / 2
                        let centerY = geometry.size.height / 2
                        let wallRadius = manager.boundaryRadius
                        let startX = centerX + circle.offset.width
                        let startY = centerY + circle.offset.height
                        let startPoint = CGPoint(x: startX, y: startY)
                        let dx = -circle.dragOffset.width
                        let dy = -circle.dragOffset.height
                        let distance = sqrt(dx*dx + dy*dy)
                        let targetPoint = CGPoint(x: startX + (dx / max(distance, 0.001)) * (wallRadius * 2),
                                                 y: startY + (dy / max(distance, 0.001)) * (wallRadius * 2))
                        let lineWidthWide: CGFloat = 50
                        let lineWidthCore: CGFloat = 1.5
                        
                        let rayGradient = LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0), location: 0),
                                .init(color: .white.opacity(1), location: 0.1),
                                .init(color: .white.opacity(1), location: 0.8),
                                .init(color: .white.opacity(0), location: 1)
                            ],
                            startPoint: UnitPoint(x: startPoint.x / geometry.size.width, y: startPoint.y / geometry.size.height),
                            endPoint: UnitPoint(x: targetPoint.x / geometry.size.width, y: targetPoint.y / geometry.size.height)
                        )
                        
                        ZStack {
                            Path { p in p.move(to: startPoint); p.addLine(to: targetPoint) }
                                .stroke(rayGradient, style: StrokeStyle(lineWidth: lineWidthWide, lineCap: .round))
                                .opacity(0.12).blur(radius: 15)
                            Path { p in p.move(to: startPoint); p.addLine(to: targetPoint) }
                                .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidthCore, lineCap: .round))
                                .opacity(0.8).blur(radius: 0.3)
                        }
                        .mask(Circle().frame(width: wallRadius * 2, height: wallRadius * 2).position(x: centerX, y: centerY))
                    }
                    
                    // おはじき本体（OhajikiDeskViewと同じ見た目）
                    OhajikiView(ohajiki: circle)
                        .offset(x: circle.offset.width, y: circle.offset.height)
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 12)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .gesture(
                            circle.isHandBall ?
                            DragGesture()
                                .onChanged { value in
                                    manager.startOrUpdateDragging(for: circle.id, translation: value.translation)
                                }
                                .onEnded { value in
                                    manager.endDragging(for: circle.id, translation: value.translation)
                                }
                            : nil
                        )
                }
                
                // 手玉を右方向にドラッグするアニメーション
                if let handBall = manager.circles.first(where: { $0.isHandBall }), 
                   !manager.hasDetectedMerge,
                   !handBall.isDragging,
                   !isHandBallMoving(handBall) {
                    Image(systemName: "hand.point.up.left")
                        .font(.system(size: 120))
                        .foregroundColor(.white.opacity(animationOpacity * 0.85))
                        
                        .position(
                            x: geometry.size.width / 2 + handBall.offset.width + animationOffset + 30,
                            y: geometry.size.height / 2 + handBall.offset.height + 60
                        )
                }
                
                // スコア表示（中央上部）
                VStack {
                    VStack {
                        AnimatedScoreText(targetScore: scoreManager.score)
                    }
                    .padding(.top, 20)
                    .offset(y: -20)
                    Spacer()
                }
                
                // コンボ表示
                if showCombo {
                    VStack(spacing: 6) {
                        Text(comboLabel)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(comboColor)
                            .stroke(color: .white, width: 1.2)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                        
                        Text("\(comboCount) combo")
                            .font(.system(size: 38, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 270)
                }
                
                // スコア加算表示（上に浮かぶ）
                if showScoreChange && comboCount >= 1 {
                    Text(scoreChangeText)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreChangeColor)
                        .shadow(color: scoreChangeColor.opacity(0.5), radius: 10, x: 0, y: 0)
                        .transition(.opacity)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 270 + scoreChangeOffsetY)
                }
                
                // 画面下中央に説明テキストを表示
                VStack {
                    Spacer()
                    Text("When Ohajiki of the same color collide, they merge and grow larger\nMake the pink ohajiki hit each other to merge them.")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                    
                    // 進行状況インジケーター
                    HStack(spacing: 10) {
                        ForEach(0..<4) { index in
                            Circle()
                                .fill(index == 1 ? Color.white : Color.white.opacity(0.35))
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                
                // チェックマーク（条件達成時）
                if showCheckmark {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 140, height: 140)
                        Circle()
                            .strokeBorder(Color.green, lineWidth: 6)
                            .frame(width: 140, height: 140)
                        Image(systemName: "checkmark")
                            .font(.system(size: 70, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .shadow(color: .green.opacity(0.5), radius: 20)
                    .transition(.scale.combined(with: .opacity))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                
                // 戻るボタン（本編の？から来た場合のみ表示）
                if showBackButton {
                    VStack {
                        HStack {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("戻る")
                                }
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                            }
                            .padding()
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .onAppear {
                manager.setScreenSize(geometry.size)
                manager.startTimer()
                startDragAnimation()
            }
            .onChange(of: geometry.size) { newSize in
                manager.setScreenSize(newSize)
            }
            .onChange(of: manager.circles.first(where: { $0.isHandBall })?.isDragging ?? false) { isDragging in
                if isDragging {
                    isAnimating = false
                    animationOpacity = 0
                } else {
                    checkAndRestartAnimation()
                }
            }
            .onChange(of: manager.circles.first(where: { $0.isHandBall })?.velocity ?? .zero) { velocity in
                let speed = sqrt(velocity.width * velocity.width + velocity.height * velocity.height)
                let minVelocity: CGFloat = 0.2
                
                if speed >= minVelocity {
                    isAnimating = false
                    animationOpacity = 0
                } else {
                    checkAndRestartAnimation()
                }
            }
            .onChange(of: manager.hasDetectedMerge) { detected in
                if detected {
                    isAnimating = false
                    animationOpacity = 0
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        showCheckmark = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            shouldNavigate = true
                        }
                    }
                }
            }
            .onChange(of: manager.hasFlicked) { flicked in
                if !flicked {
                    // リセットされたのでアニメーションを再開
                    showCheckmark = false
                    scoreManager.resetScore()
                    startDragAnimation()
                }
            }
            .onChange(of: manager.comboDisplayCount) { count in
                if count >= 1 {
                    comboCount = count
                    scoreManager.addComboScore(comboCount: count)
                    let points = count * (count + 1) * 50
                    scoreChangeText = "+\(points)"
                    scoreChangeColor = comboColor
                    scoreChangeOffsetY = 0
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        showCombo = true
                        showScoreChange = true
                    }
                    withAnimation(.easeOut(duration: 1.0)) {
                        scoreChangeOffsetY = -170
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showCombo = false
                            showScoreChange = false
                        }
                    }
                } else if count == 0 {
                    scoreChangeText = "-50"
                    scoreChangeColor = .red
                    scoreManager.applyMissPenalty()
                    scoreChangeOffsetY = 0
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        showScoreChange = true
                    }
                    withAnimation(.easeOut(duration: 1.0)) {
                        scoreChangeOffsetY = -170
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showScoreChange = false
                        }
                    }
                }
            }
            .onDisappear {
                manager.stopTimer()
                isAnimating = false
            }
        }
        .overlay(
            Group {
                if shouldNavigate {
                    ThirdTutorialView(showBackButton: showBackButton)
                        .transition(.opacity)
                }
            }
        )
    }
    
    private func startDragAnimation() {
        isAnimating = true
        animateDragLoop()
    }
    
    private func isHandBallMoving(_ handBall: Ohajiki) -> Bool {
        let speed = sqrt(handBall.velocity.width * handBall.velocity.width + handBall.velocity.height * handBall.velocity.height)
        let minVelocity: CGFloat = 0.2
        return speed >= minVelocity
    }
    
    private func checkAndRestartAnimation() {
        // 手玉が止まっていて、合体が検出されていない場合のみアニメーションを再開
        if let handBall = manager.circles.first(where: { $0.isHandBall }),
           !manager.hasDetectedMerge,
           !handBall.isDragging,
           !isHandBallMoving(handBall),
           !isAnimating {
            startDragAnimation()
        }
    }
    
    private func animateDragLoop() {
        // アニメーションが停止されているか、合体が検出されたら停止
        guard isAnimating && !manager.hasDetectedMerge else {
            return
        }
        
        // 手玉の位置から開始（完全に重ねる）
        animationOffset = 0
        animationOpacity = 1.0
        
        // 右に移動（opacityは1.0のまま）
        withAnimation(.easeOut(duration: 1.5)) {
            animationOffset = 160 // 右方向に移動（2倍の距離）
        }
        
        // 移動完了後、フェードアウト
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard self.isAnimating && !self.manager.hasDetectedMerge else {
                return
            }
            
            withAnimation(.easeOut(duration: 0.5)) {
                self.animationOpacity = 0.0 // 徐々に消える
            }
            
            // フェードアウト完了後、再び手玉の位置から開始（ループ）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.animateDragLoop()
            }
        }
    }
}

/// 第二チュートリアル用のおはじきマネージャー（手玉1つと赤玉2つ）
class SecondTutorialOhajikiManager: OhajikiManager {
    @Published var hasDetectedMerge = false
    @Published var hasFlicked = false
    
    override init() {
        super.init()
        handBallFriction = 0.93
        defaultFriction = 0.92
        currentFriction = 0.92
    }
    
    override func setupInitialCircles() {
        // 手玉1つと赤玉2つを設定
        circles = [
            Ohajiki(color: .white),  // 手玉
            Ohajiki(color: .ohajikiRed),    // 赤い円1
            Ohajiki(color: .ohajikiRed)     // 赤い円2
        ]
        
        // ★ 修正6: 手玉フラグを設定
        if !circles.isEmpty {
            circles[0].isHandBall = true
            // 手玉の面積を2倍にするため、半径を√2倍にする
            circles[0].radius = circleRadius * sqrt(2.0)
        }
    }
    
    override func updatePhysics() {
        // 合体前の手玉以外の玉の数を記録
        let nonHandBallCountBefore = circles.filter { !$0.isHandBall }.count
        
        super.updatePhysics()
        
        // 合体後の手玉以外の玉の数を確認
        let nonHandBallCountAfter = circles.filter { !$0.isHandBall }.count
        
        // 手玉以外の玉が2つから1つに減ったら合体を検出
        if nonHandBallCountBefore == 2 && nonHandBallCountAfter == 1 && !hasDetectedMerge {
            hasDetectedMerge = true
            return
        }
        
        // 手玉を弾いた後、全ての玉が停止しても条件未達成 → リセット
        if hasFlicked && !hasDetectedMerge {
            let allStopped = circles.allSatisfy { circle in
                if circle.isDragging || circle.isExpiring { return true }
                return circle.velocity == .zero
            }
            if allStopped {
                resetTutorial()
            }
        }
    }
    
    func resetTutorial() {
        hasFlicked = false
        hasDetectedMerge = false
        collisionDetected = false
        setupInitialCircles()
        initializePositions()
    }
    
    override func endDragging(for id: UUID, translation: CGSize) {
        super.endDragging(for: id, translation: translation)
        let dragDistance = sqrt(translation.width * translation.width + translation.height * translation.height)
        if dragDistance > 0 {
            hasFlicked = true
        }
    }
    
    // 色を比較するヘルパーメソッド
    private func areColorsEqual(_ color1: Color, _ color2: Color) -> Bool {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
    }
    
    override func initializePositions() {
        // 親クラスの実装は呼ばない（手玉1つと赤玉2つだけの配置）
        // 手玉と赤玉2つを一直線上に配置（手玉を右端に）
        
        // 青い円（手玉）を右端に配置
        if circles.count > 0 {
            circles[0].offset = CGSize(width: boundaryRadius * 0.3, height: 0)
        }
        
        // 赤い円1を中央に配置
        if circles.count > 1 {
            circles[1].offset = CGSize(width: 0, height: 0)
        }
        
        // 赤い円2を左端に配置
        if circles.count > 2 {
            circles[2].offset = CGSize(width: -boundaryRadius * 0.3, height: 0)
        }
    }
}

#Preview {
    SecondTutorialView()
}
