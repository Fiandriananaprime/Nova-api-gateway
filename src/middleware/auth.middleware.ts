import { FastifyReply, FastifyRequest } from "fastify";
import { AuthClient } from "../clients/auth.client";

const authClient = new AuthClient();
export const authenticate = async (request:FastifyRequest,reply:FastifyReply) => {
    const accessToken = request.cookies.access_token;
    if(!accessToken) throw new Error("Unauthorized");

    const session = await authClient.validateSession(accessToken);

    request.userId = session.userId
}