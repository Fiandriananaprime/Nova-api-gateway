import "dotenv/config";

export const env = {
  nodeEnv: process.env.NODE_ENV || "development",

  host: process.env.HOST || "0.0.0.0",
  port: Number(process.env.PORT) || 3000,

  clientFrontendUrl: process.env.CLIENT_FRONTEND_URL,
  sellerFrontendUrl: process.env.SELLER_FRONTEND_URL,
  adminFrontendUrl: process.env.ADMIN_FRONTEND_URL,

  cookieSecret: process.env.COOKIE_SECRET || "",

  logLevel: process.env.LOG_LEVEL || "info",
};