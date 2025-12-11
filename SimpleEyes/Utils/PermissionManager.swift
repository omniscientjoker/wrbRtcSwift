//
//  PermissionManager.swift
//  SimpleEyes
//
//  权限管理服务 - 麦克风和摄像头权限
//

import Foundation
import AVFoundation
import UIKit

/// 权限管理器
class PermissionManager {

    static let shared = PermissionManager()

    private init() {}

    // MARK: - Microphone Permission

    /// 请求麦克风权限
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            completion(true)

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }

        case .denied, .restricted:
            completion(false)
            showPermissionAlert(for: "麦克风")

        @unknown default:
            completion(false)
        }
    }

    /// 检查麦克风权限
    func checkMicrophonePermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    // MARK: - Camera Permission

    /// 请求摄像头权限
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            completion(true)

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }

        case .denied, .restricted:
            completion(false)
            showPermissionAlert(for: "摄像头")

        @unknown default:
            completion(false)
        }
    }

    /// 检查摄像头权限
    func checkCameraPermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    // MARK: - Combined Permissions

    /// 请求音视频权限
    func requestAVPermissions(completion: @escaping (Bool, Bool) -> Void) {
        requestMicrophonePermission { micGranted in
            self.requestCameraPermission { cameraGranted in
                completion(micGranted, cameraGranted)
            }
        }
    }

    // MARK: - Alert

    private func showPermissionAlert(for permission: String) {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first,
                  let rootViewController = window.rootViewController else {
                return
            }

            let alert = UIAlertController(
                title: "\(permission)权限被拒绝",
                message: "请在设置中允许访问\(permission)以使用此功能",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })

            rootViewController.present(alert, animated: true)
        }
    }
}
