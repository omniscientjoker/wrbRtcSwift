//
//  LiveVideoViewModel.swift
//  SimpleEyes
//
//  视频直播 ViewModel
//

import Foundation
import Combine

@MainActor
class LiveVideoViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var deviceIdInput: String = ""
    @Published var streamUrl: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let apiClient: APIClient

    // MARK: - Initialization

    init(deviceId: String = "", apiClient: APIClient = .shared) {
        self.deviceIdInput = deviceId
        self.apiClient = apiClient
    }

    // MARK: - Computed Properties

    var canStartLive: Bool {
        !deviceIdInput.isEmpty && !isLoading
    }

    // MARK: - Public Methods

    func startLiveStream() {
        guard canStartLive else { return }

        isLoading = true
        errorMessage = nil

        apiClient.getLiveStream(deviceId: deviceIdInput) { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                self.isLoading = false

                switch result {
                case .success(let response):
                    self.streamUrl = response.url
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopStream() {
        streamUrl = nil
        errorMessage = nil
    }
}
