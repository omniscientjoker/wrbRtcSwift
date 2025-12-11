//
//  SettingsViewModel.swift
//  SimpleEyes
//
//  设置 ViewModel
//

import Foundation
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var apiServerURL: String {
        didSet {
            UserDefaults.standard.set(apiServerURL, forKey: "apiServerURL")
        }
    }

    @Published var wsServerURL: String {
        didSet {
            UserDefaults.standard.set(wsServerURL, forKey: "wsServerURL")
        }
    }

    @Published var showingSaveAlert = false
    @Published var showingResetAlert = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        self.apiServerURL = UserDefaults.standard.string(forKey: "apiServerURL") ?? APIConfig.baseURL
        self.wsServerURL = UserDefaults.standard.string(forKey: "wsServerURL") ?? APIConfig.wsURL
    }

    // MARK: - Computed Properties

    var hasChanges: Bool {
        apiServerURL != APIConfig.baseURL || wsServerURL != APIConfig.wsURL
    }

    // MARK: - Public Methods

    func saveSettings() {
        // 设置已自动保存通过 didSet
        showingSaveAlert = true
    }

    func resetToDefaults() {
        apiServerURL = APIConfig.baseURL
        wsServerURL = APIConfig.wsURL
    }

    func requestReset() {
        showingResetAlert = true
    }
}
