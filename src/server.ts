import buildApp from "./app.js";
import { env } from "./config/index.js";

const app = buildApp();

app.listen({
  host: env.host,
  port: env.port,
}).catch((error) => {
  app.log.error(error);
  process.exit(1);
});