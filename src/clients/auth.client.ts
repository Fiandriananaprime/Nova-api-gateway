
import { services } from "../config"
import { http } from "./axios"

const BASE_URL = services.auth

export class AuthClient {
    private readonly baseUrl = BASE_URL

    async validateSession(accessToken: string) {
      const session = await http.post(`${this.baseUrl}/internal/validate`,{access_token:accessToken})
      return session.data
    }

    async validateCsrf(accessToken: string, csrfToken: string): Promise<boolean> {
      const response = await http.post(`${this.baseUrl}/internal/validate-csrf`, {
        access_token: accessToken,
        csrf_token: csrfToken,
      });

      return response.data.valid === true;
    }
}