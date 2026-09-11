import cookie from "@fastify/cookie";
import type { FastifyInstance } from "fastify";
import { env } from "../config";

export async function registerCookie(app: FastifyInstance) {
  await app.register(cookie, {
    secret: env.cookieSecret || undefined,
  });
}