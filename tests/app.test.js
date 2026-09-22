import { describe, expect, it, vi } from "vitest";
import buildApp from "../src/app";
describe("request observability", () => {
    it("logs request lifecycle information", async () => {
        const app = buildApp();
        const infoSpy = vi.spyOn(app.log, "info");
        await app.ready();
        const response = await app.inject({
            method: "GET",
            url: "/health",
        });
        expect(response.statusCode).toBe(200);
        expect(infoSpy).toHaveBeenCalledWith(expect.objectContaining({
            method: "GET",
            url: "/health",
        }), "request started");
        expect(infoSpy).toHaveBeenCalledWith(expect.objectContaining({
            method: "GET",
            url: "/health",
            statusCode: 200,
        }), "request completed");
    });
    it("starts even when some upstream service URLs are not configured", async () => {
        const app = buildApp();
        await expect(app.ready()).resolves.toBeUndefined();
    });
});
