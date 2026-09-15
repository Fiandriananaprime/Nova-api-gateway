import type { FastifyError, FastifyInstance } from "fastify";
import type { Error } from "@Fiandriananaprime/nova_api_type";
import axios from "axios";

export function registerErrorHandler(app: FastifyInstance) {
  app.setErrorHandler((error: FastifyError, request, reply) => {
    request.log.error(error);

    if (axios.isAxiosError(error)) {
      const statusCode = error.response?.status ?? 502;
      const upstreamResponse = error.response?.data;

      if (upstreamResponse && typeof upstreamResponse === "object") {
        return reply.status(statusCode).send(upstreamResponse);
      }

      return reply.status(statusCode).send({
        error: {
          code: "UPSTREAM_SERVICE_ERROR",
          message:
            typeof upstreamResponse === "string"
              ? upstreamResponse
              : "The upstream service request failed.",
        },
      });
    }

    if (error.validation) {
      const response: Error = {
        error: {
            code: "VALIDATION_ERROR",
            message: "The request is invalid.",
            details: error.validation.map((item) => ({
            field:
                item.instancePath ||
                (typeof item.params?.missingProperty === "string"
                ? item.params.missingProperty
                : undefined),
            message: item.message,
            })),
        },
      };

      return reply.status(400).send(response);
    }

    if (error.statusCode && error.statusCode < 500) {
      const response: Error = {
        error: {
          code: error.code || "REQUEST_ERROR",
          message: error.message,
        },
      };

      return reply.status(error.statusCode).send(response);
    }

    const response: Error = {
      error: {
        code: "INTERNAL_SERVER_ERROR",
        message: "An unexpected error occurred.",
      },
    };

    return reply.status(500).send(response);
  });
}