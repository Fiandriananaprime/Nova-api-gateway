import { http } from "./axios";
import { services } from "../config";

const BASE_URL = services.store

class StoreClient {
    private readonly baseUrl = BASE_URL

    async getProducts(page:number,limit:number,search?:string,location?:string,userId?:string,){
        return http.get(`${this.baseUrl}/api/stores`, {
            params:{page,limit,search,location},
             headers: userId? {"X-User-Id": userId} : undefined
            })
    }
}

export const storeClient = new StoreClient()