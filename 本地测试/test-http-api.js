#!/usr/bin/env node
/**
 * 测试 HTTP API 端点
 */

const http = require('http');

const options = {
    hostname: '192.168.1.217',
    port: 8080,
    path: '/api/devices/online',
    method: 'GET',
    headers: {
        'Accept': 'application/json'
    }
};

console.log('测试 HTTP API...');
console.log(`URL: http://${options.hostname}:${options.port}${options.path}`);
console.log('');

const req = http.request(options, (res) => {
    console.log(`状态码: ${res.statusCode}`);
    console.log(`响应头:`, res.headers);
    console.log('');

    let data = '';

    res.on('data', (chunk) => {
        data += chunk;
    });

    res.on('end', () => {
        console.log('响应数据:');
        console.log(data);
        console.log('');

        if (res.statusCode === 200) {
            try {
                const json = JSON.parse(data);
                console.log('✅ JSON 解析成功:');
                console.log(JSON.stringify(json, null, 2));
            } catch (e) {
                console.log('❌ JSON 解析失败:', e.message);
            }
        } else {
            console.log('❌ HTTP 状态码不是 200');
        }
    });
});

req.on('error', (e) => {
    console.error(`❌ 请求错误: ${e.message}`);
});

req.end();
