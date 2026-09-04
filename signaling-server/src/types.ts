import { WebSocket } from 'ws';

export type PeerRole = 'host' | 'guest';

export interface PeerConnection {
  ws: WebSocket;
  role: PeerRole;
  sessionId: string;
  joinedAt: number;
}

export interface EphemeralRoom {
  sessionId: string;
  createdAt: number;
  expiresAt: number;
  host?: PeerConnection;
  guest?: PeerConnection;
  messageCount: number;
}

export type ClientAction = 
  | 'join' 
  | 'offer' 
  | 'answer' 
  | 'candidate' 
  | 'ice-restart'
  | 'leave' 
  | 'ping';

export interface SignalMessage {
  action: ClientAction;
  sessionId: string;
  role?: PeerRole;
  payload?: any; // Encrypted SDP or encrypted Candidate
}

export interface ServerResponse {
  type: 'joined' | 'peer-joined' | 'peer-left' | 'signal' | 'error' | 'pong' | 'room-closed';
  sessionId?: string;
  senderRole?: PeerRole;
  payload?: any;
  message?: string;
}
