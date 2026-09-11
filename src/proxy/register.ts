import type { FastifyInstance } from "fastify";
import proxy from "@fastify/http-proxy";
import { services } from "../config";
import { proxyRoutes } from "./routes";

export const registerProxies = async (app: FastifyInstance) => {
  for (const route of proxyRoutes) {
    const upstream = services[route.service];

    if (!upstream) {
      throw new Error(
        `No service URL configured for "${route.service}"`
      );
    }

    await app.register(proxy, {
      upstream,
      prefix: route.prefix,
      rewritePrefix: "",
    });
  }
}