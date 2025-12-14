import SwiftUI

// MARK: - 页面日志查看器（可选，用于调试）
struct PageLogView: View {
    @State private var logs: [PageLog] = []

    var body: some View {
        List {
            Section {
                Button(action: {
                    PageLogger.shared.printStatistics()
                }) {
                    Label("打印统计信息", systemImage: "chart.bar.fill")
                }

                Button(role: .destructive) {
                    PageLogger.shared.clearLogs()
                    refreshLogs()
                } label: {
                    Label("清除所有日志", systemImage: "trash.fill")
                }
            }

            Section(header: Text("访问记录 (\(logs.count))")) {
                if logs.isEmpty {
                    Text("暂无日志记录")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(log.pageName)
                                    .font(.headline)
                                Spacer()
                                Text("#\(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Label(formatTime(log.enterTime), systemImage: "arrow.right.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)

                                if let exitTime = log.exitTime {
                                    Label(formatTime(exitTime), systemImage: "arrow.left.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            if let duration = log.duration {
                                Label(String(format: "停留 %.2f 秒", duration), systemImage: "clock.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }

                            if !log.parameters.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("参数:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    ForEach(Array(log.parameters.keys.sorted()), id: \.self) { key in
                                        Text("  • \(key): \(log.parameters[key] ?? "")")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("页面访问日志")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshLogs()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshLogs) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private func refreshLogs() {
        logs = PageLogger.shared.getAllLogs()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        PageLogView()
    }
}
