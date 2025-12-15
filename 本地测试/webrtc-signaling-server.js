#!/usr/bin/env node
/**
 * SimpleEyes WebRTC 信令服务器
 * 用于双向音视频通话
 */

const WebSocket = require('ws');
const http = require('http');
const dgram = require('dgram');
const os = require('os');
const bonjour = require('bonjour')();

const PORT = 8080;
const SERVER_NAME = 'SimpleEyes WebRTC 信令服务器';

// Multicast 配置
const MULTICAST_ADDRESS = '239.255.255.250';
const MULTICAST_PORT = 12345;
const MULTICAST_INTERVAL = 5000; // 每 5 秒广播一次

// 创建 HTTP 服务器
const server = http.createServer((req, res) => {
    // 设置 CORS 头
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    res.setHeader('Content-Type', 'application/json');

    // 处理 OPTIONS 请求
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    // API: 健康检查（用于服务器发现）
    if (req.url === '/api/health' && req.method === 'GET') {
        res.writeHead(200);
        res.end(JSON.stringify({
            name: 'SimpleEyes WebRTC 信令服务器',
            status: 'ok',
            port: PORT,
            clients: clients.size
        }));
        return;
    }

    // API: 获取在线设备列表
    if (req.url === '/api/devices/online' && req.method === 'GET') {
        const onlineDevices = [];
        const deviceSet = new Set();

        for (const [deviceId, connection] of clients.entries()) {
            if (connection.ws.readyState === WebSocket.OPEN) {
                deviceSet.add(deviceId);
            }
        }

        // 转换为数组
        deviceSet.forEach(deviceId => {
            onlineDevices.push({
                deviceId: deviceId,
                status: 'online',
                name: `设备 ${deviceId}`
            });
        });

        res.writeHead(200);
        res.end(JSON.stringify({
            devices: onlineDevices,
            count: onlineDevices.length
        }));
        return;
    }

    // 404
    res.writeHead(404);
    res.end(JSON.stringify({ error: 'Not Found' }));
});

// 创建 WebSocket 服务器
const wss = new WebSocket.Server({ noServer: true });

// 存储连接的客户端: Map<deviceId, {ws, type}>
const clients = new Map();

// 处理 WebSocket 升级请求
server.on('upgrade', (request, socket, head) => {
    wss.handleUpgrade(request, socket, head, (ws) => {
        wss.emit('connection', ws, request);
    });
});

// WebSocket 连接处理
wss.on('connection', (ws, req) => {
    // 解析连接参数
    const url = new URL(req.url, 'http://localhost');
    const deviceId = url.searchParams.get('deviceId');
    const type = url.searchParams.get('type') || 'peer'; // peer, audio

    if (!deviceId) {
        console.log('❌ 连接被拒绝: 缺少 deviceId 参数');
        ws.close();
        return;
    }

    // 保存客户端连接
    clients.set(deviceId, { ws, type });

    console.log(`✅ 新连接: [${type}] 设备ID=${deviceId} (总连接数: ${clients.size})`);

    // 接收消息
    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            console.log(`📨 收到消息: [${type}] 设备ID=${deviceId}`, data.type || data);

            // 处理不同类型的信令消息
            switch (data.type) {
                case 'offer':
                case 'answer':
                case 'ice-candidate':
                    // 转发 WebRTC 信令到目标设备
                    forwardSignaling(deviceId, data);
                    break;

                case 'call':
                    // 发起通话请求
                    handleCallRequest(deviceId, data);
                    break;

                case 'hangup':
                    // 挂断通话
                    handleHangup(deviceId, data);
                    break;

                default:
                    // 其他消息类型（音频数据等）
                    if (Buffer.isBuffer(message) || data.audio) {
                        // 转发音频数据
                        forwardAudioData(deviceId, message);
                    }
            }
        } catch (error) {
            // 二进制数据（音频）
            if (Buffer.isBuffer(message)) {
                forwardAudioData(deviceId, message);
            } else {
                console.log(`⚠️  解析消息失败: ${error.message}`);
            }
        }
    });

    // 连接断开
    ws.on('close', () => {
        clients.delete(deviceId);
        console.log(`❌ 断开连接: [${type}] 设备ID=${deviceId} (剩余连接: ${clients.size})`);

        // 通知其他客户端
        broadcastDeviceStatus(deviceId, 'offline');
    });

    // 错误处理
    ws.on('error', (error) => {
        console.log(`⚠️  错误 [${type}] 设备ID=${deviceId}:`, error.message);
    });

    // 广播设备上线
    broadcastDeviceStatus(deviceId, 'online');
});

// 转发 WebRTC 信令消息
function forwardSignaling(fromDeviceId, data) {
    const targetDeviceId = data.to;
    if (!targetDeviceId) {
        console.log(`⚠️  缺少目标设备ID`);
        return;
    }

    const targetConnection = clients.get(targetDeviceId);
    if (targetConnection && targetConnection.ws.readyState === WebSocket.OPEN) {
        const signaling = {
            ...data,
            from: fromDeviceId
        };
        targetConnection.ws.send(JSON.stringify(signaling));
        console.log(`📡 转发信令: [${fromDeviceId}] → [${targetDeviceId}] (${data.type})`);
    } else {
        console.log(`⚠️  目标设备未连接: [${targetDeviceId}]`);
    }
}

// 处理通话请求
function handleCallRequest(fromDeviceId, data) {
    const targetDeviceId = data.to;
    if (!targetDeviceId) {
        console.log(`⚠️  缺少目标设备ID`);
        return;
    }

    const targetConnection = clients.get(targetDeviceId);
    if (targetConnection && targetConnection.ws.readyState === WebSocket.OPEN) {
        const callRequest = {
            type: 'incoming-call',
            from: fromDeviceId,
            callType: data.callType || 'video' // video, audio
        };
        targetConnection.ws.send(JSON.stringify(callRequest));
        console.log(`📞 通话请求: [${fromDeviceId}] → [${targetDeviceId}] (${data.callType})`);
    } else {
        // 目标设备不在线，通知发起者
        const fromConnection = clients.get(fromDeviceId);
        if (fromConnection) {
            fromConnection.ws.send(JSON.stringify({
                type: 'call-failed',
                reason: 'target-offline',
                target: targetDeviceId
            }));
        }
    }
}

// 处理挂断
function handleHangup(fromDeviceId, data) {
    const targetDeviceId = data.to;
    if (!targetDeviceId) return;

    const targetConnection = clients.get(targetDeviceId);
    if (targetConnection && targetConnection.ws.readyState === WebSocket.OPEN) {
        targetConnection.ws.send(JSON.stringify({
            type: 'hangup',
            from: fromDeviceId
        }));
        console.log(`📴 挂断通话: [${fromDeviceId}] → [${targetDeviceId}]`);
    }
}

// 转发音频数据
function forwardAudioData(fromDeviceId, data) {
    // 这里可以根据需要实现音频数据转发逻辑
    // 对于 WebRTC，音频数据通过 RTP 直接传输，不经过服务器
}

// 广播设备状态
function broadcastDeviceStatus(deviceId, status) {
    const message = JSON.stringify({
        type: 'device-status',
        deviceId: deviceId,
        status: status
    });

    for (const [id, connection] of clients.entries()) {
        if (id !== deviceId && connection.ws.readyState === WebSocket.OPEN) {
            connection.ws.send(message);
        }
    }
}

// 获取本地 IP 地址
function getLocalIPAddress() {
    const interfaces = os.networkInterfaces();

    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            // 跳过内部地址和非 IPv4 地址
            if (iface.family === 'IPv4' && !iface.internal) {
                // 优先返回局域网地址
                if (iface.address.startsWith('192.168.') ||
                    iface.address.startsWith('10.') ||
                    iface.address.startsWith('172.')) {
                    return iface.address;
                }
            }
        }
    }

    return 'localhost';
}

// UDP Multicast 广播
let multicastSocket = null;
let multicastIntervalId = null;

function startMulticastBroadcast() {
    const localIP = getLocalIPAddress();

    // 创建 UDP socket
    multicastSocket = dgram.createSocket('udp4');

    // 配置 socket
    multicastSocket.bind(() => {
        try {
            multicastSocket.setBroadcast(true);
            multicastSocket.setMulticastTTL(128);
            multicastSocket.addMembership(MULTICAST_ADDRESS);

            console.log('📡 UDP Multicast 广播已启动:');
            console.log(`   多播地址: ${MULTICAST_ADDRESS}:${MULTICAST_PORT}`);
            console.log(`   广播间隔: ${MULTICAST_INTERVAL}ms`);
            console.log(`   本地IP: ${localIP}`);
            console.log('');
        } catch (error) {
            console.log('⚠️  Multicast 配置错误:', error.message);
        }
    });

    // 定期广播服务器信息
    const broadcastMessage = () => {
        const message = JSON.stringify({
            name: SERVER_NAME,
            host: localIP,
            port: PORT,
            apiURL: `http://${localIP}:${PORT}`,
            wsURL: `ws://${localIP}:${PORT}`,
            timestamp: Date.now()
        });

        const buffer = Buffer.from(message);

        multicastSocket.send(buffer, 0, buffer.length, MULTICAST_PORT, MULTICAST_ADDRESS, (error) => {
            if (error) {
                console.log('⚠️  Multicast 发送错误:', error.message);
            }
        });
    };

    // 立即发送一次
    setTimeout(broadcastMessage, 1000);

    // 启动定时广播
    multicastIntervalId = setInterval(broadcastMessage, MULTICAST_INTERVAL);
}

function stopMulticastBroadcast() {
    if (multicastIntervalId) {
        clearInterval(multicastIntervalId);
        multicastIntervalId = null;
    }

    if (multicastSocket) {
        try {
            multicastSocket.dropMembership(MULTICAST_ADDRESS);
            multicastSocket.close();
        } catch (error) {
            // Ignore errors during cleanup
        }
        multicastSocket = null;
        console.log('✅ UDP Multicast 广播已停止');
    }
}

// 启动服务器
server.listen(PORT, () => {
    console.log('╔══════════════════════════════════════════════════════════╗');
    console.log('║                                                          ║');
    console.log('║     SimpleEyes WebRTC 信令服务器                         ║');
    console.log('║                                                          ║');
    console.log('╚══════════════════════════════════════════════════════════╝');
    console.log('');
    console.log(`🚀 WebSocket 服务器: ws://localhost:${PORT}`);
    console.log(`📡 HTTP API 服务器: http://localhost:${PORT}`);
    console.log(`📱 在线设备列表 API: http://localhost:${PORT}/api/devices/online`);
    console.log(`🎥 支持双向音视频通话（WebRTC）`);
    console.log('');

    // 发布 Bonjour 服务（用于局域网自动发现）
    bonjourServiceInstance = bonjour.publish({
        name: SERVER_NAME,
        type: 'simpleyes',
        port: PORT,
        txt: {
            apiPort: String(PORT),
            wsPort: String(PORT),
            name: SERVER_NAME,
            version: '1.0.0'
        }
    });

    console.log('📡 Bonjour 服务已发布:');
    console.log(`   服务名称: ${SERVER_NAME}`);
    console.log(`   服务类型: _simpleyes._tcp`);
    console.log(`   端口: ${PORT}`);
    console.log(`   ✅ iOS 客户端现在可以自动发现此服务器`);
    console.log('');

    bonjourServiceInstance.on('up', () => {
        console.log('✅ Bonjour 服务已上线');
    });

    bonjourServiceInstance.on('error', (error) => {
        console.log('⚠️  Bonjour 服务错误:', error.message);
    });

    // 启动 UDP Multicast 广播
    startMulticastBroadcast();
});

// 定期显示连接状态
setInterval(() => {
    if (clients.size > 0) {
        console.log(`\n📊 当前连接状态 (${new Date().toLocaleTimeString()}):`);
        for (const [deviceId, connection] of clients.entries()) {
            const status = connection.ws.readyState === WebSocket.OPEN ? '🟢 在线' : '🔴 离线';
            console.log(`   ${status} [${connection.type}] 设备ID=${deviceId}`);
        }
        console.log('');
    }
}, 30000); // 每30秒显示一次

// 优雅退出
let bonjourServiceInstance = null;

process.on('SIGINT', () => {
    console.log('\n\n👋 正在关闭服务器...');

    // 停止 UDP Multicast 广播
    stopMulticastBroadcast();

    // 停止 Bonjour 服务
    if (bonjourServiceInstance) {
        bonjourServiceInstance.stop();
        console.log('✅ Bonjour 服务已停止');
    }
    bonjour.destroy();

    wss.close(() => {
        server.close(() => {
            console.log('✅ 服务器已关闭');
            process.exit(0);
        });
    });
});

console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('');
console.log('💡 使用说明:');
console.log('   1. App 中进入"设置"标签');
console.log('   2. 配置 WebSocket 服务器地址: ws://你的IP:8080');
console.log('   3. 进入"视频通话"标签');
console.log('   4. 选择在线设备');
console.log('   5. 点击"开始通话"进行音视频通话');
console.log('');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('');
