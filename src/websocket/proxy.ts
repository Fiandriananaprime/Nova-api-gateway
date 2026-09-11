import WebSocket from "ws";

function toWebSocketUrl(url: string) {
  return url
    .replace(/^http:\/\//, "ws://")
    .replace(/^https:\/\//, "wss://");
}

export function proxyWebSocket(
  client: WebSocket,
  upstreamUrl: string,
  headers?: Record<string, string>,
) {
  const upstream = new WebSocket(
    toWebSocketUrl(upstreamUrl),
    {
      headers,
    },
  );

  upstream.on("open", () => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(
        JSON.stringify({
          type: "connected",
        }),
      );
    }
  });

  client.on("message", (message, isBinary) => {
    if (upstream.readyState === WebSocket.OPEN) {
      upstream.send(message, {
        binary: isBinary,
      });
    }
  });

  upstream.on("message", (message, isBinary) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message, {
        binary: isBinary,
      });
    }
  });

  client.on("close", () => {
    if (
      upstream.readyState === WebSocket.OPEN ||
      upstream.readyState === WebSocket.CONNECTING
    ) {
      upstream.close();
    }
  });

  upstream.on("close", () => {
    if (
      client.readyState === WebSocket.OPEN ||
      client.readyState === WebSocket.CONNECTING
    ) {
      client.close();
    }
  });

  client.on("error", () => {
    if (
      upstream.readyState === WebSocket.OPEN ||
      upstream.readyState === WebSocket.CONNECTING
    ) {
      upstream.close();
    }
  });

  upstream.on("error", () => {
    if (client.readyState === WebSocket.OPEN) {
      client.close(1011, "Upstream WebSocket error");
    }
  });
}