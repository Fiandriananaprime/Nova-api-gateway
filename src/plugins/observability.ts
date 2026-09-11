import type { FastifyInstance, FastifyRequest } from "fastify";

const requestStartTime = Symbol("nova.request.startTime");

const getRequestMetadata = (request: FastifyRequest) => ({
  requestId: request.id,
  method: request.method,
  url: request.url,
  route: request.routeOptions?.url ?? request.url,
  ip: request.ip,
  userAgent: request.headers["user-agent"],
});

export async function registerObservability(app: FastifyInstance) {
  app.addHook("onRequest", async (request) => {
    Reflect.set(request, requestStartTime, Date.now());

    request.log.info(
      {
        ...getRequestMetadata(request),
        startedAt: new Date().toISOString(),
      },
      "request started"
    );
  });

  app.addHook("onResponse", async (request, reply) => {
    const startedAt = Number(Reflect.get(request, requestStartTime) ?? Date.now());
    const durationMs = Date.now() - startedAt;

    request.log.info(
      {
        ...getRequestMetadata(request),
        statusCode: reply.statusCode,
        durationMs,
        completedAt: new Date().toISOString(),
      },
      "request completed"
    );
  });
}
