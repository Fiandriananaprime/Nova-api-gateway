import { FastifyReply, FastifyRequest } from "fastify";
import { storeClient } from "../clients/store.client";

export type storeQuery = {
    page?: number,
    limit?:number,
    search?: string,
    location?:string
}
export class PublicController {
    async getAllProducts(request: FastifyRequest<{Querystring: storeQuery}>,reply:FastifyReply){
        const {page = 1,limit = 20,search,location} = request.query
        const userId = request.userId ?? undefined;

        const response = await storeClient.getProducts(page,limit,search,location,userId)
        return reply.status(response.status).send(response.data)
    }
}