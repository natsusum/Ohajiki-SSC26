import SwiftUI
import AVKit

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showStartButton = false
    @State private var videoFinished = false
    @State private var showSecondText = false
    @State private var showText = true
    @State private var showTutorialHint = false
    let hasCompletedTutorial: Bool
    var onStart: () -> Void
    var onTutorial: () -> Void
    
    var body: some View {
        ZStack {
            VideoBackgroundView(
                videoURL: Bundle.main.url(forResource: "onboarding", withExtension: "mp4"),
                placeholderImageName: nil,
                onVideoFinished: {
                    videoFinished = true
                    // 動画が終わったらスタートボタンは表示しない（2つ目のテキストをタップしたら表示）
                }
            )
            .ignoresSafeArea()
            
            // 説明文とスタートボタン
            VStack {
                Spacer()
                
                // 説明文
                if showText {
                    if !showSecondText {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What are Ohajiki?")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Ohajiki are traditional Japanese toys made of glass in the shape of flat discs. \nThey are primarily played by flicking one Ohajiki scattered on the floor or similar surface to hit another Ohajiki.")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .lineSpacing(4)
                            HStack {
                                Spacer()
                                AnimatedPromptArrow()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .onTapGesture {
                            showSecondText = true
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About this App")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Ohajiki supports children’s cognitive development and helps prevent cognitive decline in older adults. This app is designed to connect elderly users with tech-savvy children, encouraging intergenerational interaction while promoting cognitive health and early development.")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .lineSpacing(4)
                            HStack {
                                Spacer()
                                AnimatedPromptArrow()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .onTapGesture {
                            showText = false // テキストを消す
                            showStartButton = true // スタートボタンを表示
                        }
                    }
                }
                
                // ヒントメッセージ
                if showTutorialHint {
                    Text("Please Play the Tutorial first.")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(16)
                        .transition(.opacity)
                        .padding(.bottom, 8)
                }
                
                // ボタンエリア
                if showStartButton {
                    VStack(spacing: 16) {
                        // スタートボタン（チュートリアル完了済みの場合のみタップ可能）
                        Button(action: {
                            if hasCompletedTutorial {
                                hasSeenOnboarding = true
                                onStart()
                            } else {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showTutorialHint = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showTutorialHint = false
                                    }
                                }
                            }
                        }) {
                            Text("Start the Game")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(hasCompletedTutorial ? Color.blue.opacity(0.6) : Color.gray.opacity(0.6))
                                .cornerRadius(50)
                                .shadow(radius: 10)
                        }
                        
                        // play tutorial ボタン（常にタップ可能）
                        Button(action: {
                            hasSeenOnboarding = true
                            onTutorial()
                        }) {
                            Text("Play Tutorial")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.cyan)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.white.opacity(0.7))
                                .cornerRadius(50)
                                .shadow(radius: 10)
                        }
                    }
                    .padding(.horizontal, 180)
                    .padding(.bottom, 80)
                }
            }
        }
        .onAppear {
            if hasCompletedTutorial {
                // チュートリアル完了済みならテキストをスキップしてボタンを即表示
                showText = false
                showStartButton = true
            } else {
                showStartButton = false
            }
        }
    }
}

private struct AnimatedPromptArrow: View {
    @State private var isMovingDown = false

    var body: some View {
        Text("▽")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
            .offset(y: isMovingDown ? 6 : -2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    isMovingDown = true
                }
            }
    }
}

struct VideoBackgroundView: UIViewControllerRepresentable {
    var videoURL: URL?
    var placeholderImageName: String?
    var onVideoFinished: (() -> Void)?

    func makeUIViewController(context: Context) -> VideoBackgroundViewController {
        let controller = VideoBackgroundViewController(
            videoURL: videoURL,
            placeholderImageName: placeholderImageName
        )
        controller.onVideoFinished = onVideoFinished
        return controller
    }

    func updateUIViewController(_ uiViewController: VideoBackgroundViewController, context: Context) {
    }
}

class VideoBackgroundViewController: UIViewController {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private let videoURL: URL?
    private let placeholderImageName: String?
    private let imageView = UIImageView()
    var onVideoFinished: (() -> Void)?

    init(videoURL: URL?, placeholderImageName: String?) {
        self.videoURL = videoURL
        self.placeholderImageName = placeholderImageName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupImageView()
        setupVideoPlayer()
        setupObservers()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    private func setupImageView() {
        guard let imageName = placeholderImageName, let image = UIImage(named: imageName) else { return }

        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupVideoPlayer() {
        guard let url = videoURL else { return }

        player = AVPlayer(url: url)
        player?.isMuted = false

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = view.bounds
        playerLayer?.videoGravity = .resizeAspectFill

        if let playerLayer = playerLayer {
            view.layer.addSublayer(playerLayer)
        }

        player?.play()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func playerDidFinishPlaying() {
        // 毎回動画終了時にコールバックを呼ぶ
        DispatchQueue.main.async {
            self.onVideoFinished?()
        }
        // ループ再生
        player?.seek(to: .zero)
        player?.play()
    }

    @objc private func handleAppWillEnterForeground() {
        player?.play()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

#Preview {
    OnboardingView(hasCompletedTutorial: false, onStart: {}, onTutorial: {})
}
