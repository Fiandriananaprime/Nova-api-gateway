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
  rewritePrefix?: string;
  public?: boolean;
  optionalAuth?: boolean;
  csrf?: boolean;
}

export const proxyRoutes: ProxyRoute[] = [
  {
    prefix: "/auth/register/seller",
    service: "admin",
    rewritePrefix: "/internal/seller",
  },
  { prefix: "/auth", service: "auth", public: true },

  { prefix: "/account/notifications", service: "notification", csrf: true },
  { prefix: "/account/sessions", service: "auth", csrf: true },
  { prefix: "/account/security", service: "auth", csrf: true },
  { prefix: "/account/phone", service: "auth", csrf: true },
  { prefix: "/account/settings", service: "auth", csrf: true },
  { prefix: "/account/email", service: "auth", csrf: true },
  { prefix: "/account/password", service: "auth", csrf: true },
  { prefix: "/account", service: "user", csrf: true },

  { prefix: "/buyer/notifications/preferences", service: "user", csrf: true },
  { prefix: "/buyer/payment-methods", service: "payment", csrf: true },
  { prefix: "/buyer/profile", service: "user", csrf: true },
  { prefix: "/buyer/addresses", service: "user", csrf: true },
  { prefix: "/buyer/preferences", service: "user", csrf: true },

  { prefix: "/seller/notifications/preferences", service: "user", csrf: true },
  { prefix: "/seller/store/policies", service: "store", csrf: true },
  { prefix: "/seller/payout-methods", service: "payment", csrf: true },
  { prefix: "/seller/payouts", service: "payment", csrf: true },
  { prefix: "/seller/business", service: "store", csrf: true },
  { prefix: "/seller/verification", service: "store", csrf: true },
  { prefix: "/seller/products", service: "product", csrf: true },
  { prefix: "/seller/inventory", service: "product", csrf: true },
  { prefix: "/seller/orders", service: "order", csrf: true },
  { prefix: "/seller/balance", service: "payment", csrf: true },
  { prefix: "/seller/dashboard", service: "store", csrf: true },
  { prefix: "/seller/analytics", service: "store", csrf: true },
  { prefix: "/seller/reviews", service: "product", csrf: true },
  { prefix: "/seller/promotions", service: "product", csrf: true },
  { prefix: "/seller/customers", service: "user", csrf: true },
  { prefix: "/seller/profile", service: "user", csrf: true },
  { prefix: "/seller/settings", service: "user", csrf: true },

  { prefix: "/admin/orders/:id/tracking", service: "delivery", csrf: true },
  { prefix: "/admin/notifications/preferences", service: "user", csrf: true },
  { prefix: "/admin/sellers/applications", service: "admin", csrf: true },
  { prefix: "/admin/delivery/agents", service: "delivery", csrf: true },
  { prefix: "/admin/payments", service: "payment", csrf: true },
  { prefix: "/admin/products", service: "product", csrf: true },
  { prefix: "/admin/categories", service: "product", csrf: true },
  { prefix: "/admin/promotions", service: "product", csrf: true },
  { prefix: "/admin/reviews", service: "product", csrf: true },
  { prefix: "/admin/audit-logs", service: "admin", csrf: true },
  { prefix: "/admin/events", service: "admin", csrf: true },
  { prefix: "/admin/reports", service: "admin", csrf: true },
  { prefix: "/admin/users", service: "admin", csrf: true },
  { prefix: "/admin/admins", service: "admin", csrf: true },
  { prefix: "/admin/orders", service: "order", csrf: true },
  { prefix: "/admin/profile", service: "user", csrf: true },
  { prefix: "/admin/settings", service: "user", csrf: true },
  { prefix: "/admin/security", service: "user", csrf: true },

  { prefix: "/moderator/inventory", service: "product", csrf: true },
  { prefix: "/moderator/products", service: "product", csrf: true },

  { prefix: "/orders/:id/tracking", service: "delivery", csrf: true },
  { prefix: "/orders", service: "order", csrf: true },

  { prefix: "/favorites/products", service: "user", csrf: true },
  { prefix: "/favorites/stores", service: "user", csrf: true },

  { prefix: "/checkout", service: "order", csrf: true },
  { prefix: "/cart", service: "order", csrf: true },

  { prefix: "/delivery", service: "delivery", csrf: true },

  { prefix: "/categories", service: "store", public: true },
  { prefix: "/products", service: "product", public: true },
  { prefix: "/stores/:id/products", service:"product", public: true },
  { prefix: "/stores/:id/reviews", service: "product", public: true },
  { prefix: "/stores/:id/follow", service: "store", csrf: true },
  { prefix: "/stores", service: "store", public: true, optionalAuth: true },
];