import { FastifyRequest } from "fastify";
import { AuthClient } from "../clients/auth.client";

const authClient = new AuthClient();

const getCookieValue = (request: FastifyRequest, name: string) => {
  const parsedValue = request.cookies?.[name];
  if (parsedValue) return parsedValue;

  const rawCookie = request.headers.cookie;
  if (!rawCookie) return undefined;

  const cookie = rawCookie
    .split(";")
    .map((part) => part.trim())
    .find((part) => part.startsWith(`${name}=`));

  return cookie ? decodeURIComponent(cookie.slice(name.length + 1)) : undefined;
};

export const getAccessToken = (request: FastifyRequest) => {
  const cookieToken = getCookieValue(request, "access_token");
  if (cookieToken) return cookieToken;

  const authorization = request.headers.authorization;
  if (authorization?.startsWith("Bearer ")) {
    return authorization.slice("Bearer ".length).trim();
  }

  return undefined;
};

const unauthorized = (message = "Unauthorized") => {
  const error = new Error(message) as Error & { statusCode: number; code: string };
  error.statusCode = 401;
  error.code = "UNAUTHORIZED";
  return error;
};

export const authenticate = async (request:FastifyRequest) => {
    const accessToken = getAccessToken(request);
    if(!accessToken) throw unauthorized();

    const session = await authClient.validateSession(accessToken);

    request.userId = session.userId
}

export const authenticateOptional = async (request: FastifyRequest) => {
  const accessToken = getAccessToken(request);

  if (!accessToken) {
    request.userId = null;
    return;
  }

  const session = await authClient.validateSession(accessToken);

  request.userId = session.userId;
};