-- ==========================================================================
-- Nova Market - PostgreSQL database schema
-- Derived from: openapi(2).yaml, OpenAPI 3.0.3, version 3.0.0
--
-- Target: PostgreSQL 15+
--
-- Design principles:
--   * OpenAPI schemas that represent persistent state become tables.
--   * Response-only/calculated DTOs (metrics, dashboard series, counts, names
--     resolved through joins, etc.) are intentionally not duplicated as tables.
--   * JSON/open-ended OpenAPI objects are stored as JSONB.
--   * API/public IDs that are explicitly strings (not uuid) remain text.
--   * Financial amounts use NUMERIC instead of floating point.
--   * Security secrets/tokens are represented by hashes or encrypted values,
--     never as plaintext passwords, card PANs, or raw recovery codes.
--
-- IMPORTANT CONTRACT NOTES (from the OpenAPI spec):
--   1) /auth/register/seller accepts SellerApplication but the schema does not
--      contain an applicant user id/email/password. seller_applications therefore
--      allows applicant_user_id to be NULL until the API contract is corrected.
--   2) Order.id is a string in OpenAPI (example ORD-2026-001), so orders.id is TEXT.
--   3) Product.status and ProductInput.status use different sets. products.status
--      therefore covers the union required by the endpoints.
--   4) Seller-order response counts mention shipped/refunded although OrderStatus
--      does not; no new canonical order status is invented here.
--   5) /seller/store/policies declares IdParam although the path has no {id}.
--
-- No application/business logic can be inferred safely from OpenAPI alone;
-- comments mark implementation choices where the contract is underspecified.
-- ==========================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- --------------------------------------------------------------------------
-- Common helper
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- --------------------------------------------------------------------------
-- 1. Identity, authentication and account security
-- --------------------------------------------------------------------------
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  phone TEXT,
  role TEXT NOT NULL CHECK (role IN ('buyer', 'seller', 'admin')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  admin_role TEXT,
  avatar_url TEXT,
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
  last_login_at TIMESTAMPTZ,
  last_login_ip INET,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT users_admin_role_consistency CHECK (
    (role = 'admin' AND admin_role IN ('super_admin', 'admin', 'moderator', 'delivery'))
    OR
    (role <> 'admin' AND admin_role IS NULL)
  )
);

CREATE UNIQUE INDEX ux_users_email_lower ON users (LOWER(email));
CREATE INDEX ix_users_role_status ON users (role, status);
CREATE INDEX ix_users_last_login_at ON users (last_login_at DESC);

CREATE TABLE user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token_hash TEXT NOT NULL,
  device TEXT NOT NULL,
  browser TEXT NOT NULL,
  operating_system TEXT NOT NULL,
  ip_address INET NOT NULL,
  location TEXT,
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  remember BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX ux_user_sessions_refresh_hash ON user_sessions (refresh_token_hash);
CREATE INDEX ix_user_sessions_user_active ON user_sessions (user_id, revoked_at, expires_at);

CREATE TABLE verification_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  channel TEXT NOT NULL CHECK (channel IN ('email', 'phone')),
  purpose TEXT NOT NULL CHECK (
    purpose IN ('email_verification', 'phone_verification', 'two_factor', 'email_change')
  ),
  destination TEXT,
  code_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_verification_codes_user_purpose ON verification_codes (user_id, purpose, expires_at);
CREATE INDEX ix_verification_codes_active ON verification_codes (code_hash, expires_at) WHERE consumed_at IS NULL;

CREATE TABLE password_reset_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX ux_password_reset_token_hash ON password_reset_tokens (token_hash);
CREATE INDEX ix_password_reset_user ON password_reset_tokens (user_id, expires_at);

CREATE TABLE two_factor_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  enabled BOOLEAN NOT NULL DEFAULT FALSE,
  secret_encrypted TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified_at TIMESTAMPTZ
);

CREATE TABLE two_factor_recovery_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  used_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX ux_recovery_code_hash ON two_factor_recovery_codes (code_hash);
CREATE INDEX ix_recovery_codes_user ON two_factor_recovery_codes (user_id, used_at);

CREATE TABLE csrf_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES user_sessions(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  used_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX ux_csrf_token_hash ON csrf_tokens (token_hash);
CREATE INDEX ix_csrf_tokens_session ON csrf_tokens (session_id, expires_at);

-- --------------------------------------------------------------------------
-- 2. Account/profile/preferences/notifications
-- --------------------------------------------------------------------------
CREATE TABLE user_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  recipient_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  street TEXT NOT NULL,
  district TEXT NOT NULL,
  city TEXT NOT NULL,
  region TEXT NOT NULL,
  postal_code TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  instructions TEXT,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT user_addresses_latitude_ck CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT user_addresses_longitude_ck CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

CREATE UNIQUE INDEX ux_user_default_address ON user_addresses(user_id) WHERE is_default;
CREATE INDEX ix_user_addresses_user ON user_addresses(user_id);

CREATE TABLE buyer_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  theme TEXT CHECK (theme IN ('light', 'dark', 'system')),
  lang TEXT CHECK (lang IN ('mg', 'fr', 'en')),
  preferred_delivery_method TEXT CHECK (preferred_delivery_method IN ('standard', 'express', 'pickup')),
  personalized_recommendations BOOLEAN,
  show_recently_viewed BOOLEAN,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE buyer_notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  order_created BOOLEAN NOT NULL DEFAULT TRUE,
  order_delivered BOOLEAN NOT NULL DEFAULT TRUE,
  order_pending BOOLEAN NOT NULL DEFAULT TRUE,
  order_cancelled BOOLEAN NOT NULL DEFAULT TRUE,
  payment BOOLEAN NOT NULL DEFAULT TRUE,
  promotions BOOLEAN NOT NULL DEFAULT TRUE,
  price_drops BOOLEAN NOT NULL DEFAULT TRUE,
  back_in_stock BOOLEAN NOT NULL DEFAULT TRUE,
  new_products BOOLEAN NOT NULL DEFAULT FALSE,
  followed_stores BOOLEAN NOT NULL DEFAULT FALSE,
  reviews BOOLEAN NOT NULL DEFAULT TRUE,
  recommendations BOOLEAN NOT NULL DEFAULT TRUE,
  email BOOLEAN NOT NULL DEFAULT FALSE,
  push BOOLEAN NOT NULL DEFAULT TRUE,
  sms BOOLEAN NOT NULL DEFAULT FALSE,
  frequency TEXT NOT NULL DEFAULT 'monthly' CHECK (frequency IN ('monthly', 'daily', 'weekly')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE privacy_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  profile_visibility TEXT CHECK (profile_visibility IN ('private', 'public')),
  activity_personalization BOOLEAN,
  analytics_consent BOOLEAN,
  marketing_consent BOOLEAN,
  data_sharing BOOLEAN,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE consent_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  marketing BOOLEAN,
  analytics BOOLEAN,
  personalization BOOLEAN,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('order', 'payment', 'promotion', 'review', 'seller', 'system', 'security')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::JSONB,
  read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_notifications_user_created ON notifications(user_id, created_at DESC);
CREATE INDEX ix_notifications_unread ON notifications(user_id, created_at DESC) WHERE read = FALSE;

CREATE TABLE admin_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  theme TEXT CHECK (theme IN ('light', 'dark', 'system')),
  lang TEXT CHECK (lang IN ('mg', 'fr', 'en')),
  email_notifications BOOLEAN,
  push_notifications BOOLEAN,
  security_alerts BOOLEAN,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE admin_notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  seller_applications BOOLEAN,
  product_moderation BOOLEAN,
  payment_failures BOOLEAN,
  fraud_alerts BOOLEAN,
  system_alerts BOOLEAN,
  user_reports BOOLEAN,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE seller_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  theme TEXT CHECK (theme IN ('light', 'dark', 'system')),
  lang TEXT CHECK (lang IN ('mg', 'fr', 'en')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE seller_notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  new_order BOOLEAN NOT NULL DEFAULT TRUE,
  order_cancelled BOOLEAN NOT NULL DEFAULT TRUE,
  low_stock BOOLEAN NOT NULL DEFAULT TRUE,
  product_approved BOOLEAN NOT NULL DEFAULT TRUE,
  product_rejected BOOLEAN NOT NULL DEFAULT TRUE,
  new_review BOOLEAN NOT NULL DEFAULT TRUE,
  payout BOOLEAN NOT NULL DEFAULT TRUE,
  seller_announcements BOOLEAN NOT NULL DEFAULT TRUE,
  email BOOLEAN NOT NULL DEFAULT TRUE,
  push BOOLEAN NOT NULL DEFAULT TRUE,
  sms BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE data_export_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'ready', 'failed', 'expired')),
  object_key TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ready_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  failure_reason TEXT
);

CREATE INDEX ix_data_export_jobs_user ON data_export_jobs(user_id, requested_at DESC);

-- --------------------------------------------------------------------------
-- 3. Catalog and stores
-- --------------------------------------------------------------------------
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  parent_id UUID REFERENCES categories(id) ON DELETE RESTRICT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_categories_parent ON categories(parent_id);
CREATE INDEX ix_categories_active ON categories(is_active);

CREATE TABLE stores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  logo_url TEXT,
  cover_url TEXT,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  rating NUMERIC(3,2) NOT NULL DEFAULT 0,
  reviews_count INTEGER NOT NULL DEFAULT 0,
  products_count INTEGER NOT NULL DEFAULT 0,
  location TEXT,
  followers_count INTEGER NOT NULL DEFAULT 0,
  description TEXT,
  phone TEXT,
  email TEXT,
  website TEXT,
  vacation_mode BOOLEAN NOT NULL DEFAULT FALSE,
  business_hours JSONB NOT NULL DEFAULT '{}'::JSONB,
  social_links JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT stores_rating_ck CHECK (rating BETWEEN 0 AND 5),
  CONSTRAINT stores_counts_ck CHECK (
    reviews_count >= 0 AND products_count >= 0 AND followers_count >= 0
  )
);

CREATE UNIQUE INDEX ux_stores_user ON stores(user_id);
CREATE UNIQUE INDEX ux_stores_slug_lower ON stores(LOWER(slug));
CREATE INDEX ix_stores_verified_location ON stores(verified, location);

CREATE TABLE store_policies (
  store_id UUID PRIMARY KEY REFERENCES stores(id) ON DELETE CASCADE,
  return_policy TEXT NOT NULL,
  refund_policy TEXT NOT NULL,
  cancellation_policy TEXT NOT NULL,
  privacy_policy TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- --------------------------------------------------------------------------
-- 4. Seller onboarding / KYC
-- --------------------------------------------------------------------------
CREATE TABLE seller_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  applicant_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'not_submitted' CHECK (
    status IN ('not_submitted', 'pending', 'approved', 'rejected')
  ),
  submitted_at TIMESTAMPTZ,
  verified_at TIMESTAMPTZ,
  comments TEXT,
  store_name TEXT,
  location TEXT,
  business_type TEXT CHECK (business_type IN ('individual', 'company')),
  tax_id TEXT,
  registration_number TEXT,
  approved_at TIMESTAMPTZ,
  approved_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_seller_applications_status ON seller_applications(status, submitted_at DESC);
CREATE INDEX ix_seller_applications_applicant ON seller_applications(applicant_user_id);

CREATE TABLE seller_application_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL REFERENCES seller_applications(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (
    type IN ('identity', 'business_registration', 'tax_document', 'bank_account')
  ),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  file_url TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  rejection_reason TEXT
);

CREATE INDEX ix_seller_application_documents_application ON seller_application_documents(application_id);
CREATE INDEX ix_seller_application_documents_status ON seller_application_documents(status);

CREATE TABLE seller_application_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL REFERENCES seller_applications(id) ON DELETE CASCADE,
  admin_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  action TEXT NOT NULL CHECK (action IN ('approved', 'rejected')),
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_seller_application_reviews_application ON seller_application_reviews(application_id, created_at DESC);

-- --------------------------------------------------------------------------
-- 5. Products, media, variants/specs and inventory
-- --------------------------------------------------------------------------
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  brand TEXT,
  description TEXT NOT NULL DEFAULT '',
  price NUMERIC(19,4) NOT NULL,
  rating NUMERIC(3,2) NOT NULL DEFAULT 0,
  reviews_count INTEGER NOT NULL DEFAULT 0,
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE RESTRICT,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  low_stock_threshold INTEGER NOT NULL DEFAULT 10,
  sku TEXT,
  tags TEXT[] NOT NULL DEFAULT '{}',
  specs JSONB NOT NULL DEFAULT '{}'::JSONB,
  variants JSONB NOT NULL DEFAULT '[]'::JSONB,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (
    status IN ('draft', 'active', 'inactive', 'pending', 'approved', 'rejected')
  ),
  views INTEGER NOT NULL DEFAULT 0,
  sold_count INTEGER NOT NULL DEFAULT 0,
  wishlist_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT products_price_ck CHECK (price >= 0),
  CONSTRAINT products_rating_ck CHECK (rating BETWEEN 0 AND 5),
  CONSTRAINT products_counts_ck CHECK (
    reviews_count >= 0 AND low_stock_threshold >= 0 AND views >= 0
    AND sold_count >= 0 AND wishlist_count >= 0
  )
);

CREATE INDEX ix_products_store_status ON products(store_id, status, created_at DESC);
CREATE INDEX ix_products_category ON products(category_id);
CREATE INDEX ix_products_price ON products(price);
CREATE INDEX ix_products_rating ON products(rating DESC);
CREATE INDEX ix_products_sku ON products(store_id, sku);
CREATE INDEX ix_products_tags_gin ON products USING GIN(tags);
CREATE INDEX ix_products_search_gin ON products USING GIN (
  to_tsvector('simple', COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(brand, ''))
);

CREATE TABLE product_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX ux_product_default_image ON product_images(product_id) WHERE is_default;
CREATE INDEX ix_product_images_product ON product_images(product_id, sort_order, id);

CREATE TABLE inventory (
  product_id UUID PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
  stock INTEGER NOT NULL DEFAULT 0,
  reserved INTEGER NOT NULL DEFAULT 0,
  threshold INTEGER NOT NULL DEFAULT 10,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT inventory_stock_ck CHECK (stock >= 0),
  CONSTRAINT inventory_reserved_ck CHECK (reserved >= 0),
  CONSTRAINT inventory_threshold_ck CHECK (threshold >= 0),
  CONSTRAINT inventory_reserved_le_stock_ck CHECK (reserved <= stock)
);

CREATE INDEX ix_inventory_low_stock ON inventory(stock, threshold);

CREATE TABLE inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  delta INTEGER NOT NULL,
  quantity_before INTEGER NOT NULL,
  quantity_after INTEGER NOT NULL,
  type TEXT NOT NULL CHECK (
    type IN ('manual', 'sale', 'reservation', 'release', 'audit', 'adjustment')
  ),
  reference_type TEXT,
  reference_id TEXT,
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT inventory_movements_quantities_ck CHECK (
    quantity_before >= 0 AND quantity_after >= 0
  )
);

CREATE INDEX ix_inventory_movements_product_date ON inventory_movements(product_id, created_at DESC);
CREATE INDEX ix_inventory_movements_reference ON inventory_movements(reference_type, reference_id);

CREATE TABLE inventory_audits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  expected_stock INTEGER NOT NULL,
  counted_stock INTEGER NOT NULL,
  difference INTEGER NOT NULL,
  reason TEXT,
  notes TEXT,
  moderator_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT inventory_audits_counted_ck CHECK (counted_stock >= 0),
  CONSTRAINT inventory_audits_difference_ck CHECK (difference = counted_stock - expected_stock)
);

CREATE INDEX ix_inventory_audits_product_date ON inventory_audits(product_id, created_at DESC);
CREATE INDEX ix_inventory_audits_moderator_date ON inventory_audits(moderator_id, created_at DESC);

CREATE TABLE product_moderation_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  actor_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  action TEXT NOT NULL CHECK (action IN ('approved', 'rejected')),
  reason TEXT,
  is_admin_override BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_product_moderation_history_product ON product_moderation_history(product_id, created_at DESC);

-- --------------------------------------------------------------------------
-- 6. Favorites / followed stores / category preferences
-- --------------------------------------------------------------------------
CREATE TABLE favorite_products (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, product_id)
);

CREATE INDEX ix_favorite_products_product ON favorite_products(product_id);

CREATE TABLE followed_stores (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, store_id)
);

CREATE INDEX ix_followed_stores_store ON followed_stores(store_id);

CREATE TABLE buyer_favorite_categories (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, category_id)
);

CREATE INDEX ix_buyer_favorite_categories_category ON buyer_favorite_categories(category_id);

-- --------------------------------------------------------------------------
-- 7. Saved payment methods
-- --------------------------------------------------------------------------
CREATE TABLE payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('card', 'mvola', 'orange_money')),
  provider TEXT,
  label TEXT,
  last4 TEXT,
  phone TEXT,
  provider_token_encrypted TEXT,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  expired BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX ux_payment_method_default ON payment_methods(user_id) WHERE is_default;
CREATE INDEX ix_payment_methods_user ON payment_methods(user_id, created_at DESC);

-- --------------------------------------------------------------------------
-- 8. Shopping cart
-- --------------------------------------------------------------------------
CREATE TABLE carts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE cart_items (
  cart_id UUID NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  qty INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (cart_id, product_id),
  CONSTRAINT cart_items_qty_ck CHECK (qty >= 1)
);

CREATE INDEX ix_cart_items_product ON cart_items(product_id);

-- --------------------------------------------------------------------------
-- 9. Promotions
-- --------------------------------------------------------------------------
CREATE TABLE promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('percentage', 'fixed')),
  discount NUMERIC(19,4) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (
    status IN ('active', 'scheduled', 'inactive', 'expired')
  ),
  code TEXT,
  minimum_order_amount NUMERIC(19,4),
  maximum_discount NUMERIC(19,4),
  usage_limit INTEGER,
  used_count INTEGER NOT NULL DEFAULT 0,
  is_automatic BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT promotions_discount_ck CHECK (discount >= 0),
  CONSTRAINT promotions_dates_ck CHECK (end_date >= start_date),
  CONSTRAINT promotions_percentage_ck CHECK (
    type <> 'percentage' OR discount <= 100
  ),
  CONSTRAINT promotions_amount_ck CHECK (
    (minimum_order_amount IS NULL OR minimum_order_amount >= 0)
    AND (maximum_discount IS NULL OR maximum_discount >= 0)
    AND (usage_limit IS NULL OR usage_limit >= 0)
    AND used_count >= 0
  )
);

CREATE UNIQUE INDEX ux_store_promotion_code_lower
  ON promotions(store_id, LOWER(code))
  WHERE code IS NOT NULL;
CREATE INDEX ix_promotions_store_dates ON promotions(store_id, start_date, end_date, status);

CREATE TABLE promotion_products (
  promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  PRIMARY KEY (promotion_id, product_id)
);

CREATE INDEX ix_promotion_products_product ON promotion_products(product_id);

CREATE TABLE promotion_usages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE RESTRICT,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  order_id TEXT,
  discount_amount NUMERIC(19,4) NOT NULL,
  used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT promotion_usages_discount_ck CHECK (discount_amount >= 0)
);

CREATE INDEX ix_promotion_usages_promotion ON promotion_usages(promotion_id, used_at DESC);
CREATE INDEX ix_promotion_usages_user ON promotion_usages(user_id, used_at DESC);

-- --------------------------------------------------------------------------
-- 10. Orders and order history
-- --------------------------------------------------------------------------
CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  buyer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  subtotal NUMERIC(19,4) NOT NULL,
  delivery_fee NUMERIC(19,4) NOT NULL DEFAULT 0,
  total NUMERIC(19,4) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'confirmed', 'processing', 'preparing', 'delivered', 'cancelled')
  ),
  delivery_method TEXT NOT NULL CHECK (delivery_method IN ('standard', 'express', 'pickup')),
  payment_method TEXT NOT NULL CHECK (payment_method IN ('mvola', 'orange_money', 'card', 'cod')),
  payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (
    payment_status IN ('pending', 'paid', 'failed', 'refunded', 'partially_refunded')
  ),
  estimated_delivery TIMESTAMPTZ,
  note TEXT,
  cancel_reason TEXT,
  delivery_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  discount_total NUMERIC(19,4) NOT NULL DEFAULT 0,
  CONSTRAINT orders_amounts_ck CHECK (
    subtotal >= 0 AND delivery_fee >= 0 AND total >= 0 AND discount_total >= 0
  )
);

CREATE INDEX ix_orders_buyer_status_date ON orders(buyer_id, status, created_at DESC);
CREATE INDEX ix_orders_status_date ON orders(status, created_at DESC);
CREATE INDEX ix_orders_delivery_id ON orders(delivery_id);

CREATE TABLE order_addresses (
  order_id TEXT PRIMARY KEY REFERENCES orders(id) ON DELETE CASCADE,
  label TEXT,
  recipient_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  street TEXT NOT NULL,
  district TEXT NOT NULL,
  city TEXT NOT NULL,
  region TEXT NOT NULL,
  postal_code TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  instructions TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT order_addresses_latitude_ck CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT order_addresses_longitude_ck CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  image TEXT,
  price NUMERIC(19,4) NOT NULL,
  qty INTEGER NOT NULL,
  seller_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  seller_name TEXT NOT NULL,
  CONSTRAINT order_items_price_ck CHECK (price >= 0),
  CONSTRAINT order_items_qty_ck CHECK (qty >= 1)
);

CREATE INDEX ix_order_items_order ON order_items(order_id);
CREATE INDEX ix_order_items_product ON order_items(product_id);
CREATE INDEX ix_order_items_seller ON order_items(seller_id, order_id);

-- Add the promotion -> order FK now that orders exists. The OpenAPI schema
-- exposes orderId only in the usage/history layer, not in Promotion itself.
ALTER TABLE promotion_usages
  ADD CONSTRAINT fk_promotion_usages_order
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL;

CREATE TABLE order_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  old_status TEXT CHECK (old_status IS NULL OR old_status IN ('pending', 'confirmed', 'processing', 'preparing', 'delivered', 'cancelled')),
  new_status TEXT NOT NULL CHECK (new_status IN ('pending', 'confirmed', 'processing', 'preparing', 'delivered', 'cancelled')),
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  tracking TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_order_status_history_order ON order_status_history(order_id, created_at DESC);

-- order_id is already referenced by a few tables above; delivery FK is added
-- after deliveries is created to keep the DDL dependency order simple.

-- --------------------------------------------------------------------------
-- 11. Reviews
-- --------------------------------------------------------------------------
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE RESTRICT,
  customer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  rating INTEGER NOT NULL,
  comment TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  replied BOOLEAN NOT NULL DEFAULT FALSE,
  reply TEXT,
  reply_date TIMESTAMPTZ,
  product_image TEXT,
  verified_purchase BOOLEAN NOT NULL DEFAULT FALSE,
  helpful_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('published', 'hidden', 'pending')),
  order_item_id UUID REFERENCES order_items(id) ON DELETE SET NULL,
  CONSTRAINT reviews_rating_ck CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT reviews_helpful_ck CHECK (helpful_count >= 0)
);

CREATE INDEX ix_reviews_product_status ON reviews(product_id, status, created_at DESC);
CREATE INDEX ix_reviews_store_status ON reviews(store_id, status, created_at DESC);
CREATE INDEX ix_reviews_customer ON reviews(customer_id, created_at DESC);
CREATE INDEX ix_reviews_order_item ON reviews(order_item_id);

-- --------------------------------------------------------------------------
-- 12. Financial transactions / refunds / seller payout
-- --------------------------------------------------------------------------
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  buyer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  seller_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  amount NUMERIC(19,4) NOT NULL,
  method TEXT NOT NULL CHECK (method IN ('mvola', 'orange_money', 'card', 'cod')),
  commission NUMERIC(19,4) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('completed', 'pending', 'failed', 'refunded')),
  provider_reference TEXT,
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT transactions_amounts_ck CHECK (amount >= 0 AND commission >= 0 AND commission <= amount)
);

CREATE INDEX ix_transactions_order ON transactions(order_id);
CREATE INDEX ix_transactions_seller_status_date ON transactions(seller_id, status, created_at DESC);
CREATE INDEX ix_transactions_buyer_date ON transactions(buyer_id, created_at DESC);
CREATE INDEX ix_transactions_status_date ON transactions(status, created_at DESC);

CREATE TABLE refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE RESTRICT,
  amount NUMERIC(19,4) NOT NULL,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'processed', 'failed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  CONSTRAINT refunds_amount_ck CHECK (amount >= 0)
);

CREATE INDEX ix_refunds_transaction ON refunds(transaction_id, created_at DESC);

CREATE TABLE seller_payout_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('mvola', 'orange_money', 'bank_account')),
  label TEXT,
  account_name TEXT NOT NULL,
  account_encrypted TEXT NOT NULL,
  masked_account TEXT NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX ux_seller_payout_method_default ON seller_payout_methods(seller_id) WHERE is_default;
CREATE INDEX ix_seller_payout_methods_seller ON seller_payout_methods(seller_id, created_at DESC);

CREATE TABLE payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  amount NUMERIC(19,4) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')
  ),
  method TEXT NOT NULL,
  payout_method_id UUID REFERENCES seller_payout_methods(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid_at TIMESTAMPTZ,
  failure_reason TEXT,
  CONSTRAINT payouts_amount_ck CHECK (amount >= 0)
);

CREATE INDEX ix_payouts_seller_status_date ON payouts(seller_id, status, created_at DESC);

-- --------------------------------------------------------------------------
-- 13. Delivery, location tracking and delivery events
-- --------------------------------------------------------------------------
CREATE TABLE delivery_agents (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'offline' CHECK (status IN ('available', 'busy', 'offline', 'suspended')),
  vehicle TEXT,
  last_location_id UUID,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id TEXT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
  delivery_agent_id UUID REFERENCES delivery_agents(user_id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'preparing', 'processing', 'delivered', 'cancelled', 'failed')
  ),
  pending_reason TEXT CHECK (
    pending_reason IS NULL OR pending_reason IN ('traffic', 'waiting_seller', 'waiting_buyer', 'vehicle_issue', 'weather', 'other')
  ),
  estimated_delivery TIMESTAMPTZ,
  current_location_id UUID,
  assigned_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  failed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_deliveries_agent_status ON deliveries(delivery_agent_id, status, created_at DESC);
CREATE INDEX ix_deliveries_status ON deliveries(status, created_at DESC);

CREATE TABLE tracking_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  accuracy DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  heading DOUBLE PRECISION,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT tracking_points_latitude_ck CHECK (latitude BETWEEN -90 AND 90),
  CONSTRAINT tracking_points_longitude_ck CHECK (longitude BETWEEN -180 AND 180),
  CONSTRAINT tracking_points_accuracy_ck CHECK (accuracy IS NULL OR accuracy >= 0),
  CONSTRAINT tracking_points_speed_ck CHECK (speed IS NULL OR speed >= 0),
  CONSTRAINT tracking_points_heading_ck CHECK (heading IS NULL OR heading BETWEEN 0 AND 360)
);

CREATE INDEX ix_tracking_points_delivery_time ON tracking_points(delivery_id, timestamp DESC);

ALTER TABLE delivery_agents
  ADD CONSTRAINT fk_delivery_agent_last_location
  FOREIGN KEY (last_location_id) REFERENCES tracking_points(id) ON DELETE SET NULL;

ALTER TABLE deliveries
  ADD CONSTRAINT fk_delivery_current_location
  FOREIGN KEY (current_location_id) REFERENCES tracking_points(id) ON DELETE SET NULL;

ALTER TABLE orders
  ADD CONSTRAINT fk_orders_delivery
  FOREIGN KEY (delivery_id) REFERENCES deliveries(id) ON DELETE SET NULL;

CREATE TABLE delivery_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  delivery_id UUID REFERENCES deliveries(id) ON DELETE SET NULL,
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (
    type IN ('assigned', 'status_changed', 'vehicle_loaded', 'delivery_started',
             'location_updated', 'traffic_delay', 'vehicle_issue', 'arrived',
             'delivery_completed', 'delivery_failed', 'note')
  ),
  status TEXT CHECK (
    status IS NULL OR status IN ('pending', 'preparing', 'processing', 'delivered', 'cancelled', 'failed')
  ),
  pending_reason TEXT CHECK (
    pending_reason IS NULL OR pending_reason IN ('traffic', 'waiting_seller', 'waiting_buyer', 'vehicle_issue', 'weather', 'other')
  ),
  message TEXT,
  location_id UUID REFERENCES tracking_points(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_delivery_events_order_date ON delivery_events(order_id, created_at DESC);
CREATE INDEX ix_delivery_events_delivery_date ON delivery_events(delivery_id, created_at DESC);

-- --------------------------------------------------------------------------
-- 14. Platform-wide event stream and admin audit trail
-- --------------------------------------------------------------------------
CREATE TABLE platform_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  actor_name TEXT,
  actor_type TEXT NOT NULL CHECK (
    actor_type IN ('buyer', 'seller', 'moderator', 'delivery', 'admin', 'super_admin', 'system')
  ),
  event_type TEXT NOT NULL,
  resource_type TEXT,
  resource_id TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  ip_address INET,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_platform_events_created ON platform_events(created_at DESC);
CREATE INDEX ix_platform_events_actor ON platform_events(actor_type, actor_id, created_at DESC);
CREATE INDEX ix_platform_events_resource ON platform_events(resource_type, resource_id, created_at DESC);
CREATE INDEX ix_platform_events_event_type ON platform_events(event_type, created_at DESC);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  admin_name TEXT NOT NULL,
  action TEXT NOT NULL,
  resource TEXT NOT NULL,
  resource_id TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  ip_address INET NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_audit_logs_admin_date ON audit_logs(admin_id, created_at DESC);
CREATE INDEX ix_audit_logs_resource ON audit_logs(resource, resource_id, created_at DESC);

-- --------------------------------------------------------------------------
-- 15. Global platform configuration
-- --------------------------------------------------------------------------
CREATE TABLE platform_settings (
  id BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id = TRUE),
  platform_name TEXT,
  commission_rate NUMERIC(5,2),
  default_delivery_fee NUMERIC(19,4),
  maintenance_mode BOOLEAN,
  allow_new_registrations BOOLEAN,
  allow_new_seller_applications BOOLEAN,
  require_product_moderation BOOLEAN,
  require_seller_approval BOOLEAN,
  default_language TEXT CHECK (default_language IN ('mg', 'fr', 'en')),
  timezone TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT platform_settings_commission_ck CHECK (
    commission_rate IS NULL OR commission_rate BETWEEN 0 AND 100
  ),
  CONSTRAINT platform_settings_delivery_fee_ck CHECK (
    default_delivery_fee IS NULL OR default_delivery_fee >= 0
  )
);

INSERT INTO platform_settings (id)
VALUES (TRUE)
ON CONFLICT (id) DO NOTHING;

-- --------------------------------------------------------------------------
-- 16. Triggers for updated_at
-- --------------------------------------------------------------------------
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_two_factor_settings_updated_at
BEFORE UPDATE ON two_factor_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_addresses_updated_at
BEFORE UPDATE ON user_addresses
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_buyer_preferences_updated_at
BEFORE UPDATE ON buyer_preferences
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_buyer_notification_preferences_updated_at
BEFORE UPDATE ON buyer_notification_preferences
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_privacy_settings_updated_at
BEFORE UPDATE ON privacy_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_consent_settings_updated_at
BEFORE UPDATE ON consent_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_admin_settings_updated_at
BEFORE UPDATE ON admin_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_admin_notification_preferences_updated_at
BEFORE UPDATE ON admin_notification_preferences
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_seller_settings_updated_at
BEFORE UPDATE ON seller_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_seller_notification_preferences_updated_at
BEFORE UPDATE ON seller_notification_preferences
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_carts_updated_at
BEFORE UPDATE ON carts
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_cart_items_updated_at
BEFORE UPDATE ON cart_items
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_categories_updated_at
BEFORE UPDATE ON categories
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_stores_updated_at
BEFORE UPDATE ON stores
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_store_policies_updated_at
BEFORE UPDATE ON store_policies
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_seller_applications_updated_at
BEFORE UPDATE ON seller_applications
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_inventory_updated_at
BEFORE UPDATE ON inventory
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_promotions_updated_at
BEFORE UPDATE ON promotions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_transactions_updated_at
BEFORE UPDATE ON transactions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_seller_payout_methods_updated_at
BEFORE UPDATE ON seller_payout_methods
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_delivery_agents_updated_at
BEFORE UPDATE ON delivery_agents
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_deliveries_updated_at
BEFORE UPDATE ON deliveries
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_platform_settings_updated_at
BEFORE UPDATE ON platform_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- --------------------------------------------------------------------------
-- 17. Useful calculated views matching OpenAPI response DTOs
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW inventory_items_api AS
SELECT
  i.product_id,
  p.name,
  p.sku,
  i.stock,
  i.reserved,
  (i.stock - i.reserved) AS available,
  i.threshold,
  CASE
    WHEN (i.stock - i.reserved) <= 0 THEN 'out_of_stock'
    WHEN (i.stock - i.reserved) <= i.threshold THEN 'low_stock'
    ELSE 'in_stock'
  END AS status
FROM inventory i
JOIN products p ON p.id = i.product_id
WHERE p.deleted_at IS NULL;

CREATE OR REPLACE VIEW seller_balances_api AS
WITH earnings AS (
  SELECT
    seller_id,
    COALESCE(SUM(CASE WHEN status = 'completed' THEN amount - commission ELSE 0 END), 0) AS earned_completed,
    COALESCE(SUM(CASE WHEN status = 'pending' THEN amount - commission ELSE 0 END), 0) AS earned_pending
  FROM transactions
  GROUP BY seller_id
),
payout_totals AS (
  SELECT
    seller_id,
    COALESCE(SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END), 0) AS paid_out
  FROM payouts
  GROUP BY seller_id
)
SELECT
  u.id AS seller_id,
  COALESCE(e.earned_completed, 0) - COALESCE(p.paid_out, 0) AS available,
  COALESCE(e.earned_pending, 0) AS pending,
  COALESCE(e.earned_completed, 0) AS total_earned,
  COALESCE(p.paid_out, 0) AS total_paid_out
FROM users u
LEFT JOIN earnings e ON e.seller_id = u.id
LEFT JOIN payout_totals p ON p.seller_id = u.id
WHERE u.role = 'seller';

-- --------------------------------------------------------------------------
-- 18. Optional consistency checks / seed invariants
-- --------------------------------------------------------------------------
-- seller/admin/delivery role/profile linkage is enforced by application logic;
-- a PostgreSQL CHECK cannot safely inspect another table row.
--
-- Example application invariants that MUST be implemented in service code:
--   * /auth/register creates buyer users only.
--   * Seller approval changes users.role to seller, sets stores.verified and
--     links the resulting store to that seller.
--   * Reviews can only be created after a verified purchase according to the
--     business rule exposed by POST /products/{id}/reviews.
--   * Adding/updating cart quantities must re-check live inventory.
--   * Checkout must run in a transaction and reject insufficient stock.
--   * If the cart contains products from several sellers, checkout may create
--     multiple orders (the endpoint explicitly returns Order[]).
--   * Buyer-visible order item name/price/image/sellerName are snapshots and
--     must not be recomputed from mutable product/store data.
--   * Order address must be a checkout-time snapshot, not a live pointer to a
--     mutable buyer address.
--   * Refresh tokens, CSRF tokens, reset codes, verification codes and 2FA
--     recovery codes must be hashed or encrypted appropriately.
--   * Raw card data must never be stored; only a provider token/reference and
--     masked data belong in payment_methods.
--   * seller_payout_methods.account_encrypted requires application-layer
--     encryption/key management.
--
-- END OF SCHEMA
