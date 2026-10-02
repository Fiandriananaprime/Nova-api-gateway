import type { FastifyReply, FastifyRequest } from "fastify";
import { AuthClient } from "../clients/auth.client";
import { getAccessToken } from "./auth.middleware";

const authClient = new AuthClient();
const safeMethods = new Set(["GET", "HEAD", "OPTIONS"]);

export const requireCsrf = async (request: FastifyRequest, reply: FastifyReply) => {
  if (safeMethods.has(request.method)) return;

  const accessToken = getAccessToken(request);
  const csrfToken = request.headers["x-csrf-token"];

  if (!accessToken) {
    return reply.code(401).send({ error: "Unauthorized" });
  }

  if (typeof csrfToken !== "string" || csrfToken.length === 0) {
    return reply.code(403).send({ error: "CSRF token required" });
  }

  const valid = await authClient.validateCsrf(accessToken, csrfToken);

  if (!valid) {
    return reply.code(403).send({ error: "Invalid CSRF token" });
  }
};