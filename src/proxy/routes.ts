export type ServiceName =
  | "auth"
  | "user"
  | "product"
  | "store"
  | "order"
  | "payment"
  | "delivery"
  | "admin"
  | "notification";

export interface ProxyRoute {
  prefix: string;
  service: ServiceName;
}

export const proxyRoutes: ProxyRoute[] = [
  { prefix: "/auth", service: "auth" },

  { prefix: "/account/notifications", service: "notification" },
  { prefix: "/account/sessions", service: "auth"},
  { prefix: "/account/security", service:"auth"},
  { prefix:"/account/settings", service:"auth"},
  {prefix:"/account/email",service:"auth"},
  {prefix:"/account/password",service:"auth"},
  { prefix: "/account", service: "user" },

  { prefix: "/buyer/notifications/preferences", service: "user" },
  { prefix: "/buyer/payment-methods", service: "payment" },
  { prefix: "/buyer/profile", service: "user" },
  { prefix: "/buyer/addresses", service: "user" },
  { prefix: "/buyer/preferences", service: "user" },

  { prefix: "/seller/notifications/preferences", service: "user" },
  { prefix: "/seller/store/policies", service: "store" },
  { prefix: "/seller/payout-methods", service: "payment" },
  { prefix: "/seller/payouts", service: "payment" },
  { prefix: "/seller/business", service: "store" },
  { prefix: "/seller/verification", service: "store" },
  { prefix: "/seller/products", service: "product" },
  { prefix: "/seller/inventory", service: "product" },
  { prefix: "/seller/orders", service: "order" },
  { prefix: "/seller/balance", service: "payment" },
  { prefix: "/seller/dashboard", service: "store" },
  { prefix: "/seller/analytics", service: "store" },
  { prefix: "/seller/reviews", service: "product" },
  { prefix: "/seller/promotions", service: "product" },
  { prefix: "/seller/customers", service: "user" },
  { prefix: "/seller/profile", service: "user" },
  { prefix: "/seller/settings", service: "user" },

  { prefix: "/admin/orders/:id/tracking", service: "delivery" },
  { prefix: "/admin/notifications/preferences", service: "user" },
  { prefix: "/admin/sellers/applications", service: "admin" },
  { prefix: "/admin/delivery/agents", service: "delivery" },
  { prefix: "/admin/payments", service: "payment" },
  { prefix: "/admin/products", service: "product" },
  { prefix: "/admin/categories", service: "product" },
  { prefix: "/admin/promotions", service: "product" },
  { prefix: "/admin/reviews", service: "product" },
  { prefix: "/admin/audit-logs", service: "admin" },
  { prefix: "/admin/events", service: "admin" },
  { prefix: "/admin/reports", service: "admin" },
  { prefix: "/admin/users", service: "admin" },
  { prefix: "/admin/admins", service: "admin" },
  { prefix: "/admin/orders", service: "order" },
  { prefix: "/admin/profile", service: "user" },
  { prefix: "/admin/settings", service: "user" },
  { prefix: "/admin/security", service: "user" },

  { prefix: "/moderator/inventory", service: "product" },
  { prefix: "/moderator/products", service: "product" },

  { prefix: "/orders/:id/tracking", service: "delivery" },
  { prefix: "/orders", service: "order" },

  { prefix: "/favorites/products", service: "user" },
  { prefix: "/favorites/stores", service: "user" },

  { prefix: "/checkout", service: "order" },
  { prefix: "/cart", service: "order" },

  { prefix: "/delivery", service: "delivery" },

  { prefix: "/categories", service: "product" },
  { prefix: "/products", service: "product" },
  { prefix: "/stores", service: "store" },
];