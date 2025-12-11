#!/usr/bin/env node
/**
 * 模拟设备端 - 用于测试 App 音频对讲
 * 接收 App 发送的音频，并回传（回声测试）
 */

const WebSocket = require('ws');

// 配置
const SERVER_URL = 'ws://localhost:8080';
const DEVICE_ID = process.argv[2] || 'test-001';

console.log('╔══════════════════════════════════════════════════════════╗');
console.log('║                                                          ║');
console.log('║           SimpleEyes 设备模拟器 (回声测试)               ║');
console.log('║                                                          ║');
console.log('╚══════════════════════════════════════════════════════════╝');
console.log('');
console.log(`📱 设备ID: ${DEVICE_ID}`);
console.log(`🔌 连接到: ${SERVER_URL}`);
console.log('');

// 连接到 WebSocket 服务器
const ws = new WebSocket(`${SERVER_URL}?deviceId=${DEVICE_ID}`, {
    headers: {
        'x-role': 'device'
    }
});

let audioPacketCount = 0;

ws.on('open', () => {
    console.log('✅ 已连接到服务器');
    console.log('');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('');
    console.log('💡 等待 App 连接...');
    console.log(`   在 App 中输入设备ID: ${DEVICE_ID}`);
    console.log('   然后点击"开始对讲"');
    console.log('');
    console.log('🔊 收到的音频会立即回传，形成回声效果');
    console.log('');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('');
});

ws.on('message', (data) => {
    audioPacketCount++;
    
    // 显示接收到的音频信息
    const timestamp = new Date().toLocaleTimeString();
    console.log(`📥 [${timestamp}] 收到音频包 #${audioPacketCount}: ${data.length} bytes (AAC)`);
    
    // 立即回传（回声效果）
    ws.send(data);
    console.log(`📤 [${timestamp}] 回传音频包 #${audioPacketCount}: ${data.length} bytes`);
    
    // 每10个包显示一次统计
    if (audioPacketCount % 10 === 0) {
        console.log('');
        console.log(`📊 统计: 已处理 ${audioPacketCount} 个音频包`);
        console.log('');
    }
});

ws.on('close', () => {
    console.log('');
    console.log('❌ 连接已断开');
    console.log(`📊 总共处理了 ${audioPacketCount} 个音频包`);
    process.exit(0);
});

ws.on('error', (error) => {
    console.error('⚠️  连接错误:', error.message);
    console.log('');
    console.log('💡 请确保:');
    console.log('   1. WebSocket 服务器正在运行 (node test-server.js)');
    console.log('   2. 服务器地址正确');
    process.exit(1);
});

// 优雅退出
process.on('SIGINT', () => {
    console.log('\n\n👋 正在断开连接...');
    ws.close();
});
