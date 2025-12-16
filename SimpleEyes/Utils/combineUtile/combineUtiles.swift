//
//  combineUtiles.swift
//  SimpleEyes
//
//  Created by 姜淼 on 2025/12/16.
//
//  说明：本文件提供了一系列用于文本输入处理的 Combine 扩展方法
//  主要用于处理 TextField、TextEditor 等输入组件的实时文本验证和格式化
//

import Foundation
import SwiftUI
import Combine

// MARK: - Publisher 文本处理扩展
/// 为 Publisher<String, Never> 类型扩展文本处理方法
/// 这些方法可以直接应用于 @Published 属性，实现响应式的文本处理
///
/// 注意：
/// - 本扩展提供了常用的文本处理方法
/// - Combine 原生的方法（如 removeDuplicates()）可以直接使用，无需额外封装
/// - 所有方法都支持链式调用
extension Publisher where Output == String, Failure == Never {

    // MARK: - 空格处理方法

    /// 去除首尾空格和换行符
    ///
    /// 功能说明：
    /// - 只处理文本开头和结尾的空白字符
    /// - 保留文本中间的空格
    ///
    /// 实现步骤：
    /// 1. 使用 map 操作符转换每个输入值
    /// 2. 调用 String 的 trimmingCharacters(in:) 方法
    /// 3. 传入 .whitespacesAndNewlines 字符集（包括空格、制表符、换行符等）
    /// 4. 将结果包装为 AnyPublisher 类型返回
    ///
    /// 使用场景：
    /// - 用户名输入框（允许中间有空格，但不允许首尾有空格）
    /// - 搜索框（去除意外输入的首尾空格）
    ///
    /// - Returns: 返回处理后的 Publisher，输出去除首尾空格后的字符串
    ///
    /// 示例：
    /// ```swift
    /// $username
    ///     .trimWhitespace()
    ///     .assign(to: &$processedUsername)
    /// // 输入: "  张三  " -> 输出: "张三"
    /// // 输入: "张 三" -> 输出: "张 三"
    /// ```
    func trimWhitespace() -> AnyPublisher<String, Never> {
        map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .eraseToAnyPublisher()
    }

    /// 去除所有空格（不包括换行符）
    ///
    /// 功能说明：
    /// - 移除文本中所有的空格字符
    /// - 保留换行符和其他空白字符
    ///
    /// 实现步骤：
    /// 1. 使用 map 操作符
    /// 2. 调用 replacingOccurrences(of:with:) 方法
    /// 3. 将所有空格替换为空字符串
    /// 4. 返回 AnyPublisher 类型
    ///
    /// 使用场景：
    /// - 手机号输入（11位连续数字）
    /// - 身份证号输入
    /// - 验证码输入
    ///
    /// - Returns: 返回处理后的 Publisher，输出不含空格的字符串
    ///
    /// 示例：
    /// ```swift
    /// $phoneNumber
    ///     .removeAllSpaces()
    ///     .assign(to: &$processedPhone)
    /// // 输入: "138 0013 8000" -> 输出: "13800138000"
    /// ```
    func removeAllSpaces() -> AnyPublisher<String, Never> {
        map { $0.replacingOccurrences(of: " ", with: "") }
            .eraseToAnyPublisher()
    }

    /// 去除所有空格和换行符
    ///
    /// 功能说明：
    /// - 移除所有类型的空白字符
    /// - 包括空格、制表符、换行符等
    ///
    /// 实现步骤：
    /// 1. 使用 components(separatedBy:) 按空白字符分割字符串
    /// 2. 传入 .whitespacesAndNewlines 字符集作为分隔符
    /// 3. 使用 joined() 将分割后的部分重新连接
    /// 4. 返回 AnyPublisher 类型
    ///
    /// 使用场景：
    /// - 密码输入框（不允许任何空白字符）
    /// - 用户名输入（单个连续字符串）
    ///
    /// - Returns: 返回处理后的 Publisher，输出不含任何空白字符的字符串
    ///
    /// 示例：
    /// ```swift
    /// $password
    ///     .removeWhitespacesAndNewlines()
    ///     .assign(to: &$processedPassword)
    /// // 输入: "abc 123\n456" -> 输出: "abc123456"
    /// ```
    func removeWhitespacesAndNewlines() -> AnyPublisher<String, Never> {
        map { $0.components(separatedBy: .whitespacesAndNewlines).joined() }
            .eraseToAnyPublisher()
    }

    // MARK: - 字符过滤方法

    /// 去除特殊字符，只保留字母、数字和中文
    ///
    /// 功能说明：
    /// - 使用正则表达式过滤特殊字符
    /// - 保留英文字母（大小写）、数字和中文字符
    /// - 移除标点符号、表情符号等
    ///
    /// 实现步骤：
    /// 1. 定义正则表达式模式 "[^a-zA-Z0-9\\u4e00-\\u9fa5]"
    ///    - ^ 表示取反（匹配不在集合中的字符）
    ///    - a-zA-Z 匹配所有英文字母
    ///    - 0-9 匹配所有数字
    ///    - \\u4e00-\\u9fa5 匹配中文字符的 Unicode 范围
    /// 2. 使用 replacingOccurrences 替换匹配的字符为空
    /// 3. 设置 options: .regularExpression 启用正则表达式
    /// 4. 返回处理后的字符串
    ///
    /// 使用场景：
    /// - 用户昵称输入
    /// - 地址信息输入
    /// - 搜索关键词
    ///
    /// - Returns: 返回处理后的 Publisher，输出只包含字母、数字和中文的字符串
    ///
    /// 示例：
    /// ```swift
    /// $nickname
    ///     .removeSpecialCharacters()
    ///     .assign(to: &$processedNickname)
    /// // 输入: "张三@123!" -> 输出: "张三123"
    /// // 输入: "Hello世界😊" -> 输出: "Hello世界"
    /// ```
    func removeSpecialCharacters() -> AnyPublisher<String, Never> {
        map { text in
            // 定义正则模式：保留字母、数字、中文，移除其他所有字符
            let pattern = "[^a-zA-Z0-9\\u4e00-\\u9fa5]"
            return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        .eraseToAnyPublisher()
    }

    /// 只保留指定的字符集
    ///
    /// 功能说明：
    /// - 根据传入的字符集过滤文本
    /// - 只保留字符集中定义的字符
    /// - 移除所有其他字符
    ///
    /// 实现步骤：
    /// 1. 将字符串转换为 unicodeScalars（Unicode 标量序列）
    /// 2. 使用 filter 过滤每个字符
    /// 3. 检查字符是否在指定的 characterSet 中
    /// 4. 将过滤后的字符重新组合成字符串
    /// 5. 返回 AnyPublisher 类型
    ///
    /// 参数说明：
    /// - characterSet: CharacterSet 类型，定义允许保留的字符集合
    ///   常用字符集：
    ///   - .alphanumerics: 字母和数字
    ///   - .decimalDigits: 十进制数字（0-9）
    ///   - .letters: 所有字母
    ///   - .lowercaseLetters: 小写字母
    ///   - .uppercaseLetters: 大写字母
    ///
    /// 使用场景：
    /// - 自定义字符过滤规则
    /// - 特殊格式的输入验证
    ///
    /// - Returns: 返回处理后的 Publisher，输出只包含指定字符集的字符串
    ///
    /// 示例：
    /// ```swift
    /// $input
    ///     .keepOnly(characterSet: .letters)
    ///     .assign(to: &$lettersOnly)
    /// // 输入: "abc123!@#" -> 输出: "abc"
    /// ```
    func keepOnly(characterSet: CharacterSet) -> AnyPublisher<String, Never> {
        map { text in
            // 遍历 Unicode 标量，只保留在字符集中的字符
            String(text.unicodeScalars.filter { characterSet.contains($0) })
        }
        .eraseToAnyPublisher()
    }

    /// 只保留字母和数字
    ///
    /// 功能说明：
    /// - 封装 keepOnly 方法的便捷版本
    /// - 只保留英文字母（大小写）和数字
    ///
    /// 实现步骤：
    /// 1. 调用 keepOnly(characterSet:) 方法
    /// 2. 传入预定义的 .alphanumerics 字符集
    ///
    /// 使用场景：
    /// - 用户名输入（只允许字母和数字）
    /// - 产品编号输入
    ///
    /// - Returns: 返回处理后的 Publisher，输出只包含字母和数字的字符串
    ///
    /// 示例：
    /// ```swift
    /// $username
    ///     .alphanumericOnly()
    ///     .assign(to: &$validUsername)
    /// // 输入: "user@123!" -> 输出: "user123"
    /// ```
    func alphanumericOnly() -> AnyPublisher<String, Never> {
        keepOnly(characterSet: .alphanumerics)
    }

    /// 只保留数字
    ///
    /// 功能说明：
    /// - 封装 keepOnly 方法的便捷版本
    /// - 只保留 0-9 的数字字符
    ///
    /// 实现步骤：
    /// 1. 调用 keepOnly(characterSet:) 方法
    /// 2. 传入预定义的 .decimalDigits 字符集
    ///
    /// 使用场景：
    /// - 手机号输入
    /// - 验证码输入
    /// - 金额输入（配合其他验证）
    ///
    /// - Returns: 返回处理后的 Publisher，输出只包含数字的字符串
    ///
    /// 示例：
    /// ```swift
    /// $verificationCode
    ///     .numbersOnly()
    ///     .limitLength(to: 6)
    ///     .assign(to: &$code)
    /// // 输入: "12a34b56" -> 输出: "123456"
    /// ```
    func numbersOnly() -> AnyPublisher<String, Never> {
        keepOnly(characterSet: .decimalDigits)
    }

    // MARK: - 长度限制方法

    /// 限制文本长度
    ///
    /// 功能说明：
    /// - 当文本超过指定长度时自动截断
    /// - 保留前 maxLength 个字符
    ///
    /// 实现步骤：
    /// 1. 使用 map 操作符处理输入文本
    /// 2. 检查文本长度是否超过 maxLength
    /// 3. 如果超过，使用 prefix(maxLength) 截取前面的字符
    /// 4. 如果未超过，返回原文本
    /// 5. 返回 AnyPublisher 类型
    ///
    /// 参数说明：
    /// - maxLength: Int 类型，允许的最大字符数
    ///   - 必须是正整数
    ///   - 如果设为 0，将返回空字符串
    ///   - 建议根据实际业务需求设置合理值
    ///
    /// 使用场景：
    /// - 昵称限制（如 20 个字符）
    /// - 简介限制（如 200 个字符）
    /// - 标题限制（如 50 个字符）
    ///
    /// - Returns: 返回处理后的 Publisher，输出长度不超过指定值的字符串
    ///
    /// 注意事项：
    /// - 使用 count 计算字符数，emoji 算一个字符
    /// - 如果需要按字节限制，需要使用其他方法
    ///
    /// 示例：
    /// ```swift
    /// $nickname
    ///     .limitLength(to: 20)
    ///     .assign(to: &$validNickname)
    /// // 输入: "这是一个很长很长很长很长的昵称" -> 输出: "这是一个很长很长很长很长的昵"（20字符）
    /// ```
    func limitLength(to maxLength: Int) -> AnyPublisher<String, Never> {
        map { text in
            // 检查长度并截断
            if text.count > maxLength {
                return String(text.prefix(maxLength))
            }
            return text
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 综合处理方法

    /// 综合文本验证器：去除空格、特殊字符并限制长度
    ///
    /// 功能说明：
    /// - 一站式文本处理方法
    /// - 按顺序执行：空格处理 -> 字符过滤 -> 长度限制
    /// - 所有参数都可自定义
    ///
    /// 实现步骤：
    /// 1. 首先处理空格（根据参数选择处理方式）
    ///    - 如果 removeAllSpaces = true: 移除所有空格
    ///    - 否则如果 trimSpaces = true: 只去除首尾空格
    /// 2. 然后过滤特殊字符
    ///    - 创建正则表达式对象
    ///    - 使用 allowedPattern 匹配允许的字符
    ///    - 提取所有匹配的字符并拼接
    /// 3. 最后限制长度
    ///    - 检查字符串长度
    ///    - 如果超长则截断
    /// 4. 返回处理后的字符串
    ///
    /// 参数详解：
    /// - maxLength: Int
    ///   - 允许的最大字符数
    ///   - 必填参数，需要明确指定
    ///
    /// - trimSpaces: Bool (默认: true)
    ///   - 是否去除首尾空格和换行符
    ///   - true: 去除首尾空白字符
    ///   - false: 不处理空格
    ///   - 注意：如果 removeAllSpaces = true，此参数无效
    ///
    /// - removeAllSpaces: Bool (默认: false)
    ///   - 是否去除所有空格
    ///   - true: 移除文本中所有空格
    ///   - false: 根据 trimSpaces 参数决定
    ///   - 优先级高于 trimSpaces
    ///
    /// - allowedPattern: String (默认: "[a-zA-Z0-9\\u4e00-\\u9fa5]")
    ///   - 正则表达式，定义允许保留的字符
    ///   - 默认值保留：字母、数字、中文
    ///   - 可自定义，例如：
    ///     - "[0-9]": 只允许数字
    ///     - "[a-zA-Z]": 只允许字母
    ///     - "[a-zA-Z0-9@.]": 允许字母、数字、@和.（邮箱）
    ///
    /// 使用场景：
    /// - 用户名输入：允许字母数字，长度 6-20
    /// - 昵称输入：允许中文字母数字，长度 2-15
    /// - 备注信息：允许中文字母数字和常用标点
    ///
    /// - Returns: 返回处理后的 Publisher，输出经过完整验证的字符串
    ///
    /// 示例：
    /// ```swift
    /// // 示例1: 用户名验证（只允许字母数字，最长20位）
    /// $username
    ///     .textFieldValidator(
    ///         maxLength: 20,
    ///         removeAllSpaces: true,
    ///         allowedPattern: "[a-zA-Z0-9]"
    ///     )
    ///     .assign(to: &$validUsername)
    /// // 输入: "user @123!" -> 输出: "user123"
    ///
    /// // 示例2: 昵称验证（允许中文字母数字，最长15位）
    /// $nickname
    ///     .textFieldValidator(
    ///         maxLength: 15,
    ///         trimSpaces: true,
    ///         allowedPattern: "[a-zA-Z0-9\\u4e00-\\u9fa5]"
    ///     )
    ///     .assign(to: &$validNickname)
    /// // 输入: "  张三ABC  " -> 输出: "张三ABC"
    ///
    /// // 示例3: 邮箱前缀验证
    /// $emailPrefix
    ///     .textFieldValidator(
    ///         maxLength: 30,
    ///         removeAllSpaces: true,
    ///         allowedPattern: "[a-zA-Z0-9._-]"
    ///     )
    ///     .assign(to: &$validEmailPrefix)
    /// ```
    func textFieldValidator(
        maxLength: Int,
        trimSpaces: Bool = true,
        removeAllSpaces: Bool = false,
        allowedPattern: String = "[a-zA-Z0-9\\u4e00-\\u9fa5]"
    ) -> AnyPublisher<String, Never> {
        map { text in
            var result = text

            // 步骤1: 处理空格
            if removeAllSpaces {
                // 移除所有空格
                result = result.replacingOccurrences(of: " ", with: "")
            } else if trimSpaces {
                // 只去除首尾空格
                result = result.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // 步骤2: 过滤特殊字符（使用正则表达式）
            let pattern = allowedPattern
            if let regex = try? NSRegularExpression(pattern: pattern) {
                // 查找所有匹配的字符
                let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
                // 提取匹配的字符并拼接
                result = matches.map { match in
                    String(result[Range(match.range, in: result)!])
                }.joined()
            }

            // 步骤3: 限制长度
            if result.count > maxLength {
                result = String(result.prefix(maxLength))
            }

            return result
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 性能优化方法

    /// 防抖动处理（Debounce）
    ///
    /// 功能说明：
    /// - 延迟处理用户输入，避免频繁触发
    /// - 只有在用户停止输入一段时间后才发送值
    /// - 减少不必要的 API 调用和计算
    ///
    /// 实现步骤：
    /// 1. 使用 Combine 的 debounce 操作符
    /// 2. 设置延迟时间（interval 参数）
    /// 3. 指定调度器为 RunLoop.main（主线程）
    /// 4. 返回 AnyPublisher 类型
    ///
    /// 工作原理：
    /// - 每次收到新值时重置计时器
    /// - 只有在 interval 时间内没有新值时才发送最后一个值
    /// - 例如：设置 0.3 秒，用户快速输入"hello"，只在输完后 0.3 秒发送"hello"
    ///
    /// 参数说明：
    /// - interval: TimeInterval 类型（默认: 0.3）
    ///   - 延迟时间，单位：秒
    ///   - 建议值：
    ///     - 搜索框: 0.3-0.5 秒
    ///     - 实时验证: 0.5-1.0 秒
    ///     - API 调用: 0.5-1.0 秒
    ///
    /// 使用场景：
    /// - 搜索框实时搜索（避免每次按键都发送请求）
    /// - 用户名唯一性检查（延迟发送 API 请求）
    /// - 表单验证（用户输入完成后再验证）
    ///
    /// - Returns: 返回防抖后的 Publisher
    ///
    /// 示例：
    /// ```swift
    /// // 搜索框示例
    /// $searchText
    ///     .debounceTextField(for: 0.5)
    ///     .sink { searchKeyword in
    ///         // 只在用户停止输入 0.5 秒后才执行搜索
    ///         self.performSearch(keyword: searchKeyword)
    ///     }
    ///     .store(in: &cancellables)
    ///
    /// // 用户名检查示例
    /// $username
    ///     .debounceTextField(for: 0.8)
    ///     .sink { username in
    ///         // 停止输入 0.8 秒后检查用户名是否可用
    ///         self.checkUsernameAvailability(username)
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    func debounceTextField(for interval: TimeInterval = 0.3) -> AnyPublisher<String, Never> {
        debounce(for: .seconds(interval), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }

}

// MARK: - 使用示例 ViewModel
/// 演示如何在实际项目中使用文本处理扩展方法的示例 ViewModel
/// 这个类展示了多种常见的使用场景和最佳实践
class TextFieldViewModel: ObservableObject {

    // MARK: - Published 属性

    /// 原始输入文本（用户在 TextField 中输入的内容）
    @Published var inputText = ""

    /// 处理后的文本（经过验证和格式化的结果）
    @Published var processedText = ""

    // MARK: - Private 属性

    /// Combine 订阅集合，用于管理所有订阅的生命周期
    /// 当 ViewModel 被释放时，所有订阅会自动取消
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init() {
        setupTextProcessing()
    }

    // MARK: - 文本处理设置

    /// 配置文本处理管道
    /// 注意：以下示例展示了多种用法，实际使用时只需要选择一种合适的方案
    private func setupTextProcessing() {

        // ========== 示例1: 简单去除空格和限制长度 ==========
        //
        // 使用场景：
        // - 手机号输入框（去除空格，限制11位）
        // - 身份证号输入（去除空格，限制18位）
        //
        // 处理流程：
        // 1. 输入 "138 0013 8000"
        // 2. removeAllSpaces() -> "13800138000"
        // 3. limitLength(to: 20) -> "13800138000"（未超长，保持不变）
        //
        // 优点：
        // - 代码简洁，逻辑清晰
        // - 使用 assign(to:) 操作符自动更新属性
        // - 不需要手动管理订阅
        //
        // 注意事项：
        // - assign(to:) 会自动管理订阅生命周期
        // - 不需要使用 [weak self]，因为使用了 &$ 语法
        $inputText
            .removeAllSpaces()
            .limitLength(to: 20)
            .assign(to: &$processedText)

        // ========== 示例2: 综合处理（推荐使用） ==========
        //
        // 使用场景：
        // - 用户名输入（字母数字，6-20位）
        // - 昵称输入（中文字母数字，2-15位）
        //
        // 处理流程：
        // 1. 输入 "张三 @123!"
        // 2. textFieldValidator 内部执行：
        //    a. removeAllSpaces: true -> "张三@123!"
        //    b. 正则过滤（默认保留字母数字中文） -> "张三123"
        //    c. limitLength(to: 20) -> "张三123"（未超长）
        // 3. 通过 sink 传递给 processedText
        //
        // 优点：
        // - 一站式处理，所有验证逻辑集中在一个方法
        // - 参数可配置，适应不同场景
        // - 代码可读性强
        //
        // 注意事项：
        // - 使用 sink 时需要 [weak self] 避免循环引用
        // - 需要手动 store(in: &cancellables) 管理订阅
        $inputText
            .textFieldValidator(maxLength: 20, removeAllSpaces: true)
            .sink { [weak self] validated in
                // validated 是经过完整验证的字符串
                self?.processedText = validated

                // 可以在这里添加额外逻辑
                // 例如：实时显示字符数
                // print("当前字符数: \(validated.count)/20")
            }
            .store(in: &cancellables)

        // ========== 示例3: 只允许数字输入 ==========
        //
        // 使用场景：
        // - 验证码输入（6位数字）
        // - 金额输入（纯数字部分）
        // - 银行卡号输入
        //
        // 处理流程：
        // 1. 输入 "12a34b56c78"
        // 2. numbersOnly() -> "12345678"（只保留数字）
        // 3. limitLength(to: 10) -> "1234567890"（截断到10位）
        //
        // 优点：
        // - 专门针对数字输入优化
        // - 自动过滤所有非数字字符
        //
        // 实际应用示例：
        // ```swift
        // TextField("请输入验证码", text: $viewModel.inputText)
        //     .keyboardType(.numberPad)  // 配合数字键盘使用
        // ```
        $inputText
            .numbersOnly()
            .limitLength(to: 10)
            .sink { [weak self] validated in
                self?.processedText = validated

                // 可以添加格式化显示
                // 例如：银行卡号每4位加一个空格
                // let formatted = validated.chunked(into: 4).joined(separator: " ")
            }
            .store(in: &cancellables)

        // ========== 示例4: 链式调用多个方法（高级用法） ==========
        //
        // 使用场景：
        // - 搜索框（去除首尾空格、特殊字符，延迟搜索）
        // - 评论输入（多重验证，防抖）
        //
        // 处理流程：
        // 1. 输入 "  Hello 世界@!  "
        // 2. trimWhitespace() -> "Hello 世界@!"（去除首尾空格）
        // 3. removeSpecialCharacters() -> "Hello世界"（去除特殊字符）
        // 4. limitLength(to: 50) -> "Hello世界"（未超长）
        // 5. debounceTextField(for: 0.5) -> 等待0.5秒后才发送
        //
        // 优点：
        // - 灵活性强，可以自由组合多个方法
        // - 适合复杂的验证场景
        // - debounce 减少不必要的处理和网络请求
        //
        // 性能优化：
        // - debounce 避免用户每次输入都触发处理
        // - 适合需要调用 API 的场景（如实时搜索）
        //
        // 完整的搜索框示例：
        // ```swift
        // $searchText
        //     .trimWhitespace()           // 去除首尾空格
        //     .removeSpecialCharacters()  // 去除特殊字符
        //     .limitLength(to: 50)        // 限制最大长度
        //     .debounceTextField(for: 0.5) // 延迟0.5秒
        //     .removeDuplicates()         // 去重（避免重复搜索）
        //     .sink { keyword in
        //         self.performSearch(keyword: keyword)
        //     }
        //     .store(in: &cancellables)
        // ```
        $inputText
            .trimWhitespace()
            .removeSpecialCharacters()
            .limitLength(to: 50)
            .debounceTextField(for: 0.5)
            .sink { [weak self] validated in
                self?.processedText = validated
            }
            .store(in: &cancellables)
    }
}

// MARK: - 实际应用场景示例

/// 示例1: 用户注册表单 ViewModel
class UserRegistrationViewModel: ObservableObject {
    // 用户名：字母数字，6-20位
    @Published var username = ""
    @Published var validatedUsername = ""

    // 手机号：纯数字，11位
    @Published var phoneNumber = ""
    @Published var validatedPhone = ""

    // 昵称：中文字母数字，2-15位
    @Published var nickname = ""
    @Published var validatedNickname = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        // 用户名验证：只允许字母数字，6-20位
        $username
            .textFieldValidator(
                maxLength: 20,
                removeAllSpaces: true,
                allowedPattern: "[a-zA-Z0-9]"
            )
            .assign(to: &$validatedUsername)

        // 手机号验证：只允许数字，11位
        $phoneNumber
            .numbersOnly()
            .limitLength(to: 11)
            .assign(to: &$validatedPhone)

        // 昵称验证：允许中文字母数字，2-15位
        $nickname
            .textFieldValidator(
                maxLength: 15,
                trimSpaces: true,
                allowedPattern: "[a-zA-Z0-9\\u4e00-\\u9fa5]"
            )
            .assign(to: &$validatedNickname)
    }
}

/// 示例2: 搜索功能 ViewModel
class SearchViewModel: ObservableObject {
    @Published var searchKeyword = ""
    @Published var searchResults: [String] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // 搜索框文本处理：
        // 1. 去除首尾空格
        // 2. 限制长度
        // 3. 防抖（用户停止输入0.5秒后才搜索）
        // 4. 去重（避免重复搜索相同关键词）
        $searchKeyword
            .trimWhitespace()
            .limitLength(to: 50)
            .debounceTextField(for: 0.5)
            .removeDuplicates()
            .sink { [weak self] keyword in
                guard !keyword.isEmpty else {
                    self?.searchResults = []
                    return
                }
                self?.performSearch(keyword: keyword)
            }
            .store(in: &cancellables)
    }

    private func performSearch(keyword: String) {
        // 执行搜索逻辑
        print("搜索关键词: \(keyword)")
        // TODO: 调用搜索 API
    }
}

/// 示例3: 表单输入验证 ViewModel
class FormInputViewModel: ObservableObject {
    // 邮箱前缀输入
    @Published var emailPrefix = ""
    @Published var validatedEmailPrefix = ""

    // 验证码输入
    @Published var verificationCode = ""
    @Published var validatedCode = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        // 邮箱前缀：允许字母、数字、点、下划线、连字符
        $emailPrefix
            .textFieldValidator(
                maxLength: 30,
                removeAllSpaces: true,
                allowedPattern: "[a-zA-Z0-9._-]"
            )
            .assign(to: &$validatedEmailPrefix)

        // 验证码：6位数字
        $verificationCode
            .numbersOnly()
            .limitLength(to: 6)
            .assign(to: &$validatedCode)
    }
}

// MARK: - Combine 原生方法补充说明
/*
 除了上述自定义的扩展方法外，以下 Combine 原生方法也非常实用，可以直接使用：

 1. removeDuplicates()
    - 功能：过滤掉连续重复的值
    - 使用场景：避免重复触发相同的操作
    - 示例：
    ```swift
    $searchText
        .removeDuplicates()  // 只在值真正改变时才发送
        .debounceTextField(for: 0.3)
        .sink { keyword in
            self.performSearch(keyword: keyword)
        }
        .store(in: &cancellables)
    ```

 2. map()
    - 功能：转换 Publisher 的输出值
    - 使用场景：自定义文本转换逻辑
    - 示例：
    ```swift
    $text
        .map { $0.uppercased() }  // 转换为大写
        .assign(to: &$uppercasedText)
    ```

 3. filter()
    - 功能：根据条件过滤值
    - 使用场景：只处理符合条件的输入
    - 示例：
    ```swift
    $text
        .filter { !$0.isEmpty }  // 只处理非空文本
        .sink { text in
            self.process(text: text)
        }
        .store(in: &cancellables)
    ```

 4. debounce()
    - 功能：延迟发送值（防抖）
    - 使用场景：减少频繁触发的操作
    - 示例：
    ```swift
    $searchText
        .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
        .sink { keyword in
            self.search(keyword: keyword)
        }
        .store(in: &cancellables)
    ```
    注意：本文件已提供 debounceTextField() 方法作为便捷封装

 5. throttle()
    - 功能：限流（在指定时间内只发送第一个或最后一个值）
    - 使用场景：限制事件触发频率
    - 示例：
    ```swift
    $text
        .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
        .sink { text in
            self.updateUI(with: text)
        }
        .store(in: &cancellables)
    ```

 6. combineLatest()
    - 功能：组合多个 Publisher 的最新值
    - 使用场景：表单验证（需要多个字段都满足条件）
    - 示例：
    ```swift
    Publishers.CombineLatest($username, $password)
        .map { username, password in
            !username.isEmpty && password.count >= 6
        }
        .assign(to: &$isFormValid)
    ```

 7. compactMap()
    - 功能：转换并过滤掉 nil 值
    - 使用场景：处理可选值
    - 示例：
    ```swift
    $inputText
        .compactMap { Int($0) }  // 转换为整数，失败则跳过
        .sink { number in
            self.process(number: number)
        }
        .store(in: &cancellables)
    ```

 8. flatMap()
    - 功能：将 Publisher 的输出转换为新的 Publisher
    - 使用场景：异步操作、网络请求
    - 示例：
    ```swift
    $searchKeyword
        .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
        .flatMap { keyword in
            self.apiClient.search(keyword: keyword)
        }
        .sink { results in
            self.searchResults = results
        }
        .store(in: &cancellables)
    ```

 使用建议：
 - 优先使用本文件提供的封装方法（如 debounceTextField, numbersOnly 等）
 - 对于特殊需求，可以直接使用 Combine 原生方法
 - 可以将原生方法和封装方法链式组合使用
 - 复杂的逻辑建议使用 map/filter 等原生方法自定义处理
 */
