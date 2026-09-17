import { FastifyInstance } from "fastify";
import { authRoutes } from "./routes/auth.route.js";

export const registerRoutes = async (app: FastifyInstance) => {
  await app.register(authRoutes);
}