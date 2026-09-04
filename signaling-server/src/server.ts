import http from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { RoomManager } from './room-manager.js';
import { SignalMessage } from './types.js';

const PORT = parseInt(process.env.PORT || '8080', 10);
const HOST = process.env.HOST || '0.0.0.0';

const roomManager = new RoomManager();

// Create standard HTTP server for health check & stats
const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.url === '/health' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      service: 'ephemeral-blind-signaling',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      ...roomManager.getStats()
    }));
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not Found' }));
});

// Attach WebSocket server
const wss = new WebSocketServer({ server });

wss.on('connection', (ws: WebSocket) => {
  ws.on('message', (raw: string) => {
    try {
      const msg: SignalMessage = JSON.parse(raw.toString());

      if (!msg.action) {
        ws.send(JSON.stringify({ type: 'error', message: 'Missing action field' }));
        return;
      }

      if (msg.action === 'ping') {
        ws.send(JSON.stringify({ type: 'pong' }));
        return;
      }

      if (msg.action === 'join') {
        if (!msg.sessionId || !msg.role) {
          ws.send(JSON.stringify({ type: 'error', message: 'sessionId and role are required' }));
          return;
        }
        const result = roomManager.join(msg.sessionId, msg.role, ws);
        if (!result.success) {
          ws.send(JSON.stringify({ type: 'error', message: result.error }));
        }
        return;
      }

      if (['offer', 'answer', 'candidate', 'ice-restart'].includes(msg.action)) {
        if (!msg.sessionId) {
          ws.send(JSON.stringify({ type: 'error', message: 'sessionId is required' }));
          return;
        }
        roomManager.relaySignal(ws, msg.sessionId, msg.action, msg.payload);
        return;
      }

      if (msg.action === 'leave') {
        if (msg.sessionId) {
          roomManager.closeRoom(msg.sessionId);
        }
        return;
      }
    } catch (err: any) {
      ws.send(JSON.stringify({ type: 'error', message: 'Malformed JSON signal envelope' }));
    }
  });

  ws.on('close', () => {
    roomManager.handleDisconnect(ws);
  });

  ws.on('error', (err) => {
    console.error('[WS Error]', err.message);
    roomManager.handleDisconnect(ws);
  });
});

server.listen(PORT, HOST, () => {
  console.log(`[Blind Signaling Server] running on http://${HOST}:${PORT}`);
  console.log(`[WebSocket Endpoint] ws://${HOST}:${PORT}`);
});

process.on('SIGTERM', () => {
  console.log('Shutting down signaling server...');
  roomManager.destroy();
  server.close(() => process.exit(0));
});

process.on('SIGINT', () => {
  console.log('Interrupted. Exiting...');
  roomManager.destroy();
  server.close(() => process.exit(0));
});
