import { FastifyRequest,FastifyReply} from "fastify";

import { adminClient } from "../clients/admin.client"
import { createApplication } from "../type/admin";

export class AdminController {
    
    async registerSeller (request:FastifyRequest<{Body:createApplication}>,reply:FastifyReply)  {
        const response = await adminClient.registerSeller({
            ...request.body,
            userId:request.userId,
        });
    
        return reply.status(response.status).send(response.data)
    }
}