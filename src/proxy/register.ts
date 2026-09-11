import type { FastifyInstance } from "fastify";
import proxy from "@fastify/http-proxy";
import { services } from "../config";
import { proxyRoutes } from "./routes";

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
      rewritePrefix: "",
    });
  }
}