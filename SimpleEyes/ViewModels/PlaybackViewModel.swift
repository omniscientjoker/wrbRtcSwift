//
//  PlaybackViewModel.swift
//  SimpleEyes
//
//  视频回放 ViewModel
//

import Foundation
import Combine

@MainActor
class PlaybackViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var deviceIdInput: String = ""
    @Published var selectedDate: Date = Date()
    @Published var recordings: [Recording] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let apiClient: APIClient
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Initialization

    init(deviceId: String = "", apiClient: APIClient = .shared) {
        self.deviceIdInput = deviceId
        self.apiClient = apiClient
    }

    // MARK: - Computed Properties

    var canQuery: Bool {
        !deviceIdInput.isEmpty && !isLoading
    }

    // MARK: - Public Methods

    func loadRecordings() {
        guard canQuery else { return }

        isLoading = true
        errorMessage = nil

        let dateString = dateFormatter.string(from: selectedDate)

        apiClient.getPlaybackList(deviceId: deviceIdInput, date: dateString) { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                self.isLoading = false

                switch result {
                case .success(let response):
                    self.recordings = response.recordings
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.recordings = []
                }
            }
        }
    }

    func playRecording(_ recording: Recording) {
        // TODO: 实现录像播放
        print("Play recording: \(recording.url)")
    }
}
