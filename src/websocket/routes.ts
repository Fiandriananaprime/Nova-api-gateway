import type { FastifyInstance } from "fastify";
import type WebSocket from "ws";

import { services } from "../config";
import { proxyWebSocket } from "./proxy";

export async function websocketRoutes(app: FastifyInstance) {
  app.get<{ Params: { id: string } }>(
    "/ws/orders/:id",
    {
      websocket: true,
    },
    (socket, request) => {
      const upstream = services.order;

      if (!upstream) {
        socket.close(1011, "Order service unavailable");
        return;
      }

      proxyWebSocket(
        socket as WebSocket,
        `${upstream}/ws/orders/${request.params.id}`,
      );
    },
  );

  app.get<{ Params: { id: string } }>(
    "/ws/orders/:id/tracking",
    {
      websocket: true,
    },
    (socket, request) => {
      const upstream = services.delivery;

      if (!upstream) {
        socket.close(1011, "Delivery service unavailable");
        return;
      }

      proxyWebSocket(
        socket as WebSocket,
        `${upstream}/ws/orders/${request.params.id}/tracking`,
      );
    },
  );

  app.get<{ Params: { id: string } }>(
    "/ws/admin/orders/:id/tracking",
    {
      websocket: true,
    },
    (socket, request) => {
      const upstream = services.delivery;

      if (!upstream) {
        socket.close(1011, "Delivery service unavailable");
        return;
      }

      proxyWebSocket(
        socket as WebSocket,
        `${upstream}/ws/admin/orders/${request.params.id}/tracking`,
      );
    },
  );
}