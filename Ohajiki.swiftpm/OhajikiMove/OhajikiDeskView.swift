import SwiftUI
import UIKit

struct OhajikiDeskView: View {
    var onBack: (() -> Void)? = nil
    @StateObject private var viewModel = OhajikiDeskViewModel()
    @State private var showTutorial = false
    @State private var showClearView = false
    @State private var hasDetectedClear = false
    @State private var showCenterMessage = true
    @State private var centerMessageOpacity: Double = 1.0
    @State private var showPauseMenu = false
    @State private var showCombo = false
    @State private var comboCount: Int = 0
    @State private var showScoreChange = false
    @State private var scoreChangeText: String = ""
    @State private var scoreChangeColor: Color = .white
    @State private var scoreChangeOffsetY: CGFloat = 0
    @State private var showModeInfo = true
    @State private var isTwoPlayerMode = false
    @State private var isPlayer1Turn = true
    @State private var player1Score: Int = 0
    @State private var player2Score: Int = 0
    @State private var dragHapticGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var lastDragHapticTime: Date = .distantPast
    
    private var comboLabel: String {
        switch comboCount {
        case 1: return "Good!"
        case 2: return "Great!"
        case 3: return "Excellent!"
        default: return "Amazing!"
        }
    }
    
    private var currentPlayerName: String {
        isPlayer1Turn ? "Player 1" : "Player 2"
    }
    
    private var currentPlayerColor: Color {
        isPlayer1Turn ? .red : .blue
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
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            let wallRadius = viewModel.boundaryRadius
            
            ZStack {
                // 1. 背景層 (iwahaikei)
                Image("iwahaikei")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .ignoresSafeArea()
                
                if wallRadius > 0 {
                    // 2. 水面エリア（池の内側）
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
                
                // 4. ガイドラインとおはじき（映り込み含む）
                ForEach(viewModel.circles, id: \.id) { ohajiki in
                    
                    // A. ドラッグ時のガイド線
                    if ohajiki.isDragging && (ohajiki.dragOffset.width != 0 || ohajiki.dragOffset.height != 0) {
                        let startX = centerX + ohajiki.offset.width
                        let startY = centerY + ohajiki.offset.height
                        let startPoint = CGPoint(x: startX, y: startY)
                        let dx = -ohajiki.dragOffset.width
                        let dy = -ohajiki.dragOffset.height
                        let distance = sqrt(dx*dx + dy*dy)
                        let targetPoint = CGPoint(
                            x: startX + (dx / max(distance, 0.001)) * (wallRadius * 2),
                            y: startY + (dy / max(distance, 0.001)) * (wallRadius * 2)
                        )
                        
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
                                .stroke(rayGradient, style: StrokeStyle(lineWidth: 50, lineCap: .round))
                                .opacity(0.12).blur(radius: 15)
                            Path { p in p.move(to: startPoint); p.addLine(to: targetPoint) }
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                                .opacity(0.8).blur(radius: 0.3)
                        }
                        .mask(Circle().frame(width: wallRadius * 2, height: wallRadius * 2).position(x: centerX, y: centerY))
                    }
                    
                    // B. 水面への映り込み (Reflection)
                    OhajikiReflectionView(ohajiki: ohajiki)
                        .offset(x: ohajiki.offset.width, y: ohajiki.offset.height + 22)
                        .position(x: centerX, y: centerY)

                    // C. 接地影 (Shadow)
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: ohajiki.radius * 2, height: ohajiki.radius * 2)
                        .blur(radius: 4)
                        .offset(x: ohajiki.offset.width, y: ohajiki.offset.height + 4)
                        .position(x: centerX, y: centerY)
                    
                    // D. おはじき本体
                    OhajikiView(ohajiki: ohajiki)
                        .offset(x: ohajiki.offset.width, y: ohajiki.offset.height)
                        .position(x: centerX, y: centerY)
                        .gesture(
                            (ohajiki.isHandBall && viewModel.areAllCirclesStopped && !showClearView && !showPauseMenu && !showModeInfo) ?
                            DragGesture()
                                .onChanged { value in
                                    if showCombo || showScoreChange {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            showCombo = false
                                            showScoreChange = false
                                        }
                                    }
                                    viewModel.startOrUpdateDragging(for: ohajiki.id, translation: value.translation)
                                    triggerDragHaptic()
                                }
                                .onEnded { value in
                                    viewModel.endDragging(for: ohajiki.id, translation: value.translation)
                                    lastDragHapticTime = .distantPast
                                }
                            : nil
                        )
                }
                
                // 5. UIレイヤー（スコア、メニュー、モード切替）
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) { showPauseMenu.toggle() }
                        }) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                        }
                        .disabled(showClearView)
                        .padding()
                        
                        Spacer()
                        
                        // 右上: ベストスコア
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.yellow)
                            Text("\(viewModel.scoreManager.bestScore)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.trailing, 24)
                    }
                    
                    // スコア表示（中央上部）
                    VStack {
                        AnimatedScoreText(targetScore: viewModel.score)
                    }
                    .offset(y: -110)
                    
                    Spacer()
                    
                    HStack {
                        if isTwoPlayerMode {
                            Text(currentPlayerName)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(currentPlayerColor)
                                .shadow(color: currentPlayerColor.opacity(0.6), radius: 8)
                                .padding(.leading, 20)
                        }
                        
                        Spacer()
                        
                        ZStack {
                            // トグルのトラック
                            Capsule()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 140, height: 72)
                            
                            // アイコン（トラック内、左右に配置）
                            HStack {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 56)
                                Spacer()
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 56)
                            }
                            .frame(width: 124)
                            
                            // 白いつまみ
                            Circle()
                                .fill(.white)
                                .frame(width: 56, height: 56)
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                                .overlay(
                                    Image(systemName: isTwoPlayerMode ? "person.2.fill" : "person.fill")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(isTwoPlayerMode ? .cyan : .cyan)
                                )
                                .offset(x: isTwoPlayerMode ? 34 : -34)
                                .animation(.easeInOut(duration: 0.2), value: isTwoPlayerMode)
                        }
                        .frame(width: 140, height: 72)
                        .contentShape(Capsule())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isTwoPlayerMode.toggle()
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { value in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if value.translation.width > 0 {
                                            isTwoPlayerMode = true
                                        } else {
                                            isTwoPlayerMode = false
                                        }
                                    }
                                }
                        )
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
                
                // 6. メッセージ系
                if showCenterMessage {
                    Text("The game is cleared when all Ohajiki disappear.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .padding(16)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(16)
                        .shadow(radius: 8)
                        .opacity(centerMessageOpacity)
                        .position(x: centerX, y: centerY)
                }
                
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
                    .position(x: centerX, y: centerY - 270)
                }
                
                if showScoreChange {
                    Text(scoreChangeText)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreChangeColor)
                        .shadow(color: scoreChangeColor.opacity(0.5), radius: 10)
                        .transition(.opacity)
                        .position(x: centerX, y: centerY - 270 + scoreChangeOffsetY)
                }
                
                // ポーズメニュー
                if showPauseMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { showPauseMenu = false } }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        menuButton(title: "Tutorial", icon: "?") {
                            showPauseMenu = false
                            showTutorial = true
                        }
                        Divider()
                        menuButton(title: "Reset", systemIcon: "arrow.counterclockwise") {
                            showPauseMenu = false
                            resetGameSequence()
                        }
                        if onBack != nil {
                            Divider()
                            menuButton(title: "Back to Home", icon: "←") {
                                showPauseMenu = false
                                viewModel.stopTimer()
                                onBack?()
                            }
                        }
                    }
                    .background(Color.white).cornerRadius(14)
                    .frame(width: 240)
                    .position(x: 140, y: 120)
                }

                // 二人モードの枠
                if isTwoPlayerMode {
                    Rectangle()
                        .fill(.clear)
                        .border(currentPlayerColor, width: 4)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                
                if showClearView {
                    ClearOverlayView(
                        score: viewModel.score,
                        bestScore: viewModel.scoreManager.bestScore,
                        maxComboCount: viewModel.maxComboCount,
                        isTwoPlayerMode: isTwoPlayerMode,
                        player1Score: player1Score,
                        player2Score: player2Score,
                        onRetry: {
                            withAnimation { showClearView = false }
                            resetGameSequence()
                        },
                        onHome: onBack != nil ? {
                            withAnimation { showClearView = false }
                            viewModel.stopTimer()
                            onBack?()
                        } : nil
                    )
                }
                
                if showModeInfo {
                    ModeInfoOverlayView(
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showModeInfo = false
                            }
                            startOpeningMessage()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .onAppear {
                viewModel.setScreenSize(geometry.size)
                viewModel.startTimer()
                if !showModeInfo {
                    startOpeningMessage()
                } else {
                    showCenterMessage = false
                }
                dragHapticGenerator.prepare()
            }
            .onChange(of: geometry.size) { _, newSize in
                viewModel.setScreenSize(newSize)
            }
            .onChange(of: viewModel.comboDisplayCount) { _, count in
                handleComboUpdate(count: count)
            }
            .onChange(of: viewModel.circles.count) { _, count in
                checkGameClear(count: count)
            }
            .onChange(of: isTwoPlayerMode) { _, _ in
                resetGameSequence(showMessage: false)
            }
            .onDisappear { viewModel.stopTimer() }
            .fullScreenCover(isPresented: $showTutorial) { FirstTutorialView(showBackButton: true) }
        }
    }
    
    // --- 処理分離ロジック ---

    private func handleComboUpdate(count: Int) {
        if count >= 1 {
            comboCount = count
            let points = count * (count + 1) * 50
            scoreChangeText = "+\(points)"
            scoreChangeColor = comboColor
            if isTwoPlayerMode {
                if isPlayer1Turn { player1Score += points } else { player2Score += points }
            }
            scoreChangeOffsetY = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCombo = true
                showScoreChange = true
            }
            withAnimation(.easeOut(duration: 1.0)) {
                    scoreChangeOffsetY = -170
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showCombo = false; showScoreChange = false }
                    }
                } else if count == 0 {
            scoreChangeText = "-50"
            scoreChangeColor = .red
            if isTwoPlayerMode {
                if isPlayer1Turn { player1Score = max(0, player1Score - 50) }
                else { player2Score = max(0, player2Score - 50) }
            }
            scoreChangeOffsetY = 0
            withAnimation(.spring()) { showScoreChange = true }
            withAnimation(.easeOut(duration: 1.0)) {
                scoreChangeOffsetY = -170
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showScoreChange = false }
            }
        }
        
        if isTwoPlayerMode && count >= 0 {
            withAnimation { isPlayer1Turn.toggle() }
        }
    }

    private func checkGameClear(count: Int) {
        if count == 1 && !hasDetectedClear {
            hasDetectedClear = true
            viewModel.finalizeCombo()
            viewModel.stopTimer()
            viewModel.scoreManager.updateBestScoreIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { showClearView = true }
            }
        }
    }

    private func startOpeningMessage() {
        showCenterMessage = true
        centerMessageOpacity = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 1.0)) { centerMessageOpacity = 0.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showCenterMessage = false }
        }
    }
    
    private func resetGameSequence(showMessage: Bool = true) {
        hasDetectedClear = false
        isPlayer1Turn = true
        player1Score = 0
        player2Score = 0
        viewModel.resetGame()
        viewModel.startTimer()
        if showMessage {
            startOpeningMessage()
        } else {
            showCenterMessage = false
        }
    }
    
    private func menuButton(title: String, icon: String? = nil, systemIcon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = icon { Text(icon).font(.system(size: 22)) }
                else if let systemIcon = systemIcon { Image(systemName: systemIcon).font(.system(size: 20)) }
                Text(title).font(.system(size: 18, weight: .medium))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
    }
    
    private func triggerDragHaptic() {
        let now = Date()
        guard now.timeIntervalSince(lastDragHapticTime) >= 0.1 else { return }
        dragHapticGenerator.impactOccurred(intensity: 0.8)
        dragHapticGenerator.prepare()
        lastDragHapticTime = now
    }
}

private struct ModeInfoOverlayView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Play Mode")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                VStack(spacing: 10) {
                    Text("This app has 1-player and 2-player modes.")
                    Text("Switch modes using the toggle at the bottom right.")
                }
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white.opacity(0.92))
                .multilineTextAlignment(.center)

                Button(action: onDismiss) {
                    Text("OK")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 180, height: 56)
                        .background(Color.blue.opacity(0.9))
                        .cornerRadius(14)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .background(Color.black.opacity(0.82))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 90)
        }
    }
}
