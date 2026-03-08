import SwiftUI

/// 画面中央に配置される円形の境界線（壁）を描画するためのShape
struct CircularBoundaryShape: Shape {
    let diameter: CGFloat
    let lineWidth: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let radius = diameter / 2.0
        
        // 描画の中心を親ビューの真ん中に合わせる
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        var path = Path()
        
        // 矩形の描画領域の中央を起点として、指定された直径の円を作成
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: true
        )
        
        return path
    }
}
