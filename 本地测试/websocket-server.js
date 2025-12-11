const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });
const clients = new Map();

wss.on('connection', (ws, req) => {
 const url = new URL(req.url, 'http://localhost');
 const deviceId = url.searchParams.get('deviceId');
 const role = req.headers['x-role']; // 'app' 或 'device'

 const key = `${deviceId}_${role}`;
 clients.set(key, ws);
 console.log(`${role} connected for device ${deviceId}`);

 ws.on('message', (data) => {
  const targetRole = role === 'app' ? 'device' : 'app';
  const targetKey = `${deviceId}_${targetRole}`;

  if (clients.has(targetKey)) {
   clients.get(targetKey).send(data);
  }
 });

 ws.on('close', () => {
  clients.delete(key);
  console.log(`${role} disconnected for device ${deviceId}`);
 });
});

console.log('WebSocket server listening on port 8080');