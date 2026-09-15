
import { FastifyInstance } from "fastify";
import { login, register } from "../service/auth.service";
import { createUserDto, requestLogin } from "../type/auth";

export  const authRoutes = async (app: FastifyInstance) => {
  app.post<{ Body: createUserDto }>(
    "/auth/register",
    async (request, reply) => {
      const user = await register(request.body);

      return reply.code(201).send(user);
    }
  );

  app.post<{Body:requestLogin}>(
    "/auth/login",
    async (request, reply) => {
        const { user, cookies } = await login(request.body);

        if (cookies.length > 0) {
          reply.header("set-cookie", cookies);
        }

        return reply.code(200).send(user)
    }
  )
}