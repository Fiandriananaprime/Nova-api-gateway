import WebSocket from "ws";

function toWebSocketUrl(url: string) {
  return url
    .replace(/^http:\/\//, "ws://")
    .replace(/^https:\/\//, "wss://");
}

export function proxyWebSocket(
  client: WebSocket,
  upstreamUrl: string,
) {
  const upstream = new WebSocket(toWebSocketUrl(upstreamUrl));

  upstream.on("open", () => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(
        JSON.stringify({
          type: "connected",
        }),
      );
    }
  });

  client.on("message", (message) => {
    if (upstream.readyState === WebSocket.OPEN) {
      upstream.send(message);
    }
  });

  upstream.on("message", (message) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
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
    upstream.close();
  });

  upstream.on("error", () => {
    if (client.readyState === WebSocket.OPEN) {
      client.close(1011, "Upstream WebSocket error");
    }
  });
}