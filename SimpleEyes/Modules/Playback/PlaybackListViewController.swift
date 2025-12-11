import UIKit
import AVKit

/// 录像列表视图控制器
class PlaybackListViewController: UIViewController {

    // MARK: - Properties

    private let device: Device
    private var recordings: [Recording] = []

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.delegate = self
        table.dataSource = self
        table.register(RecordingCell.self, forCellReuseIdentifier: RecordingCell.identifier)
        table.rowHeight = 80
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无录像"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
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
        loadRecordings()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "录像列表"
        view.backgroundColor = .systemBackground

        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Data Loading

    private func loadRecordings() {
        APIClient.shared.getPlaybackList(deviceId: device.deviceId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.recordings = response.recordings
                    self?.tableView.reloadData()
                    self?.updateEmptyState()

                case .failure(let error):
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !recordings.isEmpty
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Playback

    private func playRecording(_ recording: Recording) {
        guard let url = URL(string: recording.url) else {
            showError("无效的录像地址")
            return
        }

        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player

        present(playerViewController, animated: true) {
            player.play()
        }
    }
}

// MARK: - UITableViewDataSource

extension PlaybackListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: RecordingCell.identifier, for: indexPath) as? RecordingCell else {
            return UITableViewCell()
        }

        let recording = recordings[indexPath.row]
        cell.configure(with: recording)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension PlaybackListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let recording = recordings[indexPath.row]
        playRecording(recording)
    }
}

// MARK: - RecordingCell

class RecordingCell: UITableViewCell {
    static let identifier = "RecordingCell"

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let durationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let sizeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(timeLabel)
        contentView.addSubview(durationLabel)
        contentView.addSubview(sizeLabel)

        NSLayoutConstraint.activate([
            timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            timeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            timeLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),

            durationLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 4),
            durationLabel.leadingAnchor.constraint(equalTo: timeLabel.leadingAnchor),

            sizeLabel.topAnchor.constraint(equalTo: durationLabel.topAnchor),
            sizeLabel.leadingAnchor.constraint(equalTo: durationLabel.trailingAnchor, constant: 16)
        ])

        accessoryType = .disclosureIndicator
    }

    func configure(with recording: Recording) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        timeLabel.text = formatter.string(from: recording.startTime)
        durationLabel.text = "时长: \(recording.formattedDuration)"
        sizeLabel.text = "大小: \(recording.formattedSize)"
    }
}
