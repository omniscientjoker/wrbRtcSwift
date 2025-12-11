import UIKit
import AVFoundation
import AVKit

/// 设备详情视图控制器
/// 包含视频播放和对讲功能
class DeviceDetailViewController: UIViewController {

    // MARK: - Properties

    private let device: Device
    private var intercomManager: IntercomManager?
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?

    // MARK: - UI Components

    private lazy var videoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var deviceInfoLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var intercomButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("开始对讲", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 28
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(intercomButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "空闲"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var playbackButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("查看录像", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(showPlaybackList), for: .touchUpInside)
        return button
    }()

    // MARK: - Initialization

    init(device: Device) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupIntercom()
        loadLiveStream()
        updateDeviceInfo()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // 停止视频播放
        player?.pause()

        // 停止对讲
        if intercomManager?.isIntercomActive() == true {
            intercomManager?.stopIntercom()
        }
    }

    // MARK: - Setup

    private func setupUI() {
        title = device.name
        view.backgroundColor = .systemBackground

        view.addSubview(videoContainerView)
        view.addSubview(deviceInfoLabel)
        view.addSubview(intercomButton)
        view.addSubview(statusLabel)
        view.addSubview(playbackButton)

        NSLayoutConstraint.activate([
            // 视频容器
            videoContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            videoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoContainerView.heightAnchor.constraint(equalTo: videoContainerView.widthAnchor, multiplier: 9.0/16.0),

            // 设备信息
            deviceInfoLabel.topAnchor.constraint(equalTo: videoContainerView.bottomAnchor, constant: 16),
            deviceInfoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            deviceInfoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // 对讲按钮
            intercomButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            intercomButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            intercomButton.widthAnchor.constraint(equalToConstant: 200),
            intercomButton.heightAnchor.constraint(equalToConstant: 56),

            // 状态标签
            statusLabel.topAnchor.constraint(equalTo: intercomButton.bottomAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // 录像按钮
            playbackButton.bottomAnchor.constraint(equalTo: intercomButton.topAnchor, constant: -20),
            playbackButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupIntercom() {
        intercomManager = IntercomManager(deviceId: device.deviceId)

        intercomManager?.onStatusChanged = { [weak self] status in
            DispatchQueue.main.async {
                self?.updateIntercomUI(status: status)
            }
        }
    }

    private func updateDeviceInfo() {
        let info = """
        设备 ID: \(device.deviceId)
        型号: \(device.model)
        状态: \(device.status.displayText)
        """
        deviceInfoLabel.text = info
    }

    // MARK: - Video Loading

    private func loadLiveStream() {
        guard device.status == .online else {
            showMessage("设备离线，无法查看视频")
            return
        }

        APIClient.shared.getLiveStream(deviceId: device.deviceId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.playVideo(url: response.url)

                case .failure(let error):
                    self?.showMessage("加载视频失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func playVideo(url: String) {
        guard let videoURL = URL(string: url) else {
            showMessage("无效的视频地址")
            return
        }

        // 创建播放器
        player = AVPlayer(url: videoURL)
        playerViewController = AVPlayerViewController()
        playerViewController?.player = player

        // 添加播放器视图
        if let playerVC = playerViewController {
            addChild(playerVC)
            videoContainerView.addSubview(playerVC.view)
            playerVC.view.frame = videoContainerView.bounds
            playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            playerVC.didMove(toParent: self)
        }

        // 开始播放
        player?.play()
    }

    // MARK: - Intercom

    @objc private func intercomButtonTapped() {
        guard let intercomManager = intercomManager else { return }

        if intercomManager.isIntercomActive() {
            intercomManager.stopIntercom()
        } else {
            intercomManager.startIntercom()
        }
    }

    private func updateIntercomUI(status: IntercomStatus) {
        statusLabel.text = status.displayText

        switch status {
        case .idle:
            intercomButton.setTitle("开始对讲", for: .normal)
            intercomButton.backgroundColor = .systemBlue
            intercomButton.isEnabled = true

        case .connecting:
            intercomButton.setTitle("连接中...", for: .normal)
            intercomButton.isEnabled = false

        case .connected, .speaking:
            intercomButton.setTitle("停止对讲", for: .normal)
            intercomButton.backgroundColor = .systemRed
            intercomButton.isEnabled = true

        case .error(let message):
            intercomButton.setTitle("开始对讲", for: .normal)
            intercomButton.backgroundColor = .systemBlue
            intercomButton.isEnabled = true
            showMessage("对讲错误: \(message)")
        }
    }

    // MARK: - Playback

    @objc private func showPlaybackList() {
        let playbackVC = PlaybackListViewController(device: device)
        navigationController?.pushViewController(playbackVC, animated: true)
    }

    // MARK: - Helpers

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
