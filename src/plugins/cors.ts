import cors from "@fastify/cors";
import type { FastifyInstance } from "fastify";
import { env } from "../config/index.js";

export async function registerCors(app: FastifyInstance) {
  await app.register(cors, {
    origin: [
      env.clientFrontendUrl,
      env.sellerFrontendUrl,
      env.adminFrontendUrl,
    ].filter(Boolean) as string[],
    credentials: true,
  });
}