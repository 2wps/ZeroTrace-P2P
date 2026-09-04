import test from 'node:test';
import assert from 'node:assert';
import { RoomManager } from '../room-manager.js';
import { WebSocket } from 'ws';

class MockWebSocket {
  public sent: any[] = [];
  public readyState = WebSocket.OPEN;

  send(data: string) {
    this.sent.push(JSON.parse(data));
  }
}

test('Signaling Server - Host creates room and Guest joins', (t) => {
  const manager = new RoomManager();
  const hostWs = new MockWebSocket() as unknown as WebSocket;
  const guestWs = new MockWebSocket() as unknown as WebSocket;
  const sessionId = 'test-session-123';

  // 1. Host joins
  const hostJoin = manager.join(sessionId, 'host', hostWs);
  assert.strictEqual(hostJoin.success, true);
  assert.strictEqual((hostWs as any).sent.length, 1);
  assert.strictEqual((hostWs as any).sent[0].type, 'joined');

  // 2. Guest joins
  const guestJoin = manager.join(sessionId, 'guest', guestWs);
  assert.strictEqual(guestJoin.success, true);
  
  // Host should receive peer-joined notification
  const hostMessages = (hostWs as any).sent;
  const lastHostMsg = hostMessages[hostMessages.length - 1];
  assert.strictEqual(lastHostMsg.type, 'peer-joined');
  assert.strictEqual(lastHostMsg.senderRole, 'guest');

  // 3. Host relays offer to guest
  manager.relaySignal(hostWs, sessionId, 'offer', { sdp: 'mock-encrypted-sdp' });
  const guestMessages = (guestWs as any).sent;
  const lastGuestMsg = guestMessages[guestMessages.length - 1];
  assert.strictEqual(lastGuestMsg.type, 'signal');
  assert.strictEqual(lastGuestMsg.payload.action, 'offer');
  assert.strictEqual(lastGuestMsg.payload.data.sdp, 'mock-encrypted-sdp');

  manager.destroy();
});

test('Signaling Server - Duplicate Host is rejected', () => {
  const manager = new RoomManager();
  const host1 = new MockWebSocket() as unknown as WebSocket;
  const host2 = new MockWebSocket() as unknown as WebSocket;
  const sessionId = 'test-session-duplicate';

  manager.join(sessionId, 'host', host1);
  const duplicate = manager.join(sessionId, 'host', host2);
  assert.strictEqual(duplicate.success, false);
  assert.match(duplicate.error || '', /already connected/);

  manager.destroy();
});
