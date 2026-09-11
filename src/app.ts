import Fastify from "fastify";

import {
  registerCors,
  registerCookie,
  registerHelmet,
} from "./plugins";

import { healthRoutes } from "./routes/health";
import { registerProxies } from "./proxy";

import {
  registerWebSocket,
  websocketRoutes,
} from "./websocket";

const buildApp = () => {
  const app = Fastify({
    logger: true,
  });

  app.register(registerCors);
  app.register(registerCookie);
  app.register(registerHelmet);

  app.register(registerWebSocket);
  app.register(websocketRoutes);

  app.register(healthRoutes);
  app.register(registerProxies);

  return app;
};

export default buildApp;