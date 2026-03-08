import SwiftUI

struct Ohajiki: Identifiable, Equatable { // Equatableを追加すると最適化に役立ちます
    let id: UUID
    var offset: CGSize = .zero
    var dragOffset: CGSize = .zero
    var velocity: CGSize = .zero
    var radius: CGFloat = 30
    var isDragging: Bool = false
    var isHandBall: Bool = false
    var isMerging: Bool = false   // 合体中かどうか（ビジュアル用フラグ）
    var expiryDuration: Double = 0.18
    
    // 消滅演出用のプロパティ
    var isExpiring: Bool = false
    var opacity: Double = 1.0  // 消える瞬間に0に近づける
    var scale: CGFloat = 1.0   // 消える瞬間に大きく or 小さくする
    
    var color: Color // 変化させる可能性があるなら var に変更
    var targetColor: Color
    
    init(id: UUID = UUID(), color: Color = .ohajikiBlue) { // デフォルト色を設定
        self.id = id
        self.color = color
        self.targetColor = color
    }
    
    // IDで同一性を判定するための定義（物理演算の最適化用）
    static func == (lhs: Ohajiki, rhs: Ohajiki) -> Bool {
        lhs.id == rhs.id
    }
}

struct OhajikiReflectionView: View {
    var ohajiki: Ohajiki
    
    var body: some View {
        Circle()
            .fill(ohajiki.color)
            .frame(width: ohajiki.radius * 2, height: ohajiki.radius * 2)
            .opacity(0.25) // 水面なので薄く
            .blur(radius: 4) // 水の透明度と深さを表現
            .scaleEffect(y: -0.7) // 垂直方向に反転させ、少し潰してパースをつける
            .allowsHitTesting(false)
    }
}
