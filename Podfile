# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'SimpleEyes' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Video Player
  pod 'MobileVLCKit', '~> 3.3.0'

  # WebSocket
  pod 'Starscream', '~> 4.0'

  # Network
  pod 'Alamofire', '~> 5.8'

  # JSON parsing
  pod 'SwiftyJSON', '~> 5.0'

  # WebRTC (使用官方维护的版本)
  pod 'WebRTC-SDK', '~> 114.0'

  # Lottie Animation
  pod 'lottie-ios', '~> 4.3'

end

# 统一设置所有 Pod 的部署目标
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
