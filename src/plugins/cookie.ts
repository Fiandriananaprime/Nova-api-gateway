import cookie from "@fastify/cookie";
import type { FastifyInstance } from "fastify";
import { env } from "../config/index.js";

export async function registerCookie(app: FastifyInstance) {
  await app.register(cookie, {
    secret: env.cookieSecret,
  });
}