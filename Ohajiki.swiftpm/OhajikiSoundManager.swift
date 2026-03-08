import AVFoundation
import UIKit
import Foundation

@MainActor
class OhajikiSoundManager {
    static let shared = OhajikiSoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var vanishPlayer: AVAudioPlayer?
    
    // ピッチ変更再生用の共通エンジン
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    
    private var pichonBuffer: AVAudioPCMBuffer?
    private var mergeCount: Int = 0
    
    // ノードの解放を防ぐためのセット
    private var activeNodes: Set<ObjectIdentifier> = []

    init() {
        configureAudioSession()

        // 1. 通常のSE読み込み
        if let soundData = soundData(named: "collision") {
            audioPlayer = try? AVAudioPlayer(data: soundData)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 0.8
        }
        
        if let soundData = soundData(named: "vanish") {
            vanishPlayer = try? AVAudioPlayer(data: soundData)
            vanishPlayer?.prepareToPlay()
            vanishPlayer?.volume = 0.8
        }
        
        // 2. ぴちょん単発バッファの読み込み
        if let soundData = soundData(named: "merge") {
            loadPichonBuffer(data: soundData)
        }
        
        // 3. エンジンの初期設定
        setupEngine()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("AudioSessionの設定に失敗: \(error)")
        }
    }

    private func soundData(named name: String) -> Data? {
        let bundles: [Bundle] = [.module, .main]
        let normalizedTarget = name.precomposedStringWithCanonicalMapping
        let candidateNames = [name, name.precomposedStringWithCanonicalMapping, name.decomposedStringWithCanonicalMapping]
        
        // 1) まずはNSDataAsset経由で取得
        for bundle in bundles {
            for candidate in candidateNames {
                if let asset = NSDataAsset(name: candidate, bundle: bundle) {
                    return asset.data
                }
            }
        }
        
        // 2) Playground向けフォールバック: mp3を直接探索して読む
        for bundle in bundles {
            for candidate in candidateNames {
                if let url = bundle.url(forResource: candidate, withExtension: "mp3"),
                   let data = try? Data(contentsOf: url) {
                    return data
                }
            }
            
            if let resourceURL = bundle.resourceURL,
               let enumerator = FileManager.default.enumerator(
                at: resourceURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
               ) {
                for case let fileURL as URL in enumerator {
                    guard fileURL.pathExtension.lowercased() == "mp3" else { continue }
                    let baseName = fileURL.deletingPathExtension().lastPathComponent
                    if baseName.precomposedStringWithCanonicalMapping == normalizedTarget,
                       let data = try? Data(contentsOf: fileURL) {
                        return data
                    }
                }
            }
        }
        
        print("サウンドデータが見つかりません: \(name)")
        return nil
    }
    
    private func setupEngine() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        do {
            try engine.start()
        } catch {
            print("AudioEngineの起動に失敗: \(error)")
        }
    }
    
    private func loadPichonBuffer(data: Data) {
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("pichon_tmp.caf")
        do {
            try data.write(to: tmpURL)
            let file = try AVAudioFile(forReading: tmpURL)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            try file.read(into: buffer)
            pichonBuffer = buffer
        } catch {
            print("mergeバッファ読み込み失敗: \(error)")
        }
    }

    /// 衝突音の再生
    func playCollisionSound(speed: CGFloat) {
        guard let player = audioPlayer else { return }
        let volume = Float(min(max(speed / 15.0, 0.2), 1.0))
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
    
    /// 合体音（ピッチ可変）の再生
    func playPichonSound() {
        guard let buffer = pichonBuffer else { return }
        if !engine.isRunning {
            try? engine.start()
        }
        
        // 毎回新しい再生ノードとピッチ変更ノードを作成
        let playerNode = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        
        // mergeCountに応じてピッチを上げる（1回目は0, 2回目は300...）
        let pitchShift = Float(mergeCount) * 2_00.0
        timePitch.pitch = min(pitchShift, 2400.0) // 最大2オクターブ上まで
        
        engine.attach(playerNode)
        engine.attach(timePitch)
        
        // 接続: Player -> Pitch -> Mixer
        engine.connect(playerNode, to: timePitch, format: buffer.format)
        engine.connect(timePitch, to: mixer, format: buffer.format)
        
        // 再生終了後のクリーンアップ処理
        playerNode.scheduleBuffer(buffer, at: nil) { [weak self] in
            Task { @MainActor in
                self?.engine.detach(playerNode)
                self?.engine.detach(timePitch)
            }
        }
        
        playerNode.play()
        
        // 合体回数をインクリメント
        mergeCount += 1
    }
    
    /// 合体カウントのリセット（手玉を弾いた時などに呼ぶ）
    func resetMergeCount() {
        mergeCount = 0
    }
    
    /// 消滅音の再生
    func playVanishSound() {
        guard let player = vanishPlayer else { return }
        player.currentTime = 0
        player.play()
    }
}
