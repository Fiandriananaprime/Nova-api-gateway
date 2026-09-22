import type { FastifyInstance } from "fastify";
import proxy from "@fastify/http-proxy";
import { services } from "../config/index.js";
import { proxyRoutes } from "./routes.js";
import { authenticate } from "../middleware/auth.middleware.js";

const API_PREFIX = "/api";

export const registerProxies = async (app: FastifyInstance) => {
  for (const route of proxyRoutes) {
    const upstream = services[route.service];

    if (!upstream) {
      app.log.warn(
        {
          service: route.service,
          prefix: route.prefix,
        },
        "Skipping proxy registration because service URL is not configured"
      );
      continue;
    }

    await app.register(proxy, {
      upstream,
      prefix: route.prefix,
      rewritePrefix: `${API_PREFIX}${route.prefix}`,
      preHandler: route.public ? undefined : authenticate,
    });
  }
};