import Fastify from "fastify";
import {  registerCors, registerCookie, registerHelmet} from "./plugins";
import { healthRoutes } from "./routes/health";
import { registerProxies } from "./proxy";

 const buildApp = () => {
  const app = Fastify({
    logger: true,
  });

  app.register(registerCors);
  app.register(registerCookie);
  app.register(registerHelmet);

  app.register(healthRoutes);
  app.register(registerProxies);
  return app;
}

export default buildApp;