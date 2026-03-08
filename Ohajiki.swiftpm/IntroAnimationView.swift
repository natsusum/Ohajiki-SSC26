//
//  IntroAnimationView.swift
//  Ohajiki
//
//  Created on 2026/01/25.
//

import SwiftUI
import Combine

struct IntroAnimationView: View {
    @StateObject private var manager = IntroAnimationManager()
    @State private var wasTapped = false
    @State private var isTapToStartVisible = true
    var onComplete: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景を水面エリアに設定
                GeometryReader { _ in
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
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.1), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }
                .ignoresSafeArea()
                
                // タイトル表示（おはじきの下レイヤー）
                Text("Ohajiki")
                    .font(.system(size: 172, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // 各円を描画（OhajikiDeskViewと同じ見た目）
                ForEach(manager.circles) { circle in
                    OhajikiView(ohajiki: circle, showOuterGlow: false)
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 12)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .position(
                            x: geometry.size.width / 2 + circle.offset.width,
                            y: geometry.size.height / 2 + circle.offset.height
                        )
                }
                
                // 全ての玉が止まったら「tap to start」を表示
                if manager.allBallsStopped {
                    VStack {
                        Spacer()
                        Text("tap to start")
                            .font(.system(size: 54, weight: .medium))
                            .foregroundColor(.white)
                            .opacity(isTapToStartVisible ? 1.0 : 0.2)
                            .onAppear {
                                isTapToStartVisible = true
                                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                                    isTapToStartVisible = false
                                }
                            }
                            .padding(.bottom, 100)
                    }
                }
            }
            .onTapGesture {
                // 画面のどこかをタップしたらオンボーディング画面に遷移
                wasTapped = true
                manager.stopTimer()
                onComplete()
            }
            .onAppear {
                // アプリ起動時に毎回アニメーションをリセット
                manager.setScreenSize(geometry.size)
                manager.resetAnimation()
                manager.startTimer()
                // アプリ起動から1秒後に速度を設定
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    manager.giveVelocityToYellowBall()
                }
            }
            .onChange(of: geometry.size) { newSize in
                manager.setScreenSize(newSize)
            }
            .onDisappear {
                manager.stopTimer()
            }
        }
    }
}

/// イントロアニメーション用のおはじきマネージャー（黄色い玉1つと赤い玉1つ）
class IntroAnimationManager: OhajikiManager {
    @Published var allBallsStopped: Bool = false
    private var hasVelocityBeenGiven: Bool = false
    
    // 物理パラメータ（親クラスと同じ値）
    private let restitution: CGFloat = 0.9  // 反発係数
    private let friction: CGFloat = 0.96    // 空気抵抗
    private let minVelocity: CGFloat = 0.2  // 停止判定の最小速度
    private let handBallEnergyMultiplier: CGFloat = 1.0 // 手玉が当たった時のエネルギー倍率
    
    // 色の比較ヘルパー関数
    private func areColorsEqual(_ color1: Color, _ color2: Color) -> Bool {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
    }
    
    override func setupInitialCircles() {
        var yellow = Ohajiki(color: .ohajikiGreen)
                yellow.radius = 90
                var red = Ohajiki(color: .ohajikiRed)
                red.radius = 90
                circles = [yellow, red]
    }
    
    override func initializePositions() {
        guard circles.count >= 2 else { return }
        
        // 黄色い玉を画面外の左に配置（初期速度は0）
        var yellowBall = circles[0]
        yellowBall.offset = CGSize(width: -boundaryRadius * 3.5, height: 0)
        yellowBall.velocity = CGSize(width: 0, height: 0) // 初期速度は0（1秒後に速度を与える）
        circles[0] = yellowBall
        
        // 赤い玉を中央に配置
        var redBall = circles[1]
        redBall.offset = CGSize(width: 0, height: 0)
        circles[1] = redBall
    }
    
    func resetAnimation() {
        // アニメーションをリセット
        allBallsStopped = false
        hasVelocityBeenGiven = false
        setupInitialCircles()
        // boundaryRadiusが設定されている場合のみ初期位置を設定
        if boundaryRadius > 0 {
            initializePositions()
        }
    }
    
    func giveVelocityToYellowBall() {
        guard circles.count >= 1 else { return }
        OhajikiSoundManager.shared.resetMergeCount()
        // 黄色い玉に右向きの速度を与える（速度70）
        var yellowBall = circles[0]
        yellowBall.velocity = CGSize(width: 80, height: 0)
        circles[0] = yellowBall // @Published の変更通知を発火させるために再代入
        allBallsStopped = false // 速度を与えたので、停止状態をリセット
        hasVelocityBeenGiven = true // 速度が与えられたことを記録
    }
    
    override func updatePhysics() {
        guard boundaryRadius > 0 else { return }
        
        let maxRadius: CGFloat = 120.0  // 玉の半径60の2倍
        var circlesToRemove = Set<UUID>()
        var newCircleToAdd: Ohajiki? = nil
        
        // 1. 各玉の移動と衝突判定（壁との衝突判定はスキップ）
        for index in circles.indices {
            // すでに処理済み、消滅中、ドラッグ中はスキップ
            if circlesToRemove.contains(circles[index].id) || circles[index].isExpiring || circles[index].isDragging {
                continue
            }
            
            let rA = circles[index].radius
            
            var currentOffset = circles[index].offset
            var finalVelocity = circles[index].velocity
            
            // 速度に基づいたサブステップ計算（トンネル現象防止）
            let moveDistance = sqrt(finalVelocity.width * finalVelocity.width + finalVelocity.height * finalVelocity.height)
            let numSteps = max(1, Int(ceil(moveDistance / (circleRadius * 0.5))))
            let stepVelocity = CGSize(width: finalVelocity.width / CGFloat(numSteps), height: finalVelocity.height / CGFloat(numSteps))
            
            var collisionOccurred = false
            
            for _ in 0..<numSteps {
                if collisionOccurred { break }
                
                currentOffset.width += stepVelocity.width
                currentOffset.height += stepVelocity.height
                
                // 壁との衝突判定はスキップ（画面端でも跳ね返らない）
                
                // --- 他の玉との衝突 ---
                for otherIndex in circles.indices {
                    if otherIndex == index { continue }
                    
                    let ohajikiB = circles[otherIndex]
                    
                    // 衝突対象外の判定
                    if ohajikiB.isDragging || ohajikiB.isExpiring || circlesToRemove.contains(ohajikiB.id) {
                        continue
                    }
                    
                    let dx = ohajikiB.offset.width - currentOffset.width
                    let dy = ohajikiB.offset.height - currentOffset.height
                    let distance = sqrt(dx * dx + dy * dy)
                    let minDistance = rA + ohajikiB.radius
                    
                    if distance < minDistance && distance > 0 {
                        let sameColor = areColorsEqual(circles[index].color, ohajikiB.color)
                        
                        if sameColor && !circles[index].isHandBall && !ohajikiB.isHandBall {
                            // --- 合体ロジック ---
                            let rB = ohajikiB.radius
                            let radiusC = (sqrt(rA * rA + rB * rB) * 100).rounded() / 100
                            
                            let centerX = (rA * currentOffset.width + rB * ohajikiB.offset.width) / (rA + rB)
                            let centerY = (rA * currentOffset.height + rB * ohajikiB.offset.height) / (rA + rB)
                            
                            let areaA = rA * rA
                            let areaB = rB * rB
                            let totalArea = areaA + areaB
                            let velX = (finalVelocity.width * areaA + ohajikiB.velocity.width * areaB) / totalArea
                            let velY = (finalVelocity.height * areaA + ohajikiB.velocity.height * areaB) / totalArea
                            
                            var combined = Ohajiki(color: circles[index].color)
                            combined.radius = radiusC
                            combined.offset = CGSize(width: centerX, height: centerY)
                            combined.velocity = CGSize(width: velX, height: velY)
                            
                            for checkIndex in circles.indices {
                                // 消える予定の2つと、自分自身はスキップ
                                if checkIndex == index || checkIndex == otherIndex { continue }
                                
                                let otherBall = circles[checkIndex]
                                let cdx = otherBall.offset.width - combined.offset.width
                                let cdy = otherBall.offset.height - combined.offset.height
                                let cDist = sqrt(cdx * cdx + cdy * cdy)
                                let cMinDist = combined.radius + otherBall.radius
                                
                                if cDist < cMinDist && cDist > 0 {
                                    let overlap = cMinDist - cDist
                                    let cnx = cdx / cDist
                                    let cny = cdy / cDist
                                    // 周囲の玉を外側に押し出す
                                    circles[checkIndex].offset.width += cnx * overlap
                                    circles[checkIndex].offset.height += cny * overlap
                                }
                            }
                            
                            if radiusC >= maxRadius {
                                combined.isExpiring = true
                                let idToRemove = combined.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                                    self?.circles.removeAll { $0.id == idToRemove }
                                }
                            }
                            
                            newCircleToAdd = combined
                            circlesToRemove.insert(circles[index].id)
                            circlesToRemove.insert(ohajikiB.id)
                            
                            // 同じ色の玉が衝突した時に「ぴちょん単発」を再生
                            OhajikiSoundManager.shared.playPichonSound()
                            collisionOccurred = true
                            break
                        } else {
                            // --- 通常の跳ね返り ---
                            let nx = dx / distance
                            let ny = dy / distance
                            let rvX = ohajikiB.velocity.width - finalVelocity.width
                            let rvY = ohajikiB.velocity.height - finalVelocity.height
                            let relativeSpeed = rvX * nx + rvY * ny
                            
                            if relativeSpeed < 0 {
                                OhajikiSoundManager.shared.playCollisionSound(speed: abs(relativeSpeed))
                                
                                if circles[index].isHandBall {
                                    collisionDetected = true
                                }
                                
                                let impulse = relativeSpeed * restitution
                                finalVelocity.width += impulse * nx
                                finalVelocity.height += impulse * ny
                                
                                let energyMult = circles[index].isHandBall ? handBallEnergyMultiplier : 1.0
                                circles[otherIndex].velocity.width -= impulse * nx * energyMult
                                circles[otherIndex].velocity.height -= impulse * ny * energyMult
                                
                                // 重なり解消
                                let overlap = minDistance - distance
                                currentOffset.width -= nx * overlap * 0.5
                                currentOffset.height -= ny * overlap * 0.5
                                circles[otherIndex].offset.width += nx * overlap * 0.5
                                circles[otherIndex].offset.height += ny * overlap * 0.5
                                
                                collisionOccurred = true
                                break
                            }
                        }
                    }
                }
                if newCircleToAdd != nil { break }
            }
            
            circles[index].offset = currentOffset
            circles[index].velocity = CGSize(width: finalVelocity.width * friction, height: finalVelocity.height * friction)
            
            if abs(circles[index].velocity.width) < minVelocity { circles[index].velocity.width = 0 }
            if abs(circles[index].velocity.height) < minVelocity { circles[index].velocity.height = 0 }
            
            if newCircleToAdd != nil { break }
        }
        
        // 2. 既存の玉も半径チェック（合体時以外でも大きくなった場合に備える）
        for index in circles.indices {
            if circles[index].radius >= maxRadius && !circles[index].isHandBall && !circles[index].isExpiring {
                circles[index].isExpiring = true
                let idToRemove = circles[index].id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.circles.removeAll { $0.id == idToRemove }
                }
            }
        }
        
        // 3. 配列の更新（一括で行う）
        if !circlesToRemove.isEmpty {
            circles.removeAll { circlesToRemove.contains($0.id) }
        }
        if let new = newCircleToAdd {
            circles.append(new)
        }
        
        // 4. 全ての玉の速度が0かどうかをチェック（速度が一度でも与えられた後のみ）
        if hasVelocityBeenGiven {
            let allStopped = circles.allSatisfy { circle in
                abs(circle.velocity.width) < minVelocity && abs(circle.velocity.height) < minVelocity
            }
            if allStopped != allBallsStopped {
                allBallsStopped = allStopped
            }
        }
        
        // @Published の変更通知を確実に発火させるために、objectWillChangeを送信
        objectWillChange.send()
    }
}

#Preview {
    IntroAnimationView(onComplete: {})
}
