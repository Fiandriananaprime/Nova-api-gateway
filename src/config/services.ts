import "dotenv/config";

export const services = {
  auth: process.env.AUTH_SERVICE_URL,
  user: process.env.USER_SERVICE_URL,
  product: process.env.PRODUCT_SERVICE_URL,
  store: process.env.STORE_SERVICE_URL,
  order: process.env.ORDER_SERVICE_URL,
  payment: process.env.PAYMENT_SERVICE_URL,
  notification: process.env.NOTIFICATION_SERVICE_URL,
  delivery: process.env.DELIVERY_SERVICE_URL,
  tracking: process.env.TRACKING_SERVICE_URL,
};