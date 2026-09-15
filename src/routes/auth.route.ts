
import { FastifyInstance } from "fastify";
import { register } from "../service/auth.service";
import { createUserDto } from "../type/auth";

export  const authRoutes = async (app: FastifyInstance) => {
  app.post<{ Body: createUserDto }>(
    "/auth/register",
    async (request, reply) => {
      const user = await register(request.body);

      return reply.code(201).send(user);
    }
  );
}