import SwiftUI
import Combine
import UIKit
import Foundation

@MainActor
/// おはじきの物理演算と状態を管理するクラス
class OhajikiManager: ObservableObject {
    @Published var circles: [Ohajiki] = []
    @Published var collisionDetected: Bool = false
    @Published var comboDisplayCount: Int = 0
    @Published var maxComboCount: Int = 0
    
    private var flickMergeCount: Int = 0
    private var isFlickActive: Bool = false
    
    let circleRadius: CGFloat = 30
    let borderWidth: CGFloat = 2
    
    private var timer: AnyCancellable?
    private var screenSize: CGSize = .zero
    private var isInitialized = false
    
    // 物理パラメータ
    private let restitution: CGFloat = 0.95 // 反発係数
    var currentFriction: CGFloat = 0.98 // 現在の摩擦係数（演出で可変）
    var defaultFriction: CGFloat = 0.96 // サブクラスで変更可能
    private let minVelocity: CGFloat = 0.3  // 停止判定の最小速度
    private let handBallEnergyMultiplier: CGFloat = 1.2 // エネルギー倍率
    var handBallFriction: CGFloat = 0.985 // 手玉の摩擦係数（サブクラスで変更可能）
    
    var boundaryRadius: CGFloat {
        let minDimension = min(screenSize.width, screenSize.height)
        return minDimension * (10.0 / 11.0) / 2.0
    }
    
    init() {
        setupInitialCircles()
    }
    
    func setupInitialCircles() {
        var newCircles: [Ohajiki] = []
        currentFriction = defaultFriction // 摩擦をリセット
        
        // 1. 手玉（白）
        var handBall = Ohajiki(color: .white)
        handBall.isHandBall = true
        handBall.radius = circleRadius * sqrt(2.0)
        handBall.targetColor = .white
        newCircles.append(handBall)
        
        // 2. おはじき配置
        let innerColors: [Color] = [
            .ohajikiRed, .ohajikiBlue, .ohajikiYellow, .ohajikiGreen,
            .ohajikiRed, .ohajikiBlue, .ohajikiYellow, .ohajikiGreen
        ]
        let outerColors: [Color] = [
            .ohajikiYellow, .ohajikiGreen, .ohajikiRed, .ohajikiBlue,
            .ohajikiYellow, .ohajikiGreen, .ohajikiRed, .ohajikiBlue
        ]
        
        for i in 0..<8 {
            var ohajiki = Ohajiki(color: innerColors[i])
            ohajiki.targetColor = innerColors[i]
            newCircles.append(ohajiki)
        }
        for i in 0..<8 {
            var ohajiki = Ohajiki(color: outerColors[i])
            ohajiki.targetColor = outerColors[i]
            newCircles.append(ohajiki)
        }
        circles = newCircles
    }
    
    func setScreenSize(_ size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        screenSize = size
        if !isInitialized {
            initializePositions()
            isInitialized = true
        }
    }
    
    func initializePositions() {
        guard circles.count >= 17 else { return }
        circles[0].offset = CGSize(width: 0, height: boundaryRadius - circles[0].radius - 20)
        let innerR = boundaryRadius * 0.3
        let outerR = boundaryRadius * 0.5
        
        for i in 0..<8 {
            let angle = Double(i) * (2.0 * Double.pi / 8.0) - (Double.pi / 2.0)
            let x = CGFloat(Foundation.cos(angle))
            let y = CGFloat(Foundation.sin(angle))
            circles[i + 1].offset = CGSize(width: x * innerR, height: y * innerR)
            circles[i + 9].offset = CGSize(width: x * outerR, height: y * outerR)
        }
    }
    
    func resetGame() {
        setupInitialCircles()
        maxComboCount = 0
        if screenSize.width > 0 && screenSize.height > 0 {
            initializePositions()
        }
    }
    
    func startTimer() {
        timer = Timer.publish(every: 0.016, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePhysics()
            }
    }
    
    func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    var areAllCirclesStopped: Bool {
        for circle in circles {
            if circle.isHandBall || circle.isExpiring || circle.isDragging { continue }
            let speed = sqrt(circle.velocity.width * circle.velocity.width + circle.velocity.height * circle.velocity.height)
            if speed >= minVelocity { return false }
        }
        return true
    }
    
    /// 手玉を含む全ての玉が停止しているか（コンボ判定用）
    private var isEverythingStopped: Bool {
        for circle in circles {
            if circle.isExpiring || circle.isDragging { continue }
            let speed = sqrt(circle.velocity.width * circle.velocity.width + circle.velocity.height * circle.velocity.height)
            if speed >= minVelocity { return false }
        }
        return true
    }
    
    private func areColorsEqual(_ color1: Color, _ color2: Color) -> Bool {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
    }
    
    func updatePhysics() {
        guard screenSize.width > 0 && screenSize.height > 0 else { return }
        let maxRadius: CGFloat = 60.0
        var circlesToRemove = Set<UUID>()
        var newCircleToAdd: Ohajiki? = nil
        
        for index in circles.indices {
            if circlesToRemove.contains(circles[index].id) || circles[index].isExpiring || circles[index].isDragging {
                continue
            }
            
            let baseRadiusA = circles[index].radius
            let rA = circles[index].isExpiring ? baseRadiusA * 1.5 : baseRadiusA
            let collisionBoundaryRadius = boundaryRadius - rA
            var currentOffset = circles[index].offset
            var finalVelocity = circles[index].velocity
            
            let moveDistance = sqrt(finalVelocity.width * finalVelocity.width + finalVelocity.height * finalVelocity.height)
            let numSteps = max(1, Int(ceil(moveDistance / (circleRadius * 0.5))))
            let stepVelocity = CGSize(width: finalVelocity.width / CGFloat(numSteps), height: finalVelocity.height / CGFloat(numSteps))
            
            var collisionOccurred = false
            
            for _ in 0..<numSteps {
                if collisionOccurred { break }
                currentOffset.width += stepVelocity.width
                currentOffset.height += stepVelocity.height
                
                // --- A. 円形壁との衝突 ---
                let distanceToCenter = sqrt(currentOffset.width * currentOffset.width + currentOffset.height * currentOffset.height)
                if distanceToCenter > collisionBoundaryRadius {
                    let nx = currentOffset.width / distanceToCenter
                    let ny = currentOffset.height / distanceToCenter
                    currentOffset.width = nx * collisionBoundaryRadius
                    currentOffset.height = ny * collisionBoundaryRadius
                    let wallRestitution: CGFloat = circles[index].isHandBall ? 0.98 : restitution
                    let dot = finalVelocity.width * nx + finalVelocity.height * ny
                    finalVelocity.width = (finalVelocity.width - 2 * dot * nx) * wallRestitution
                    finalVelocity.height = (finalVelocity.height - 2 * dot * ny) * wallRestitution
                    collisionOccurred = true
                }
                
                // --- B. 他の玉との衝突 ---
                for otherIndex in circles.indices {
                    if otherIndex == index { continue }
                    let ohajikiB = circles[otherIndex]
                    if ohajikiB.isDragging || circlesToRemove.contains(ohajikiB.id) {
                        continue
                    }
                    
                    let dx = ohajikiB.offset.width - currentOffset.width
                    let dy = ohajikiB.offset.height - currentOffset.height
                    let distance = sqrt(dx * dx + dy * dy)
                    let baseRadiusB = ohajikiB.radius
                    let rB_effective = ohajikiB.isExpiring ? baseRadiusB * 1.5 : baseRadiusB
                    let minDistance = rA + rB_effective
                    
                    if distance < minDistance && distance > 0 {
                        let sameColor = areColorsEqual(circles[index].color, ohajikiB.color)
                        
                        if sameColor && !circles[index].isHandBall && !ohajikiB.isHandBall && !ohajikiB.isExpiring {
                            // --- 合体ロジック ---
                            let rB = ohajikiB.radius
                            let radiusC = (sqrt(baseRadiusA * baseRadiusA + rB * rB) * 100).rounded() / 100
                            let centerX = (baseRadiusA * currentOffset.width + rB * ohajikiB.offset.width) / (baseRadiusA + rB)
                            let centerY = (baseRadiusA * currentOffset.height + rB * ohajikiB.offset.height) / (baseRadiusA + rB)
                            
                            let areaA = baseRadiusA * baseRadiusA
                            let areaB = rB * rB
                            let totalArea = areaA + areaB
                            let velX = (finalVelocity.width * areaA + ohajikiB.velocity.width * areaB) / totalArea
                            let velY = (finalVelocity.height * areaA + ohajikiB.velocity.height * areaB) / totalArea
                            
                            var combined = Ohajiki(color: circles[index].color)
                            combined.radius = radiusC
                            combined.offset = CGSize(width: centerX, height: centerY)
                            combined.velocity = CGSize(width: velX, height: velY)
                            combined.isMerging = true
                            
                            // 消滅判定
                            if radiusC >= maxRadius {
                                combined.isExpiring = true
                                combined.velocity = .zero
                                
                                // ★最後の一つ判定ロジック
                                // 現在のcirclesから、これから削除される2つを引き、新しく増える1つを数える
                                let remainingCount = circles.filter { !$0.isHandBall && !$0.isExpiring }.count - 2 + 1
                                let isLastOne = remainingCount <= 1
                                
                                // 最後なら2秒、通常なら0.18秒
                                let vanishDuration = isLastOne ? 1.0 : 0.18
                                    combined.expiryDuration = vanishDuration
                                
                                let idToRemove = combined.id
                                OhajikiSoundManager.shared.playVanishSound()
                                DispatchQueue.main.asyncAfter(deadline: .now() + vanishDuration) { [weak self] in
                                    self?.circles.removeAll { $0.id == idToRemove }
                                }
                            }
                            
                            newCircleToAdd = combined
                            circlesToRemove.insert(circles[index].id)
                            circlesToRemove.insert(ohajikiB.id)
                            flickMergeCount += 1
                            OhajikiSoundManager.shared.playPichonSound()
                            collisionOccurred = true
                            break
                        } else {
                            // --- 通常の跳ね返り ---
                            let nx = dx / distance
                            let ny = dy / distance
                            
                            if ohajikiB.isExpiring {
                                let ballRestitution: CGFloat = circles[index].isHandBall ? 0.93 : restitution
                                let overlap = minDistance - distance
                                currentOffset.width -= nx * overlap
                                currentOffset.height -= ny * overlap
                                let dot = finalVelocity.width * nx + finalVelocity.height * ny
                                finalVelocity.width = (finalVelocity.width - 2 * dot * nx) * ballRestitution
                                finalVelocity.height = (finalVelocity.height - 2 * dot * ny) * ballRestitution
                            } else {
                                let rvX = ohajikiB.velocity.width - finalVelocity.width
                                let rvY = ohajikiB.velocity.height - finalVelocity.height
                                let relativeSpeed = rvX * nx + rvY * ny
                                
                                if relativeSpeed < 0 {
                                    OhajikiSoundManager.shared.playCollisionSound(speed: abs(relativeSpeed))
                                    if circles[index].isHandBall { collisionDetected = true }
                                    let ballRestitution: CGFloat = circles[index].isHandBall ? 0.93 : restitution
                                    let impulse = relativeSpeed * ballRestitution
                                    finalVelocity.width += impulse * nx
                                    finalVelocity.height += impulse * ny
                                    let energyMult = circles[index].isHandBall ? handBallEnergyMultiplier : 1.0
                                    circles[otherIndex].velocity.width -= impulse * nx * energyMult
                                    circles[otherIndex].velocity.height -= impulse * ny * energyMult
                                    
                                    let overlap = minDistance - distance
                                    currentOffset.width -= nx * overlap * 0.5
                                    currentOffset.height -= ny * overlap * 0.5
                                    circles[otherIndex].offset.width += nx * overlap * 0.5
                                    circles[otherIndex].offset.height += ny * overlap * 0.5
                                }
                            }
                            collisionOccurred = true
                            break
                        }
                    }
                }
                if newCircleToAdd != nil { break }
            }
            circles[index].offset = currentOffset
            // 現在の摩擦係数を適用（手玉は摩擦が弱い＝よく滑る）
            let friction = circles[index].isHandBall ? handBallFriction : currentFriction
            circles[index].velocity = CGSize(width: finalVelocity.width * friction, height: finalVelocity.height * friction)
            
            if abs(circles[index].velocity.width) < minVelocity { circles[index].velocity.width = 0 }
            if abs(circles[index].velocity.height) < minVelocity { circles[index].velocity.height = 0 }
            if newCircleToAdd != nil { break }
        }
        
        if !circlesToRemove.isEmpty {
            circles.removeAll { circlesToRemove.contains($0.id) }
        }
        
        if let new = newCircleToAdd {
            var adjustedNew = new
            for _ in 0..<5 {
                var foundOverlap = false
                for other in circles where other.id != adjustedNew.id && !other.isExpiring {
                    let dx = other.offset.width - adjustedNew.offset.width
                    let dy = other.offset.height - adjustedNew.offset.height
                    let distance = sqrt(dx * dx + dy * dy)
                    let minDistance = adjustedNew.radius + other.radius
                    if distance < minDistance && distance > 0 {
                        let overlap = minDistance - distance
                        let nx = dx / distance
                        let ny = dy / distance
                        adjustedNew.offset.width -= nx * overlap * 1.1
                        adjustedNew.offset.height -= ny * overlap * 1.1
                        foundOverlap = true
                    }
                }
                let distToCenter = sqrt(adjustedNew.offset.width * adjustedNew.offset.width + adjustedNew.offset.height * adjustedNew.offset.height)
                let maxAllowedDist = boundaryRadius - adjustedNew.radius
                if distToCenter > maxAllowedDist {
                    let nx = adjustedNew.offset.width / distToCenter
                    let ny = adjustedNew.offset.height / distToCenter
                    adjustedNew.offset.width = nx * maxAllowedDist
                    adjustedNew.offset.height = ny * maxAllowedDist
                    foundOverlap = true
                }
                if !foundOverlap { break }
            }
            circles.append(adjustedNew)
            let mergingId = adjustedNew.id
            let duration = adjustedNew.expiryDuration // 消滅中ならその時間、通常なら0.18
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (adjustedNew.isExpiring ? duration : 0.18)) { [weak self] in
                if let idx = self?.circles.firstIndex(where: { $0.id == mergingId }) {
                    self?.circles[idx].isMerging = false
                }
            }
        }
        
        // コンボ判定: フリック後、全ての玉が停止したらコンボ数を確定
        if isFlickActive && isEverythingStopped {
            isFlickActive = false
            // 0の場合も通知（ミスペナルティ用）
            comboDisplayCount = flickMergeCount
            if flickMergeCount > maxComboCount {
                maxComboCount = flickMergeCount
            }
        }
    }
    
    /// フリック中のコンボを強制確定する（クリア時など、タイマー停止前に呼ぶ）
    func finalizeComboIfNeeded() {
        if isFlickActive {
            isFlickActive = false
            comboDisplayCount = flickMergeCount
            if flickMergeCount > maxComboCount {
                maxComboCount = flickMergeCount
            }
        }
    }
    
    func startOrUpdateDragging(for id: UUID, translation: CGSize) {
        if let index = circles.firstIndex(where: { $0.id == id }) {
            circles[index].isDragging = true
            circles[index].dragOffset = translation
        }
    }
    
    func endDragging(for id: UUID, translation: CGSize) {
        if let index = circles.firstIndex(where: { $0.id == id }) {
            circles[index].isDragging = false
            let dragDistance = sqrt(translation.width * translation.width + translation.height * translation.height)
            if dragDistance > 0 {
                OhajikiSoundManager.shared.resetMergeCount()
                comboDisplayCount = -1 // リセット信号（ペナルティ対象外）
                flickMergeCount = 0
                isFlickActive = true
                let nx = -translation.width / dragDistance
                let ny = -translation.height / dragDistance
                let baseSpeed: CGFloat = 70.0
                circles[index].velocity = CGSize(width: nx * baseSpeed, height: ny * baseSpeed)
            } else {
                circles[index].velocity = .zero
            }
            circles[index].dragOffset = .zero
        }
    }
}
