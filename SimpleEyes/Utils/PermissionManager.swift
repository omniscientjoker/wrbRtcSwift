//
//  PermissionManager.swift
//  SimpleEyes
//
//  权限管理服务
//  提供麦克风和摄像头权限的统一管理和请求接口
//

import Foundation
import AVFoundation
import UIKit

/// 权限管理器
///
/// 单例模式管理应用的音视频权限
/// 主要功能：
/// - 请求麦克风权限
/// - 请求摄像头权限
/// - 检查权限状态
/// - 显示权限拒绝提示
/// - 引导用户到系统设置
///
/// 使用示例：
/// ```swift
/// PermissionManager.shared.requestMicrophonePermission { granted in
///     if granted {
///         // 开始录音
///     }
/// }
/// ```
class PermissionManager {

    // MARK: - 单例

    /// 共享实例
    static let shared = PermissionManager()

    /// 私有初始化方法
    ///
    /// 防止外部创建实例，确保单例模式
    private init() {}

    // MARK: - 麦克风权限

    /// 请求麦克风权限
    ///
    /// 根据当前权限状态执行不同操作：
    /// - 已授权：直接返回成功
    /// - 未决定：弹出系统权限请求
    /// - 已拒绝：显示引导提示
    ///
    /// - Parameter completion: 权限结果回调，true 表示已授权
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
    ///
    /// 同步检查当前麦克风权限状态
    /// - Returns: true 表示已授权，false 表示未授权或被拒绝
    func checkMicrophonePermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    // MARK: - 摄像头权限

    /// 请求摄像头权限
    ///
    /// 根据当前权限状态执行不同操作：
    /// - 已授权：直接返回成功
    /// - 未决定：弹出系统权限请求
    /// - 已拒绝：显示引导提示
    ///
    /// - Parameter completion: 权限结果回调，true 表示已授权
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
    ///
    /// 同步检查当前摄像头权限状态
    /// - Returns: true 表示已授权，false 表示未授权或被拒绝
    func checkCameraPermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    // MARK: - 组合权限

    /// 请求音视频权限
    ///
    /// 按顺序请求麦克风和摄像头权限
    /// 适用于视频通话等需要同时使用音视频的场景
    ///
    /// - Parameter completion: 权限结果回调
    ///   - micGranted: 麦克风权限是否已授权
    ///   - cameraGranted: 摄像头权限是否已授权
    func requestAVPermissions(completion: @escaping (Bool, Bool) -> Void) {
        requestMicrophonePermission { micGranted in
            self.requestCameraPermission { cameraGranted in
                completion(micGranted, cameraGranted)
            }
        }
    }

    // MARK: - 权限提示

    /// 显示权限拒绝提示
    ///
    /// 当用户拒绝权限时，显示引导提示框
    /// 提供"去设置"按钮，引导用户到系统设置页面
    ///
    /// - Parameter permission: 权限类型名称（如"麦克风"、"摄像头"）
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
