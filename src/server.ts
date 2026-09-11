import  buildApp  from "./app";
import { env } from "./config";

const app = buildApp();

app.listen({
  host: env.host,
  port: env.port,
}).catch((error) => {
  app.log.error(error);
  process.exit(1);
});