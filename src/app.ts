import Fastify from "fastify";
import {
  registerCors,
  registerCookie,
  registerHelmet,
} from "./plugins";

 const buildApp = () => {
  const app = Fastify({
    logger: true,
  });

  app.register(registerCors);
  app.register(registerCookie);
  app.register(registerHelmet);

  return app;
}

export default buildApp;