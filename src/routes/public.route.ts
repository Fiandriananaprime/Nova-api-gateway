import { FastifyInstance } from "fastify";
import { PublicController, storeQuery } from "../controller/public.controller";
import { authenticateOptional } from "../middleware/auth.middleware";

export const PublicRoute = ( app: FastifyInstance ) => {
    const publicController = new PublicController()

    app.register((route) => {
        route.get<{ Params:{id:string}}>("/stores/:id",{preHandler:authenticateOptional},publicController.getAllProducts.bind(publicController))
    })
}