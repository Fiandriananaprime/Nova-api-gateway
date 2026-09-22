import { createSellerApplication } from "../type/admin";
import { http } from "./axios";
import { services } from "../config";

const BASE_URL = services.admin 

class AdminClient {
    private readonly baseUrl = BASE_URL;

    async registerSeller (data : createSellerApplication){
        return http.post(`${this.baseUrl}/api/register/seller`,data)
    }
}

export const adminClient = new AdminClient()