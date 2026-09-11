import Fastify from "fastify";
import {  registerCors, registerCookie, registerHelmet} from "./plugins";
import { healthRoutes } from "./routes/health";

 const buildApp = () => {
  const app = Fastify({
    logger: true,
  });

  app.register(registerCors);
  app.register(registerCookie);
  app.register(registerHelmet);

  app.register(healthRoutes);

  return app;
}

export default buildApp;