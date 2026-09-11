import websocket from "@fastify/websocket";
import type { FastifyInstance } from "fastify";

export async function registerWebSocket(app: FastifyInstance) {
  await app.register(websocket, {
    options: {
      maxPayload: 1024 * 1024,
    },
  });
}