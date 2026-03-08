//
//  ScoreManager.swift
//  Ohajiki
//
//  Created by 夏川宙樹 on 2025/11/30.
//

import SwiftUI

/// スコアを管理するクラス
class ScoreManager: ObservableObject {
    @Published private(set) var score: Int = 0
    
    private let bestScoreKey = "bestScore"
    
    /// ベストスコア（最高得点）を取得
    var bestScore: Int {
        UserDefaults.standard.integer(forKey: bestScoreKey)
    }
    
    /// コンボ数に応じたスコアを計算して加算
    /// 1回: 100, 2回: 300, 3回: 600, 4回: 1000, 5回: 1500
    func addComboScore(comboCount: Int) {
        guard comboCount >= 1 else { return }
        let points = comboCount * (comboCount + 1) * 50
        score += points
    }
    
    /// ミスペナルティ（合体0回）
    func applyMissPenalty() {
        score = max(0, score - 50)
    }
    
    /// スコアをリセット
    func resetScore() {
        score = 0
    }
    
    /// ベストスコアを更新（現在のスコアがベストより高い場合のみ）
    func updateBestScoreIfNeeded() {
        if score > bestScore {
            UserDefaults.standard.set(score, forKey: bestScoreKey)
        }
    }
}

/// スコアをカウントアップ/ダウンしてアニメーション表示するビュー
struct AnimatedScoreText: View {
    let targetScore: Int
    var font: Font = .system(size: 84, weight: .bold)
    var color: Color = .white
    
    @State private var displayedScore: Int = 0
    @State private var animationTask: Task<Void, Never>?
    
    var body: some View {
        Text("\(displayedScore)")
            .font(font)
            .foregroundColor(color)
            .onChange(of: targetScore) { _, newValue in
                animateTo(newValue)
            }
            .onAppear {
                displayedScore = targetScore
            }
            .onDisappear {
                animationTask?.cancel()
            }
    }
    
    @MainActor
    private func animateTo(_ target: Int) {
        animationTask?.cancel()

        let start = displayedScore
        let difference = abs(target - start)
        guard difference > 0 else { return }

        let totalDuration: Double = 0.4
        let steps = min(difference, 20)
        let increment = Double(target - start) / Double(steps)
        let intervalNanos = UInt64((totalDuration / Double(steps)) * 1_000_000_000)

        animationTask = Task { @MainActor in
            var value = Double(start)
            for step in 1...steps {
                guard !Task.isCancelled else { return }

                if step == steps {
                    displayedScore = target
                } else {
                    value += increment
                    displayedScore = Int(round(value))
                }

                if step < steps {
                    try? await Task.sleep(nanoseconds: intervalNanos)
                }
            }
        }
    }

}
