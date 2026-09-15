import { createUserDto, requestLogin } from "../type/auth";
import { http } from "../clients/axios";
import { services } from "../config";
import { User } from "@Fiandriananaprime/nova_api_type";

export const register = async (data: createUserDto): Promise<User> => {
    const response = await http.post(
        `${services.auth}/api/auth/register`,data
    )
    return response.data
}

export const login = async (data: requestLogin): Promise<{
    user: User;
    cookies: string[];
}> => {
    const response = await http.post(
        `${services.auth}/api/auth/login`,data
    )
    return {
        user: response.data,
        cookies: response.headers["set-cookie"] ?? [],
    }
}
