# SimpleEyes WebRTC 信令服务器

支持双向音视频通话和 Bonjour (mDNS) 自动服务发现的 WebRTC 信令服务器。

## 功能特性

- ✅ **WebRTC 信令服务**：支持 offer、answer、ICE candidate 转发
- ✅ **双向音视频通话**：支持视频通话和音频通话
- ✅ **Bonjour 服务发现**：iOS 客户端可自动发现局域网内的服务器
- ✅ **实时设备管理**：显示在线设备列表
- ✅ **健康检查 API**：提供 `/api/health` 端点用于服务器状态检查
- ✅ **CORS 支持**：支持跨域请求

## 快速开始

### 1. 安装依赖

```bash
cd 本地测试
npm install
```

### 2. 启动服务器

```bash
# 普通启动
npm start

# 开发模式（自动重启）
npm run dev

# 或者直接运行
node webrtc-signaling-server.js
```

### 3. 服务器信息

启动后，服务器会监听以下服务：

- **WebSocket 服务**：`ws://localhost:8080`
- **HTTP API 服务**：`http://localhost:8080`
- **健康检查 API**：`http://localhost:8080/api/health`
- **在线设备列表**：`http://localhost:8080/api/devices/online`
- **Bonjour 服务**：`_simpleyes._tcp` (自动广播)

## Bonjour 服务发现

服务器会自动通过 Bonjour (mDNS) 协议在局域网内广播服务信息：

- **服务类型**：`_simpleyes._tcp`
- **服务名称**：SimpleEyes WebRTC 信令服务器
- **端口**：8080
- **TXT 记录**：
  - `apiPort`: API 端口号
  - `wsPort`: WebSocket 端口号
  - `name`: 服务器名称
  - `version`: 版本号

### iOS 客户端使用

iOS 客户端无需手动输入服务器地址，只需：

1. 打开 App 的"设置"标签
2. 点击"扫描局域网服务器"按钮
3. 等待 1-2 秒，服务器会自动被发现
4. 选择服务器即可自动配置

**优势对比**：

| 特性 | 旧方案（IP 轮询） | 新方案（Bonjour） |
|-----|----------------|-----------------|
| 发现速度 | 30 秒（超时） | 1-2 秒 |
| 网络负载 | 高（1270+ 次连接） | 低（广播监听） |
| 可靠性 | 受防火墙影响 | 标准协议，可靠 |
| 实时性 | 手动重新扫描 | 自动感知上线/下线 |

## API 端点

### 健康检查

```bash
GET /api/health
```

响应示例：
```json
{
  "name": "SimpleEyes WebRTC 信令服务器",
  "status": "ok",
  "port": 8080,
  "clients": 2
}
```

### 获取在线设备

```bash
GET /api/devices/online
```

响应示例：
```json
{
  "devices": [
    {
      "deviceId": "iPhone-001",
      "status": "online",
      "name": "设备 iPhone-001"
    },
    {
      "deviceId": "iPad-002",
      "status": "online",
      "name": "设备 iPad-002"
    }
  ],
  "count": 2
}
```

## WebSocket 协议

### 连接

```javascript
ws://服务器IP:8080?deviceId=你的设备ID&type=peer
```

参数：
- `deviceId` (必需): 设备唯一标识符
- `type` (可选): 连接类型，默认为 `peer`

### 消息类型

#### 1. 发起通话

```json
{
  "type": "call",
  "to": "目标设备ID",
  "callType": "video"
}
```

#### 2. WebRTC Offer

```json
{
  "type": "offer",
  "to": "目标设备ID",
  "sdp": "..."
}
```

#### 3. WebRTC Answer

```json
{
  "type": "answer",
  "to": "目标设备ID",
  "sdp": "..."
}
```

#### 4. ICE Candidate

```json
{
  "type": "ice-candidate",
  "to": "目标设备ID",
  "candidate": "..."
}
```

#### 5. 挂断通话

```json
{
  "type": "hangup",
  "to": "目标设备ID"
}
```

## 依赖说明

- **ws** (^8.18.0): WebSocket 服务器实现
- **bonjour** (^3.5.0): Bonjour/mDNS 服务发现协议

## 开发说明

### 修改端口

编辑 `webrtc-signaling-server.js` 第 11 行：

```javascript
const PORT = 8080; // 修改为你想要的端口
```

### 自定义服务器名称

编辑 `webrtc-signaling-server.js` 第 12 行：

```javascript
const SERVER_NAME = '你的服务器名称';
```

### 日志输出

服务器会输出详细的日志信息：

- ✅ 新连接
- 📨 收到消息
- 📡 转发信令
- 📞 通话请求
- 📴 挂断通话
- ❌ 断开连接

## 故障排除

### iOS 客户端无法发现服务器

1. **检查网络**：确保 iOS 设备和服务器在同一局域网
2. **检查防火墙**：确保端口 8080 未被防火墙阻挡
3. **查看日志**：检查服务器是否输出 "✅ Bonjour 服务已上线"
4. **重启服务**：尝试重启服务器

### WebSocket 连接失败

1. **检查 URL**：确保使用 `ws://` 而不是 `wss://`
2. **检查端口**：确认端口号正确
3. **查看日志**：检查服务器端是否有错误信息

## 许可证

MIT License

---

**祝您使用愉快！** 🎉
