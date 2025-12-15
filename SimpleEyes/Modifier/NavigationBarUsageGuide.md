# 导航栏统一配置使用指南

## 📋 概述

本项目采用统一的导航栏配置方案，避免重复配置和全局污染问题。

---

## 🎯 核心组件

### 1. NavigationBarConfig（全局配置）
位置：`SimpleEyes/Config/NavigationBarConfig.swift`

**功能**：提供全局导航栏主题配置

**预设主题**：
- `defaultTheme` - 蓝色主题（默认）
- `lightTheme` - 浅色主题
- `darkTheme` - 深色主题
- `transparentTheme` - 透明主题

### 2. UnifiedNavigationBarModifier（统一 Modifier）
位置：`SimpleEyes/viewModifier/UnifiedNavigationBarModifier.swift`

**功能**：统一的导航栏配置 Modifier

---

## 🚀 使用方法

### 方式1：使用全局主题（推荐）⭐

在 App 启动时已配置全局主题，视图只需设置标题即可：

```swift
struct MyView: View {
    var body: some View {
        VStack {
            Text("内容")
        }
        .navigationBar(title: "我的页面")  // ✅ 最简单
    }
}
```

### 方式2：使用预设主题

为特定页面使用不同的主题：

```swift
struct SettingsView: View {
    var body: some View {
        Form {
            // 设置内容
        }
        .navigationBar(
            title: "设置",
            theme: .lightTheme  // 使用浅色主题
        )
    }
}
```

### 方式3：自定义主题

为特定页面创建自定义主题：

```swift
struct SpecialView: View {
    var body: some View {
        VStack {
            Text("特殊页面")
        }
        .navigationBar(
            title: "特殊页面",
            theme: NavigationBarTheme(
                backgroundColor: .systemTeal,
                titleColor: .white,
                tintColor: .white
            )
        )
    }
}
```

### 方式4：完整配置（带页面追踪）

```swift
struct DeviceListView: View {
    var body: some View {
        List {
            // 设备列表
        }
        .navigationBar(
            title: "设备列表",
            displayMode: .large,
            theme: .defaultTheme,
            enableTracking: true,
            trackingParameters: [
                "from": "main_tab",
                "deviceCount": 10
            ]
        )
    }
}
```

---

## ⚠️ 注意事项

### ❌ 不要这样做

```swift
// ❌ 错误1：重复配置
.navigationTitle("标题")
.navigationBarTitleDisplayMode(.inline)
.navigationBar(title: "标题")  // 重复了！

// ❌ 错误2：混用旧API
.basePage(title: "标题")  // 已废弃
.navigationBar(title: "标题")

// ❌ 错误3：直接修改 UINavigationBar.appearance()
UINavigationBar.appearance().tintColor = .red  // 会影响全局！
```

### ✅ 应该这样做

```swift
// ✅ 正确1：只使用统一API
.navigationBar(title: "标题")

// ✅ 正确2：需要特殊主题时指定
.navigationBar(
    title: "标题",
    theme: .lightTheme
)

// ✅ 正确3：需要大标题时指定
.navigationBar(
    title: "标题",
    displayMode: .large
)
```

---

## 📝 常见场景

### 场景1：普通页面

```swift
struct NormalView: View {
    var body: some View {
        VStack {
            Text("普通内容")
        }
        .navigationBar(title: "普通页面")
    }
}
```

### 场景2：设置页面（Form）

```swift
struct SettingsView: View {
    var body: some View {
        Form {
            Section("服务器配置") {
                // 设置项
            }
        }
        .navigationBar(
            title: "设置",
            theme: .lightTheme  // 浅色主题更适合 Form
        )
    }
}
```

### 场景3：列表页面（大标题）

```swift
struct DeviceListView: View {
    var body: some View {
        List {
            ForEach(devices) { device in
                Text(device.name)
            }
        }
        .navigationBar(
            title: "设备列表",
            displayMode: .large  // 大标题
        )
    }
}
```

### 场景4：透明导航栏（图片背景）

```swift
struct ImageBackgroundView: View {
    var body: some View {
        ZStack {
            Image("background")
                .resizable()
                .ignoresSafeArea()

            VStack {
                Text("内容")
            }
        }
        .navigationBar(
            title: "图片页面",
            theme: .transparentTheme  // 透明导航栏
        )
    }
}
```

---

## 🔧 修改全局主题

### 在 SimpleEyesApp.swift 中修改：

```swift
@main
struct SimpleEyesApp: App {
    init() {
        setupNavigationBar()
    }

    private func setupNavigationBar() {
        // 方式1：使用预设主题
        NavigationBarConfig.setupGlobalAppearance(theme: .defaultTheme)

        // 方式2：使用自定义主题
        // let customTheme = NavigationBarTheme(
        //     backgroundColor: UIColor(hex: "#3498db")!,  // 自定义颜色
        //     titleColor: .white,
        //     tintColor: .white
        // )
        // NavigationBarConfig.setupGlobalAppearance(theme: customTheme)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

## 🎨 自定义颜色

### 使用十六进制颜色：

```swift
let customTheme = NavigationBarTheme(
    backgroundColor: UIColor(hex: "#3498db")!,  // 蓝色
    titleColor: UIColor(hex: "#FFFFFF")!,       // 白色
    tintColor: UIColor(hex: "#FFFFFF")!          // 白色
)

.navigationBar(title: "自定义颜色", theme: customTheme)
```

### 使用系统颜色：

```swift
let systemTheme = NavigationBarTheme(
    backgroundColor: .systemIndigo,   // 系统靛蓝色
    titleColor: .white,
    tintColor: .white
)
```

---

## 📊 迁移指南

### 从旧 API 迁移到新 API

#### 旧代码（basePage）：
```swift
.basePage(
    title: "视频通话",
    displayMode: .inline,
    parameters: ["from": "tab"],
    enableTracking: true,
    backgroundColor: .systemBlue,
    titleColor: .white,
    tintColor: .white
)
```

#### 新代码（navigationBar）：
```swift
.navigationBar(
    title: "视频通话",
    displayMode: .inline,
    trackingParameters: ["from": "tab"]
    // 主题使用全局配置，无需每次指定
)
```

### 简化后（推荐）：
```swift
.navigationBar(title: "视频通话")
```

---

## 🧪 测试清单

在修改导航栏配置后，请测试以下场景：

- [ ] 导航栏背景色正确
- [ ] 导航栏标题颜色正确
- [ ] 导航栏按钮颜色正确
- [ ] 导航栏在滚动时正确显示
- [ ] 导航栏在暗黑模式下正确显示
- [ ] Push 到新页面时导航栏过渡流畅
- [ ] Present 模态页面时导航栏正确显示
- [ ] 页面追踪功能正常工作

---

## 💡 最佳实践

1. **优先使用全局主题**：除非有特殊需求，使用全局主题即可
2. **保持一致性**：同类型页面使用相同主题
3. **避免重复配置**：不要同时使用 `.navigationTitle()` 和 `.navigationBar()`
4. **测试暗黑模式**：确保暗黑模式下显示正常
5. **合理使用页面追踪**：为重要页面启用追踪

---

## 🆘 常见问题

### Q1: 导航栏颜色没有变化？

**A**: 检查是否在其他地方设置了 `UINavigationBar.appearance()`，这会覆盖配置。

### Q2: 页面追踪不工作？

**A**: 确保 `PageLogger` 和 `PageTrackingModifier` 正确引入，并且 `enableTracking` 为 `true`。

### Q3: 不同页面导航栏颜色不一致？

**A**: 使用统一的 `.navigationBar()` API，并确保全局主题已正确配置。

### Q4: 暗黑模式下导航栏显示异常？

**A**: 使用系统颜色（如 `.systemBackground`、`.label`）而非固定颜色。

---

## 📚 相关文件

- `SimpleEyesApp.swift` - App 入口，全局配置
- `NavigationBarConfig.swift` - 主题配置
- `UnifiedNavigationBarModifier.swift` - 统一 Modifier
- `PageTrackingModifier.swift` - 页面追踪

---

**最后更新**：2024-12-14
**维护者**：SimpleEyes 开发团队
