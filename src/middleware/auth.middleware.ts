import { FastifyRequest } from "fastify";
import { AuthClient } from "../clients/auth.client";

const authClient = new AuthClient();

const unauthorized = (message = "Unauthorized") => {
  const error = new Error(message) as Error & { statusCode: number; code: string };
  error.statusCode = 401;
  error.code = "UNAUTHORIZED";
  return error;
};

export const authenticate = async (request:FastifyRequest) => {
    const accessToken = request.cookies.access_token;
    if(!accessToken) throw unauthorized();

    const session = await authClient.validateSession(accessToken);

    request.userId = session.userId
}

export const authenticateOptional = async (request: FastifyRequest) => {
  const accessToken = request.cookies.access_token;

  if (!accessToken) {
    request.userId = null;
    return;
  }

  const session = await authClient.validateSession(accessToken);

  request.userId = session.userId;
};