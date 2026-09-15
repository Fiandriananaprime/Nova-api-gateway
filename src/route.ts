import { FastifyInstance } from "fastify";
import { authRoutes } from "./routes/auth.route";

export const registerRoutes = async (app: FastifyInstance) => {
  await app.register(authRoutes);
}