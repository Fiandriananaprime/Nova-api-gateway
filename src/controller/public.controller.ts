import { FastifyReply, FastifyRequest } from "fastify";
import { storeClient } from "../clients/store.client";

export type storeQuery = {
    page?: number,
    limit?:number,
    search?: string,
    location?:string
}
export class PublicController {
    async getAllProducts(request: FastifyRequest<{ Params:{id:string};}>,reply:FastifyReply){
        const {id} = request.params
        const userId = request.userId ?? undefined;

        const response = await storeClient.getProducts(id,userId)
        return reply.status(response.status).send(response.data)
    }
}