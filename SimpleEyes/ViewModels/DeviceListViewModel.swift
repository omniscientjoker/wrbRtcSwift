//
//  DeviceListViewModel.swift
//  SimpleEyes
//
//  设备列表 ViewModel
//

import Foundation
import Combine

@MainActor
class DeviceListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var devices: [Device] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let apiClient: APIClient

    // MARK: - Initialization

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Public Methods

    func loadDevices() {
        isLoading = true
        errorMessage = nil

        apiClient.getDeviceList { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                self.isLoading = false

                switch result {
                case .success(let response):
                    self.devices = response.devices
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func refresh() {
        loadDevices()
    }
}
