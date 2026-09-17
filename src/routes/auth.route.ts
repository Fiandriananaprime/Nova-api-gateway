
import { FastifyInstance } from "fastify";
import { authenticate } from "../middleware/auth.middleware";
import { AdminController} from "../controller/admin"
import { createApplication } from "../type/admin";

export  const authRoutes = async (app: FastifyInstance) => {
    const adminController = new AdminController();
    
    app.register((router) => {
        router.post<{Body:createApplication}>(
            "/auth/register/seller",
            {preHandler:authenticate},
            adminController.registerSeller.bind(adminController)
        )
    })

}