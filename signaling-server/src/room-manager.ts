import { WebSocket } from 'ws';
import { EphemeralRoom, PeerConnection, PeerRole, ServerResponse } from './types.js';

export class RoomManager {
  private rooms: Map<string, EphemeralRoom> = new Map();
  private wsToPeer: Map<WebSocket, { sessionId: string; role: PeerRole }> = new Map();
  private cleanupInterval: NodeJS.Timeout;
  private readonly defaultTTL = 10 * 60 * 1000; // 10 minutes max room life for signaling

  constructor() {
    // Periodic garbage collector for expired rooms
    this.cleanupInterval = setInterval(() => this.cleanExpiredRooms(), 30 * 1000);
  }

  public join(sessionId: string, role: PeerRole, ws: WebSocket): { success: boolean; error?: string } {
    if (!sessionId || !role) {
      return { success: false, error: 'Invalid sessionId or role' };
    }

    let room = this.rooms.get(sessionId);
    const now = Date.now();

    if (!room) {
      if (role !== 'host') {
        return { success: false, error: 'Room does not exist or has expired. Host must initialize room first.' };
      }
      room = {
        sessionId,
        createdAt: now,
        expiresAt: now + this.defaultTTL,
        messageCount: 0,
      };
      this.rooms.set(sessionId, room);
    }

    const peerConnection: PeerConnection = {
      ws,
      role,
      sessionId,
      joinedAt: now,
    };

    if (role === 'host') {
      if (room.host && room.host.ws !== ws && room.host.ws.readyState === WebSocket.OPEN) {
        return { success: false, error: 'Host already connected to this session' };
      }
      room.host = peerConnection;
    } else {
      if (room.guest && room.guest.ws !== ws && room.guest.ws.readyState === WebSocket.OPEN) {
        return { success: false, error: 'Session already has an active guest' };
      }
      room.guest = peerConnection;
    }

    this.wsToPeer.set(ws, { sessionId, role });

    // Send confirmation to joining peer
    this.send(ws, {
      type: 'joined',
      sessionId,
      senderRole: role,
      message: `Successfully joined as ${role}`,
    });

    // Notify the other peer if connected
    const otherPeer = role === 'host' ? room.guest : room.host;
    if (otherPeer && otherPeer.ws.readyState === WebSocket.OPEN) {
      this.send(otherPeer.ws, {
        type: 'peer-joined',
        sessionId,
        senderRole: role,
      });

      this.send(ws, {
        type: 'peer-joined',
        sessionId,
        senderRole: otherPeer.role,
      });
    }

    return { success: true };
  }

  public relaySignal(ws: WebSocket, sessionId: string, action: string, payload: any): void {
    const room = this.rooms.get(sessionId);
    if (!room) {
      this.send(ws, { type: 'error', message: 'Room not found or expired' });
      return;
    }

    const peerInfo = this.wsToPeer.get(ws);
    if (!peerInfo || peerInfo.sessionId !== sessionId) {
      this.send(ws, { type: 'error', message: 'Unauthorized peer for this session' });
      return;
    }

    const targetPeer = peerInfo.role === 'host' ? room.guest : room.host;
    if (!targetPeer || targetPeer.ws.readyState !== WebSocket.OPEN) {
      this.send(ws, { type: 'error', message: 'Target peer is not connected yet' });
      return;
    }

    room.messageCount++;

    // Blind relay - payload is forwarded as-is without inspection
    this.send(targetPeer.ws, {
      type: 'signal',
      sessionId,
      senderRole: peerInfo.role,
      payload: {
        action,
        data: payload,
      },
    });
  }

  public handleDisconnect(ws: WebSocket): void {
    const peerInfo = this.wsToPeer.get(ws);
    if (!peerInfo) return;

    const { sessionId, role } = peerInfo;
    this.wsToPeer.delete(ws);

    const room = this.rooms.get(sessionId);
    if (!room) return;

    const otherPeer = role === 'host' ? room.guest : room.host;
    if (otherPeer && otherPeer.ws.readyState === WebSocket.OPEN) {
      this.send(otherPeer.ws, {
        type: 'peer-left',
        sessionId,
        senderRole: role,
      });
    }

    if (role === 'host') {
      delete room.host;
      // If host leaves, close the room completely after grace period (30 seconds)
      setTimeout(() => {
        if (!room.host) {
          this.closeRoom(sessionId);
        }
      }, 30000);
    } else {
      delete room.guest;
    }

    if (!room.host && !room.guest) {
      this.rooms.delete(sessionId);
    }
  }

  public closeRoom(sessionId: string): void {
    const room = this.rooms.get(sessionId);
    if (!room) return;

    [room.host, room.guest].forEach(peer => {
      if (peer && peer.ws.readyState === WebSocket.OPEN) {
        this.send(peer.ws, { type: 'room-closed', sessionId });
      }
    });

    this.rooms.delete(sessionId);
  }

  private cleanExpiredRooms(): void {
    const now = Date.now();
    for (const [sessionId, room] of this.rooms.entries()) {
      if (now > room.expiresAt) {
        this.closeRoom(sessionId);
      }
    }
  }

  public getStats() {
    return {
      activeRooms: this.rooms.size,
      connectedPeers: this.wsToPeer.size,
    };
  }

  public destroy(): void {
    clearInterval(this.cleanupInterval);
    this.rooms.clear();
    this.wsToPeer.clear();
  }

  private send(ws: WebSocket, response: ServerResponse): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(response));
    }
  }
}
