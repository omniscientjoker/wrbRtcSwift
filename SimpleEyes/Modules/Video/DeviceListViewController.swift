import UIKit

/// 设备列表视图控制器
class DeviceListViewController: UIViewController {

    // MARK: - Properties

    private var devices: [Device] = []
    private var refreshControl = UIRefreshControl()

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.delegate = self
        table.dataSource = self
        table.register(DeviceCell.self, forCellReuseIdentifier: DeviceCell.identifier)
        table.rowHeight = 80
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无设备\n请先注册设备"
        label.textAlignment = .center
        label.textColor = .gray
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        loadDevices()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "设备列表"
        view.backgroundColor = .systemBackground

        // 添加刷新控件
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        // 添加子视图
        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        // 布局约束
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // 导航栏按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(handleRefresh)
        )
    }

    // MARK: - Data Loading

    private func loadDevices() {
        APIClient.shared.getDeviceList { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()

                switch result {
                case .success(let response):
                    self.devices = response.devices
                    self.tableView.reloadData()
                    self.updateEmptyState()

                case .failure(let error):
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func handleRefresh() {
        loadDevices()
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !devices.isEmpty
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Navigation

    private func showDeviceDetail(_ device: Device) {
        let detailVC = DeviceDetailViewController(device: device)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension DeviceListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: DeviceCell.identifier, for: indexPath) as? DeviceCell else {
            return UITableViewCell()
        }

        let device = devices[indexPath.row]
        cell.configure(with: device)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension DeviceListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let device = devices[indexPath.row]
        showDeviceDetail(device)
    }
}

// MARK: - DeviceCell

class DeviceCell: UITableViewCell {
    static let identifier = "DeviceCell"

    private let deviceNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let deviceIdLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(deviceNameLabel)
        contentView.addSubview(deviceIdLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(statusIndicator)

        NSLayoutConstraint.activate([
            deviceNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            deviceNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            deviceNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusIndicator.leadingAnchor, constant: -8),

            deviceIdLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 4),
            deviceIdLabel.leadingAnchor.constraint(equalTo: deviceNameLabel.leadingAnchor),
            deviceIdLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),

            statusIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusIndicator.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -6),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8),

            statusLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])

        accessoryType = .disclosureIndicator
    }

    func configure(with device: Device) {
        deviceNameLabel.text = device.name
        deviceIdLabel.text = device.deviceId
        statusLabel.text = device.status.displayText

        switch device.status {
        case .online:
            statusIndicator.backgroundColor = .systemGreen
        case .offline:
            statusIndicator.backgroundColor = .systemGray
        }
    }
}
