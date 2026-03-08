import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    ZStack {
                        Color.white.ignoresSafeArea()
                        Text("Turn your iPad to portrait mode")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ContentView()
                }
            }
        }
    }
}
