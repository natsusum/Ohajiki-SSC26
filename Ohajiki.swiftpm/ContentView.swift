import SwiftUI

enum PostOnboardingDestination {
    case tutorial
    case game
}

/// セッションレベルのチュートリアル完了状態（UserDefaults/AppStorageは使わない）
@MainActor
class TutorialSession: ObservableObject {
    static let shared = TutorialSession()
    @Published var hasCompletedTutorial = false
    private init() {}
}

struct ContentView: View {
    @ObservedObject private var tutorialSession = TutorialSession.shared
    @State private var showIntroAnimation = true
    @State private var destination: PostOnboardingDestination? = nil
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            Group {
                if isLandscape {
                    Color.white
                        .overlay(
                            VStack(spacing: 24) {
                                Image(systemName: "ipad")
                                    .font(.system(size: 84, weight: .regular))
                                    .foregroundColor(.black)
                                Text("Please rotate your iPad to portrait orientation.")
                                    .font(.system(size: 38, weight: .semibold))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        )
                } else if showIntroAnimation {
                    IntroAnimationView(
                        onComplete: {
                            showIntroAnimation = false
                        }
                    )
                } else if let dest = destination {
                    switch dest {
                    case .tutorial:
                        FirstTutorialView()
                    case .game:
                        OhajikiDeskView(onBack: {
                            destination = nil
                        })
                    }
                } else {
                    OnboardingView(
                        hasCompletedTutorial: tutorialSession.hasCompletedTutorial,
                        onStart: {
                            destination = .game
                        },
                        onTutorial: {
                            tutorialSession.hasCompletedTutorial = false
                            destination = .tutorial
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
        .onChange(of: tutorialSession.hasCompletedTutorial) { completed in
            // チュートリアル完了後、OnboardingViewに戻す
            if completed && destination == .tutorial {
                destination = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
