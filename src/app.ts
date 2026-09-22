import Fastify from "fastify";

import { 
  registerHealth, 
  registerVersion,registerMetrics 
} from "@Fiandriananaprime/service-core";

import {
  registerCors,
  registerCookie,
  registerHelmet,
  registerObservability,
} from "./plugins/index.js";

import { registerRoutes } from "./route.js";
import { registerProxies } from "./proxy/index.js";

import {
  registerWebSocket,
  websocketRoutes,
} from "./websocket/index.js";
import { registerErrorHandler } from "./errors/error-handler.js";

const buildApp = () => {
  const app = Fastify({
    logger: true,
  });

  app.register(registerCors);
  app.register(registerCookie);
  app.register(registerHelmet);
  app.register(registerObservability);
  registerErrorHandler(app);

  app.register(registerWebSocket);
  app.register(websocketRoutes);

  app.register(registerRoutes);
  app.register(registerProxies);

  registerHealth(app);

registerVersion(app, {
  service: "gateway portal",
  version: process.env["SERVICE_VERSION"] ?? "unknown",
  commit: process.env["GIT_COMMIT"] ?? "unknown"
});

registerMetrics(app);

  return app;
};

export default buildApp;