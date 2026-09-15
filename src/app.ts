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
} from "./plugins";

import { registerRoutes } from "./route";
import { registerProxies } from "./proxy";

import {
  registerWebSocket,
  websocketRoutes,
} from "./websocket";
import { registerErrorHandler } from "./errors/error-handler";

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