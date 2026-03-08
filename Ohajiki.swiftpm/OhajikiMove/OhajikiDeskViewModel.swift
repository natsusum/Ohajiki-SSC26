//
//  OhajikiDeskViewModel.swift
//  Ohajiki
//
//  Created by 夏川宙樹 on 2025/11/30.
//

import SwiftUI
import Combine

@MainActor

/// おはじきデスク画面のViewModel
class OhajikiDeskViewModel: ObservableObject {
    @Published private(set) var circles: [Ohajiki] = []
    @Published private(set) var score: Int = 0
    @Published private(set) var comboDisplayCount: Int = 0
    @Published private(set) var maxComboCount: Int = 0
    
    private let manager: OhajikiManager
    let scoreManager: ScoreManager
    private var cancellables = Set<AnyCancellable>()
    
    init(manager: OhajikiManager, scoreManager: ScoreManager = ScoreManager()) {
        self.manager = manager
        self.scoreManager = scoreManager
        
        // Managerのcirclesの変更を監視
        manager.$circles
            .assign(to: &$circles)
        
        // ScoreManagerのscoreの変更を監視
        scoreManager.$score
            .assign(to: &$score)
        
        // コンボ表示カウントを監視 & スコア加算
        manager.$comboDisplayCount
            .dropFirst() // 初期値を無視
            .sink { [weak self] count in
                self?.comboDisplayCount = count
                if count >= 1 {
                    self?.scoreManager.addComboScore(comboCount: count)
                } else if count == 0 {
                    // 全停止後に合体0回の場合のみペナルティ（-1はリセット信号なので無視）
                    self?.scoreManager.applyMissPenalty()
                }
            }
            .store(in: &cancellables)
        
        // 最大コンボ数を監視
        manager.$maxComboCount
            .assign(to: &$maxComboCount)
    }

    convenience init() {
        self.init(manager: OhajikiManager(), scoreManager: ScoreManager())
    }
    
    /// 画面サイズを設定
    func setScreenSize(_ size: CGSize) {
        manager.setScreenSize(size)
    }
    
    /// タイマーを開始
    func startTimer() {
        manager.startTimer()
    }
    
    /// タイマーを停止
    func stopTimer() {
        manager.stopTimer()
    }
    
    /// コンボを強制確定（クリア時に使用）
    func finalizeCombo() {
        manager.finalizeComboIfNeeded()
    }
    
    /// IDを使ってドラッグ開始/更新
    func startOrUpdateDragging(for id: UUID, translation: CGSize) {
        manager.startOrUpdateDragging(for: id, translation: translation)
    }

    /// IDを使ってドラッグ終了（発射）
    func endDragging(for id: UUID, translation: CGSize) {
        manager.endDragging(for: id, translation: translation)
    }
    
    /// 円の半径を取得
    var circleRadius: CGFloat {
        return manager.circleRadius
    }
    
    /// 円形境界の半径を取得
    var boundaryRadius: CGFloat {
        return manager.boundaryRadius
    }
    
    /// 全ての玉が静止しているか
    var areAllCirclesStopped: Bool {
        return manager.areAllCirclesStopped
    }
    
    /// ゲームをリセット（全ての玉を初期状態に戻す）
    func resetGame() {
        manager.stopTimer()
        manager.resetGame()
        scoreManager.resetScore()
        manager.startTimer()
    }
    
}
