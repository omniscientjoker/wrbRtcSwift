//
//  combineUITest.swift
//  SimpleEyes
//
//  Created by 姜淼 on 2025/12/16.
//
//  说明：演示如何使用 Combine 处理表单输入
//  包含：登录表单（账户密码）、搜索框等实用示例
//

import SwiftUI
import Combine

struct searchItem: Codable, Sendable, Hashable, Identifiable {
    let itemId: String
    let itemName: String
    let itemType: String
    var id: String { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId, itemName, itemType
    }

    init(itemId: String, itemName: String, itemType: String) {
        self.itemId = itemId
        self.itemName = itemName
        self.itemType = itemType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try container.decode(String.self, forKey: .itemId)
        itemName = try container.decode(String.self, forKey: .itemName)
        itemType = try container.decode(String.self, forKey: .itemType)
    }
}


class SearchItemApi{
    static func performTestSearchRequest(keyword: String) -> AnyPublisher<[searchItem], Error> {
        return Future { promise in
            // ✅ 在全局并发队列中延迟 + 模拟工作（不阻塞 UI）
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                let results = [
                    searchItem(itemId: "21312312\(keyword)-1", itemName: "\(keyword) - 结果 1", itemType: "12"),
                    searchItem(itemId: "21312312\(keyword)-2", itemName: "\(keyword) - 结果 2", itemType: "12"),
                    searchItem(itemId: "21312312\(keyword)-3", itemName: "\(keyword) - 结果 3", itemType: "12"),
                    searchItem(itemId: "21312312\(keyword)-4", itemName: "\(keyword) - 结果 4", itemType: "12"),
                    searchItem(itemId: "21312312\(keyword)-5", itemName: "\(keyword) - 结果 5", itemType: "12"),
                    searchItem(itemId: "21312312\(keyword)-6", itemName: "\(keyword) - 结果 6", itemType: "12"),
                    searchItem(itemId: "21312312\(keyword)-7", itemName: "\(keyword) - 结果 7", itemType: "12")
                ]
                // ✅ 安全地 fulfill Promise（Future 内部处理线程安全）
                promise(.success(results))
            }
        }
        .receive(on: DispatchQueue.main) // ✅ 确保下游（如 assign/sink）在主线程执行
        .eraseToAnyPublisher()
    }
}

// MARK: - 登录表单 ViewModel
/// 登录表单的业务逻辑处理
class TestLoginViewModel: ObservableObject {

    // MARK: - 输入属性

    /// 原始用户名输入
    @Published var username: String = ""

    /// 原始密码输入
    @Published var password: String = ""

    // MARK: - 处理后的属性

    /// 验证后的用户名（3-20位字母数字）
    @Published var validatedUsername: String = ""

    /// 验证后的密码（6-20位）
    @Published var validatedPassword: String = ""

    // MARK: - 状态属性

    /// 用户名是否有效
    @Published var isUsernameValid: Bool = false

    /// 密码是否有效
    @Published var isPasswordValid: Bool = false

    /// 表单是否可以提交
    @Published var canSubmit: Bool = false

    /// 用户名错误提示
    @Published var usernameError: String = ""

    /// 密码错误提示
    @Published var passwordError: String = ""

    /// 是否正在登录
    @Published var isLoading: Bool = false

    // MARK: - Private 属性

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化
    init() {
        setupUsernameValidation()
        setupPasswordValidation()
        setupFormValidation()
    }

    // MARK: - 用户名验证设置

    /// 配置用户名验证逻辑
    ///
    /// 验证规则：
    /// - 只允许字母和数字
    /// - 长度限制 3-20 位
    /// - 去除所有空格
    ///
    /// 处理流程：
    /// 1. 使用 textFieldValidator 处理输入
    /// 2. 去除空格、过滤特殊字符
    /// 3. 限制长度为 20 位
    /// 4. 赋值给 validatedUsername
    /// 5. 验证长度是否符合 3-20 位要求
    /// 6. 更新错误提示信息
    private func setupUsernameValidation() {
        // 步骤1: 处理和验证用户名
        $username
            .textFieldValidator(
                maxLength: 20,
                removeAllSpaces: true,
                allowedPattern: "[a-zA-Z0-9]"
            )
            .assign(to: &$validatedUsername)

        // 步骤2: 验证用户名长度
        $validatedUsername
            .map { username in
                // 长度在 3-20 之间为有效
                return (3...20).contains(username.count)
            }
            .assign(to: &$isUsernameValid)

        // 步骤3: 生成错误提示
        $validatedUsername
            .map { username in
                if username.isEmpty {
                    return "请输入用户名"
                } else if username.count < 3 {
                    return "用户名至少 3 位"
                } else if username.count > 20 {
                    return "用户名最多 20 位"
                } else {
                    return ""
                }
            }
            .assign(to: &$usernameError)
    }

    // MARK: - 密码验证设置

    /// 配置密码验证逻辑
    ///
    /// 验证规则：
    /// - 允许所有可见字符
    /// - 长度限制 6-20 位
    /// - 去除首尾空格
    ///
    /// 处理流程：
    /// 1. 去除首尾空格
    /// 2. 限制长度为 20 位
    /// 3. 验证长度是否符合 6-20 位要求
    /// 4. 更新错误提示信息
    private func setupPasswordValidation() {
        // 步骤1: 处理密码（去除首尾空格，限制长度）
        $password
            .trimWhitespace()
            .limitLength(to: 20)
            .assign(to: &$validatedPassword)

        // 步骤2: 验证密码长度
        $validatedPassword
            .map { password in
                return password.count >= 6
            }
            .assign(to: &$isPasswordValid)

        // 步骤3: 生成错误提示
        $validatedPassword
            .map { password in
                if password.isEmpty {
                    return "请输入密码"
                } else if password.count < 6 {
                    return "密码至少 6 位"
                } else {
                    return ""
                }
            }
            .assign(to: &$passwordError)
    }

    // MARK: - 表单验证设置

    /// 配置整体表单验证
    ///
    /// 只有当用户名和密码都有效时，才允许提交表单
    private func setupFormValidation() {
        Publishers.CombineLatest($isUsernameValid, $isPasswordValid)
            .map { usernameValid, passwordValid in
                return usernameValid && passwordValid
            }
            .assign(to: &$canSubmit)
    }

    // MARK: - 登录操作

    /// 执行登录
    func login() {
        guard canSubmit else { return }

        isLoading = true

        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isLoading = false
            print("登录成功！")
            print("用户名: \(self?.validatedUsername ?? "")")
            print("密码: \(self?.validatedPassword ?? "")")
        }
    }
}

// MARK: - 搜索 ViewModel
/// 搜索功能的业务逻辑处理
class TestSearchViewModel: ObservableObject {

    // MARK: - 输入属性
    // 高级搜索开关
    @Published var isAdvancedSearch = false
    /// 原始搜索关键词
    @Published var searchKeyword: String = ""

    // MARK: - 状态属性

    /// 搜索结果列表
    @Published var searchResults: [searchItem] = []

    /// 是否正在搜索
    @Published var isSearching: Bool = false

    /// 处理后的关键词（用于显示）
    @Published var processedKeyword: String = ""

    /// 错误信息
    @Published var errorMessage: String = ""

    // MARK: - Private 属性

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init() {
        setupSearchPipeline()
    }

    // MARK: - 搜索管道设置

    /// 配置搜索处理管道
    ///
    /// 处理流程：
    /// 1. 去除首尾空格
    /// 2. 限制最大长度为 50 字符
    /// 3. 防抖处理（用户停止输入 0.5 秒后才执行）
    /// 4. 去重（避免重复搜索相同关键词）
    /// 5. 过滤空字符串和长度小于 2 的关键词
    /// 6. 执行搜索
    ///
    /// 性能优化：
    /// - debounce: 减少频繁的搜索请求
    /// - removeDuplicates: 避免重复搜索
    /// - filter: 只搜索有意义的关键词
    private func setupSearchPipeline() {
        $searchKeyword
            .trimWhitespace()                      // 1. 去除首尾空格
            .limitLength(to: 50)                   // 2. 限制长度
            .debounceTextField(for: 0.5)           // 3. 防抖 0.5 秒
            .removeDuplicates()                    // 4. 去重
            .filter { keyword in  keyword.count >= 2 } // 5. 过滤 至少 2 个字符才搜索
            .sink { [weak self] keyword in         // 6. 执行搜索
                self?.processedKeyword = keyword
                self?.performSearch(keyword: keyword)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 搜索执行
    /// 执行搜索操作
    /// - Parameter keyword: 搜索关键词
    private func performSearch(keyword: String) {
        isSearching = true
        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            // 模拟搜索结果
            self?.searchResults = [
                searchItem(itemId:"21312312\(keyword)-1",itemName:"\(keyword) - 结果 1",itemType:"12"),
                searchItem(itemId:"21312312\(keyword)-2",itemName:"\(keyword) - 结果 2",itemType:"12"),
                searchItem(itemId:"21312312\(keyword)-3",itemName:"\(keyword) - 结果 3",itemType:"12"),
                searchItem(itemId:"21312312\(keyword)-4",itemName:"\(keyword) - 结果 4",itemType:"12"),
                searchItem(itemId:"21312312\(keyword)-5",itemName:"\(keyword) - 结果 5",itemType:"12"),
                searchItem(itemId:"21312312\(keyword)-6",itemName:"\(keyword) - 结果 6",itemType:"12"),
                searchItem(itemId:"21312312\(keyword)-7",itemName:"\(keyword) - 结果 7",itemType:"12"),
            ]
            self?.isSearching = false
            print("搜索完成: \(keyword)")
        }
    }
    
    /// 清空搜索
    func clearSearch() {
        searchKeyword = ""
        searchResults = []
        processedKeyword = ""
    }
    
    // MARK: - 测试全功能
    private func testCombineAllFunc(){
        $searchKeyword
            // 🔹 1. 【转换】只允许 ≥1 字符，否则转为空（后续会被过滤）
            .map { $0.count >= 1 ? $0.trimmingCharacters(in: .whitespaces) : "" }
            // 🔹 2. 【过滤】跳过空字符串（提前拦截无效输入）
            .filter { !$0.isEmpty }
            // 🔹 3. 【去重】避免相同关键词重复触发
            .removeDuplicates()
            // 🔹 4. 【时间控制】防抖：用户停止输入 300ms 后才继续
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            // 🔹 5. 【日志】记录每次有效搜索词（不改变数据流）不会修改、过滤或阻塞这个值，只是“旁路监听”
            .handleEvents(receiveOutput: { keyword in print("🔍 发起搜索: '\(keyword)'") })
            // 🔹 6. 【转换 + 异步】将关键词转为网络请求 Publisher 🔸 maxPublishers 限制并发：只处理最新请求（自动取消旧请求）
            .flatMap(maxPublishers: .max(1)) { keyWord in
                SearchItemApi.performTestSearchRequest(keyword: keyWord)
                    //🔹 7. 【时间控制】设置超时（5秒未响应则失败）
                    .timeout(.seconds(5), scheduler: RunLoop.main)
                    // 🔹 8. 【错误处理】失败时重试最多 2 次
                    .retry(2)
                    // 🔹 9. 【错误恢复】若仍失败，返回默认空结果并记录错误
                    .catch { error -> AnyPublisher<[searchItem], Never> in
                        DispatchQueue.main.async {
                            self.errorMessage = "搜索失败: \(error.localizedDescription)"
                        }
                        return Just([])
                            .setFailureType(to: Never.self) // 抹除错误类型
                            .eraseToAnyPublisher()
                    }
                    // 🔹 10. 【共享】避免重复执行上游操作
                    .share()
                    // 🔹 11. 统一类型为
                    .eraseToAnyPublisher()
            }
            // 🔹 12. 【组合】与另一个信号组合（例如：是否启用高级筛选）
            .combineLatest($isAdvancedSearch) { searchItems, isAdvanced in
                if isAdvanced {
                    // 示例：只显示名称包含偶数的项
                    return searchItems.enumerated().filter { index, _ in index % 2 == 0 }.map { $0.element }
                }
                return searchItems
            }
            // 🔹 13. 【扫描累积】记录历史搜索结果（用于“最近搜索”） 会出现数据不断增加问题 建议使用单独属性 单独维护 （只能在当前的生命周期内） 常见场景 分页数据的累加
            .scan((current: [searchItem](), history: Set<String>())) { acc, current in
                let newHistory = acc.history.union(current.map { "\($0.id)" })
                return (current: current, history: newHistory)
            }
            // 🔹 14. 【转换】只返回 current
            .map { $0.current }
            // 🔹 15. 【侧路操作】每次收到结果都打印
            .handleEvents(
                receiveOutput: { _ in print("✅ 搜索完成") },
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("⏹️ 搜索流正常结束")
                    case .failure(let error):
                        print("💥 搜索流异常终止: \(error)")
                    }
                }
            )
            // 🔹 16. 【类型擦除】统一返回类型（便于调试或接口暴露）
            .eraseToAnyPublisher()
            // 🔹 17. 【后面操作在主线程】
            .receive(on: DispatchQueue.main)
            // 🔹 18. 【订阅并保存】使用 sink 订阅并将结果赋值 或者 使用 assign，如果不需要 赋值、日志、调用函数等 其他逻辑
            .sink { [weak self] results in
                self?.searchResults = results
            }
//            .assign(to: &$searchResults)
            // 🔹 19. 【生命周期管理】保存订阅，防止被释放
            .store(in: &cancellables)
    }
}

// MARK: - 登录视图
/// 登录表单 UI
struct LoginView: View {

    @StateObject private var viewModel = TestLoginViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("用户登录")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 30)

            // 用户名输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("用户名")
                    .font(.headline)

                TextField("请输入用户名（3-20位字母数字）", text: $viewModel.username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                // 实时显示处理后的值
                if !viewModel.validatedUsername.isEmpty {
                    Text("处理后: \(viewModel.validatedUsername)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                // 错误提示
                if !viewModel.usernameError.isEmpty && !viewModel.username.isEmpty {
                    Text(viewModel.usernameError)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // 验证状态指示
                HStack {
                    Image(systemName: viewModel.isUsernameValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(viewModel.isUsernameValid ? .green : .red)
                    Text(viewModel.isUsernameValid ? "用户名有效" : "用户名无效")
                        .font(.caption)
                }
                .opacity(viewModel.username.isEmpty ? 0 : 1)
            }

            // 密码输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("密码")
                    .font(.headline)

                SecureField("请输入密码（至少6位）", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)

                // 密码长度提示
                if !viewModel.validatedPassword.isEmpty {
                    Text("密码长度: \(viewModel.validatedPassword.count)/20")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                // 错误提示
                if !viewModel.passwordError.isEmpty && !viewModel.password.isEmpty {
                    Text(viewModel.passwordError)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // 验证状态指示
                HStack {
                    Image(systemName: viewModel.isPasswordValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(viewModel.isPasswordValid ? .green : .red)
                    Text(viewModel.isPasswordValid ? "密码有效" : "密码无效")
                        .font(.caption)
                }
                .opacity(viewModel.password.isEmpty ? 0 : 1)
            }

            // 登录按钮
            Button(action: {
                viewModel.login()
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("登录")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(viewModel.canSubmit ? Color.blue : Color.gray)
            .cornerRadius(10)
            .disabled(!viewModel.canSubmit || viewModel.isLoading)

            Spacer()
        }
        .padding()
    }
}

// MARK: - 搜索视图
/// 搜索功能 UI
struct SearchView: View {

    @StateObject private var viewModel = TestSearchViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("智能搜索")
                .font(.largeTitle)
                .fontWeight(.bold)

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("输入搜索关键词（至少2个字符）", text: $viewModel.searchKeyword)
                    .textFieldStyle(.plain)

                if !viewModel.searchKeyword.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)

            // 搜索信息提示
            if !viewModel.processedKeyword.isEmpty {
                HStack {
                    Text("搜索中: \"\(viewModel.processedKeyword)\"")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                }
            }

            // 加载指示器
            if viewModel.isSearching {
                HStack {
                    ProgressView()
                    Text("正在搜索...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
            }

            // 搜索结果列表
            if !viewModel.searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("搜索结果")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)

                    List(viewModel.searchResults, id: \.self) { result in
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text(result.itemName)
                        }
                        .padding(.vertical, 8)
                    }
                }
            } else if viewModel.searchKeyword.isEmpty {
                // 空状态提示
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("输入关键词开始搜索")
                        .foregroundColor(.gray)
                }
                .padding(.top, 50)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - 主测试视图
/// Combine UI 测试主界面
struct CombineUITestView: View {

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 登录表单
            NavigationView {
                LoginView()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("登录", systemImage: "person.circle")
            }
            .tag(0)

            // Tab 2: 搜索
            NavigationView {
                SearchView()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .tag(1)
        }
    }
}

// MARK: - 预览
#Preview("登录表单") {
    LoginView()
}

#Preview("搜索") {
    SearchView()
}

#Preview("完整界面") {
    CombineUITestView()
}
