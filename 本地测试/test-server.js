#!/usr/bin/env node
/**
 * SimpleEyes WebSocket 测试服务器
 * 用于音频对讲功能测试
 */

const WebSocket = require('ws');
const http = require('http');

const PORT = 8080;

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

    // API: 获取在线设备列表
    if (req.url === '/api/devices/online' && req.method === 'GET') {
        const onlineDevices = [];
        const deviceSet = new Set();

        for (const [key, ws] of clients.entries()) {
            const [deviceId, role] = key.split('_');

            // 只统计设备端（device），不统计 app 端
            if (role === 'device' && ws.readyState === WebSocket.OPEN) {
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

// 创建 WebSocket 服务器，附加到 HTTP 服务器
// noServer: true 表示不自动处理升级请求，而是手动处理
const wss = new WebSocket.Server({ noServer: true });

// 存储连接的客户端: Map<deviceId_role, WebSocket>
const clients = new Map();

// 处理 WebSocket 升级请求
server.on('upgrade', (request, socket, head) => {
    const url = new URL(request.url, 'http://localhost');

    // 只处理 WebSocket 连接请求
    wss.handleUpgrade(request, socket, head, (ws) => {
        wss.emit('connection', ws, request);
    });
});

// 启动服务器
server.listen(PORT, () => {
    console.log('╔══════════════════════════════════════════════════════════╗');
    console.log('║                                                          ║');
    console.log('║     SimpleEyes WebSocket 音频转发服务器                  ║');
    console.log('║                                                          ║');
    console.log('╚══════════════════════════════════════════════════════════╝');
    console.log('');
    console.log(`🚀 WebSocket 服务器: ws://localhost:${PORT}`);
    console.log(`📡 HTTP API 服务器: http://localhost:${PORT}`);
    console.log(`📱 在线设备列表 API: http://localhost:${PORT}/api/devices/online`);
    console.log('');
});

wss.on('connection', (ws, req) => {
    // 解析连接参数
    const url = new URL(req.url, 'http://localhost');
    const deviceId = url.searchParams.get('deviceId');
    const role = req.headers['x-role'] || 'unknown'; // 'app' 或 'device'
    
    if (!deviceId) {
        console.log('❌ 连接被拒绝: 缺少 deviceId 参数');
        ws.close();
        return;
    }
    
    const clientKey = `${deviceId}_${role}`;
    clients.set(clientKey, ws);
    
    console.log(`✅ 新连接: [${role}] 设备ID=${deviceId} (总连接数: ${clients.size})`);
    
    // 接收消息
    ws.on('message', (data) => {
        const targetRole = role === 'app' ? 'device' : 'app';
        const targetKey = `${deviceId}_${targetRole}`;
        
        // 转发音频数据到对应的目标端
        if (clients.has(targetKey)) {
            clients.get(targetKey).send(data);
            console.log(`📡 转发音频: [${role}] → [${targetRole}] (${data.length} bytes)`);
        } else {
            console.log(`⚠️  目标端未连接: [${targetRole}] 设备ID=${deviceId}`);
        }
    });
    
    // 连接断开
    ws.on('close', () => {
        clients.delete(clientKey);
        console.log(`❌ 断开连接: [${role}] 设备ID=${deviceId} (剩余连接: ${clients.size})`);
    });
    
    // 错误处理
    ws.on('error', (error) => {
        console.log(`⚠️  错误 [${role}] 设备ID=${deviceId}:`, error.message);
    });
});

// 定期显示连接状态
setInterval(() => {
    if (clients.size > 0) {
        console.log(`\n📊 当前连接状态 (${new Date().toLocaleTimeString()}):`);
        for (const [key, ws] of clients.entries()) {
            const [deviceId, role] = key.split('_');
            const status = ws.readyState === WebSocket.OPEN ? '🟢 在线' : '🔴 离线';
            console.log(`   ${status} [${role}] 设备ID=${deviceId}`);
        }
        console.log('');
    }
}, 30000); // 每30秒显示一次

// 优雅退出
process.on('SIGINT', () => {
    console.log('\n\n👋 正在关闭服务器...');
    wss.close(() => {
        server.close(() => {
            console.log('✅ 服务器已关闭');
            process.exit(0);
        });
    });
});

console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('');
console.log('💡 测试步骤:');
console.log('   1. App 中进入"设置"标签');
console.log('   2. 修改 WebSocket 服务器地址为: ws://你的IP:8080');
console.log('   3. 保存配置');
console.log('   4. 进入"语音对讲"标签');
console.log('   5. 输入设备ID (例如: test-001)');
console.log('   6. 点击"开始对讲"');
console.log('');
console.log('🔧 模拟设备端测试:');
console.log('   在另一个终端运行: node device-simulator.js');
console.log('');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('');
