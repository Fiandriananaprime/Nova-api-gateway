import { describe, expect, it, vi } from "vitest";

import buildApp from "./app";

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
    expect(infoSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        method: "GET",
        url: "/health",
      }),
      "request started"
    );
    expect(infoSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        method: "GET",
        url: "/health",
        statusCode: 200,
      }),
      "request completed"
    );
  });
});
