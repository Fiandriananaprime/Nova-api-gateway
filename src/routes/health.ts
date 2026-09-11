import type { FastifyInstance } from "fastify";
import { services } from "../config";

export async function healthRoutes(app: FastifyInstance) {
  app.get("/health", async () => {
    return {
      status: "ok",
      service: "nova-api-gateway",
      timestamp: new Date().toISOString(),
    };
  });

  app.get("/health/services", async () => {
    return {
      status: "ok",
      services: Object.keys(services),
      timestamp: new Date().toISOString(),
    };
  });
}