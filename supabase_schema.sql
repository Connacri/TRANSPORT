-- ============================================================
-- TRANSPORT HUB — SCHÉMA SUPABASE COMPLET v1.0
-- Firebase Auth (UID) + Supabase (DB/Storage/Realtime)
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- TYPES ENUM
-- ============================================================
CREATE TYPE user_role        AS ENUM ('admin','supervisor','transporter','public');
CREATE TYPE request_status   AS ENUM ('pending','accepted','in_progress','completed','cancelled');
CREATE TYPE payment_status   AS ENUM ('pending','paid','refunded');
CREATE TYPE commission_status AS ENUM ('pending','paid','cancelled');
CREATE TYPE supervisor_tier  AS ENUM ('silver','gold','platinum');
CREATE TYPE premium_type     AS ENUM ('visibility','location_interval','badge_boost');
CREATE TYPE listing_type     AS ENUM ('product','service');
CREATE TYPE listing_status   AS ENUM ('active','sold','paused','removed');
CREATE TYPE boutique_status  AS ENUM ('pending','validated','suspended');
CREATE TYPE badge_level      AS ENUM ('bronze','silver','gold','platinum');

-- ============================================================
-- TABLE: regions
-- ============================================================
CREATE TABLE regions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  country         TEXT NOT NULL DEFAULT 'Algeria',
  currency        TEXT NOT NULL DEFAULT 'DZD',
  currency_symbol TEXT DEFAULT 'DA',
  timezone        TEXT DEFAULT 'Africa/Algiers',
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: business_rules (tout réglable par l'admin)
-- ============================================================
CREATE TABLE business_rules (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key              TEXT NOT NULL,
  value            JSONB NOT NULL,
  region_id        UUID REFERENCES regions(id) ON DELETE SET NULL,
  applies_to_role  user_role,
  description      TEXT,
  updated_by       UUID,
  updated_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(key, region_id, applies_to_role)
);

-- ============================================================
-- TABLE: profiles (lié au firebase_uid)
-- ============================================================
CREATE TABLE profiles (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid     TEXT UNIQUE NOT NULL,
  email            TEXT UNIQUE NOT NULL,
  full_name        TEXT,
  phone            TEXT,
  avatar_url       TEXT,
  role             user_role NOT NULL DEFAULT 'public',
  is_active        BOOLEAN DEFAULT true,
  is_email_verified BOOLEAN DEFAULT false,
  region_id        UUID REFERENCES regions(id) ON DELETE SET NULL,
  last_seen        TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: boutiques (paiement physique validé par admin)
-- ============================================================
CREATE TABLE boutiques (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  address       TEXT NOT NULL,
  lat           DOUBLE PRECISION,
  lng           DOUBLE PRECISION,
  phone         TEXT,
  manager_id    UUID REFERENCES profiles(id) ON DELETE SET NULL,
  status        boutique_status DEFAULT 'pending',
  validated_by  UUID REFERENCES profiles(id) ON DELETE SET NULL,
  validated_at  TIMESTAMPTZ,
  region_id     UUID REFERENCES regions(id) ON DELETE CASCADE,
  is_active     BOOLEAN DEFAULT true,
  opening_hours JSONB DEFAULT '{}',
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: transporters
-- ============================================================
CREATE TABLE transporters (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id               UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,

  -- Véhicule (obligatoire)
  vehicle_type             TEXT NOT NULL,
  vehicle_brand            TEXT,
  vehicle_model            TEXT,
  vehicle_year             INTEGER,
  vehicle_plate            TEXT UNIQUE NOT NULL,
  vehicle_capacity_kg      NUMERIC(10,2),
  vehicle_capacity_m3      NUMERIC(10,2),
  vehicle_photo_url        TEXT NOT NULL,

  -- Documents (optionnels sauf photo)
  face_photo_url           TEXT,
  license_photo_url        TEXT,
  registration_photo_url   TEXT,
  insurance_photo_url      TEXT,
  technical_control_url    TEXT,

  -- Validation admin
  is_validated             BOOLEAN DEFAULT false,
  validation_score         INTEGER DEFAULT 0,
  badge                    badge_level,
  validated_by             UUID REFERENCES profiles(id) ON DELETE SET NULL,
  validated_at             TIMESTAMPTZ,
  suspension_reason        TEXT,

  -- Disponibilité
  is_available             BOOLEAN DEFAULT false,
  availability_schedule    JSONB DEFAULT '{}',

  -- Services proposés
  offers_handling          BOOLEAN DEFAULT false,
  handling_fee_rate        NUMERIC(5,2) DEFAULT 0,
  offers_transport_insurance BOOLEAN DEFAULT false,
  insurance_rate_percent   NUMERIC(5,2) DEFAULT 0,

  -- Tarification
  base_price_per_km        NUMERIC(10,2),
  minimum_price            NUMERIC(10,2),

  -- Premium (style Facebook Ads)
  is_premium               BOOLEAN DEFAULT false,
  premium_until            TIMESTAMPTZ,
  premium_type             premium_type,
  location_interval_seconds INTEGER DEFAULT 30,

  -- Stats
  average_rating           NUMERIC(3,2) DEFAULT 0,
  total_ratings            INTEGER DEFAULT 0,
  total_transports         INTEGER DEFAULT 0,

  -- Localisation temps réel
  current_lat              DOUBLE PRECISION,
  current_lng              DOUBLE PRECISION,
  last_location_at         TIMESTAMPTZ,

  region_id                UUID REFERENCES regions(id) ON DELETE SET NULL,
  created_at               TIMESTAMPTZ DEFAULT NOW(),
  updated_at               TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: transport_requests
-- ============================================================
CREATE TABLE transport_requests (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id                   UUID REFERENCES profiles(id) ON DELETE SET NULL NOT NULL,
  transporter_id              UUID REFERENCES transporters(id) ON DELETE SET NULL,

  -- Trajet
  pickup_lat                  DOUBLE PRECISION NOT NULL,
  pickup_lng                  DOUBLE PRECISION NOT NULL,
  pickup_address              TEXT,
  dropoff_lat                 DOUBLE PRECISION NOT NULL,
  dropoff_lng                 DOUBLE PRECISION NOT NULL,
  dropoff_address             TEXT,
  estimated_distance_km       NUMERIC(10,2),
  estimated_duration_min      INTEGER,

  -- Cargaison
  cargo_description           TEXT,
  cargo_weight_kg             NUMERIC(10,2),
  needs_handling              BOOLEAN DEFAULT false,
  needs_transport_insurance   BOOLEAN DEFAULT false,

  -- Tarification
  base_price                  NUMERIC(10,2),
  handling_fee                NUMERIC(10,2) DEFAULT 0,
  insurance_fee               NUMERIC(10,2) DEFAULT 0,
  total_price                 NUMERIC(10,2),
  currency                    TEXT DEFAULT 'DZD',

  -- Commissions (calculées automatiquement par trigger)
  app_commission_amount       NUMERIC(10,2) DEFAULT 0,
  supervisor_commission_amount NUMERIC(10,2) DEFAULT 0,
  transporter_net_amount      NUMERIC(10,2) DEFAULT 0,

  -- Statuts
  status                      request_status DEFAULT 'pending',
  payment_status              payment_status DEFAULT 'pending',
  payment_boutique_id         UUID REFERENCES boutiques(id) ON DELETE SET NULL,
  payment_validated_by        UUID REFERENCES profiles(id) ON DELETE SET NULL,
  payment_validated_at        TIMESTAMPTZ,

  -- Timestamps
  requested_at                TIMESTAMPTZ DEFAULT NOW(),
  accepted_at                 TIMESTAMPTZ,
  started_at                  TIMESTAMPTZ,
  completed_at                TIMESTAMPTZ,
  cancelled_at                TIMESTAMPTZ,
  cancellation_reason         TEXT,
  region_id                   UUID REFERENCES regions(id) ON DELETE SET NULL
);

-- ============================================================
-- TABLE: trackings (Realtime — tracking Uber/Yassir style)
-- ============================================================
CREATE TABLE trackings (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id     UUID REFERENCES transport_requests(id) ON DELETE CASCADE NOT NULL,
  transporter_id UUID REFERENCES transporters(id) ON DELETE CASCADE NOT NULL,
  lat            DOUBLE PRECISION NOT NULL,
  lng            DOUBLE PRECISION NOT NULL,
  speed_kmh      NUMERIC(6,2),
  heading        NUMERIC(5,2),
  accuracy_m     NUMERIC(6,2),
  recorded_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_trackings_request    ON trackings(request_id);
CREATE INDEX idx_trackings_recorded   ON trackings(recorded_at DESC);
CREATE INDEX idx_trackings_transporter ON trackings(transporter_id, recorded_at DESC);

-- ============================================================
-- TABLE: ratings
-- ============================================================
CREATE TABLE ratings (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id     UUID REFERENCES transport_requests(id) ON DELETE CASCADE UNIQUE NOT NULL,
  transporter_id UUID REFERENCES transporters(id) ON DELETE CASCADE NOT NULL,
  client_id      UUID REFERENCES profiles(id) ON DELETE SET NULL NOT NULL,
  score          INTEGER CHECK (score BETWEEN 1 AND 5) NOT NULL,
  comment        TEXT,
  is_visible     BOOLEAN DEFAULT true,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: supervisors
-- ============================================================
CREATE TABLE supervisors (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id                      UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
  tier                            supervisor_tier DEFAULT 'silver',
  max_transporters                INTEGER DEFAULT 20,

  -- Taux commissions (modifiables par admin)
  commission_from_transports_rate NUMERIC(5,2) DEFAULT 5.00,
  commission_to_app_rate          NUMERIC(5,2) DEFAULT 2.00,

  -- Activité mensuelle
  current_month_year              TEXT,
  transporters_added_this_month   INTEGER DEFAULT 0,
  min_monthly_add_required        INTEGER DEFAULT 5,
  is_commission_active            BOOLEAN DEFAULT true,
  commission_suspended_reason     TEXT,

  -- Revenus cumulés
  total_gross_earnings            NUMERIC(10,2) DEFAULT 0,
  total_app_fees_paid             NUMERIC(10,2) DEFAULT 0,
  total_net_earnings              NUMERIC(10,2) DEFAULT 0,

  -- Multi-niveaux (superviseur recruté par un autre)
  parent_supervisor_id            UUID REFERENCES supervisors(id) ON DELETE SET NULL,
  referral_code                   TEXT UNIQUE DEFAULT UPPER(SUBSTRING(gen_random_uuid()::TEXT, 1, 8)),
  region_id                       UUID REFERENCES regions(id) ON DELETE SET NULL,
  created_at                      TIMESTAMPTZ DEFAULT NOW(),
  updated_at                      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: supervisor_referrals
-- ============================================================
CREATE TABLE supervisor_referrals (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_id     UUID REFERENCES supervisors(id) ON DELETE CASCADE NOT NULL,
  transporter_id    UUID REFERENCES transporters(id) ON DELETE CASCADE NOT NULL,
  joined_at         TIMESTAMPTZ DEFAULT NOW(),
  is_active         BOOLEAN DEFAULT true,
  deactivated_at    TIMESTAMPTZ,
  deactivation_reason TEXT,
  UNIQUE(supervisor_id, transporter_id)
);

-- ============================================================
-- TABLE: commissions (split automatique)
-- ============================================================
CREATE TABLE commissions (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id           UUID REFERENCES transport_requests(id) ON DELETE CASCADE NOT NULL,
  beneficiary_id       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  beneficiary_type     TEXT CHECK (beneficiary_type IN ('app','supervisor')) NOT NULL,
  amount               NUMERIC(10,2) NOT NULL,
  rate_applied         NUMERIC(5,2),
  status               commission_status DEFAULT 'pending',
  paid_at              TIMESTAMPTZ,
  paid_via_boutique_id UUID REFERENCES boutiques(id),
  created_at           TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: premium_options (style Facebook Ads)
-- ============================================================
CREATE TABLE premium_options (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                      TEXT NOT NULL,
  type                      premium_type NOT NULL,
  description               TEXT,
  duration_days             INTEGER NOT NULL,
  price                     NUMERIC(10,2) NOT NULL,
  currency                  TEXT DEFAULT 'DZD',
  location_interval_seconds INTEGER,
  position_boost            INTEGER DEFAULT 0,
  is_active                 BOOLEAN DEFAULT true,
  region_id                 UUID REFERENCES regions(id) ON DELETE SET NULL,
  sort_order                INTEGER DEFAULT 0,
  created_at                TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: premium_purchases (achat en boutique physique)
-- ============================================================
CREATE TABLE premium_purchases (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transporter_id  UUID REFERENCES transporters(id) ON DELETE CASCADE NOT NULL,
  option_id       UUID REFERENCES premium_options(id) ON DELETE SET NULL NOT NULL,
  boutique_id     UUID REFERENCES boutiques(id) ON DELETE SET NULL,
  amount_paid     NUMERIC(10,2) NOT NULL,
  starts_at       TIMESTAMPTZ DEFAULT NOW(),
  ends_at         TIMESTAMPTZ NOT NULL,
  status          TEXT CHECK (status IN ('pending_payment','active','expired','cancelled')) DEFAULT 'pending_payment',
  validated_by    UUID REFERENCES profiles(id) ON DELETE SET NULL,
  validated_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: marketplace_categories
-- ============================================================
CREATE TABLE marketplace_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  name_ar    TEXT,
  icon_name  TEXT,
  color_hex  TEXT DEFAULT '#FF6B35',
  parent_id  UUID REFERENCES marketplace_categories(id) ON DELETE SET NULL,
  sort_order INTEGER DEFAULT 0,
  is_active  BOOLEAN DEFAULT true
);

-- ============================================================
-- TABLE: marketplace_listings
-- ============================================================
CREATE TABLE marketplace_listings (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id         UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title             TEXT NOT NULL,
  description       TEXT,
  category_id       UUID REFERENCES marketplace_categories(id) ON DELETE SET NULL,
  type              listing_type NOT NULL,
  price             NUMERIC(10,2),
  is_price_negotiable BOOLEAN DEFAULT false,
  currency          TEXT DEFAULT 'DZD',
  images_urls       TEXT[] DEFAULT '{}',
  region_id         UUID REFERENCES regions(id) ON DELETE SET NULL,
  city              TEXT,
  status            listing_status DEFAULT 'active',
  commission_rate   NUMERIC(5,2) DEFAULT 5.00,
  is_premium        BOOLEAN DEFAULT false,
  premium_until     TIMESTAMPTZ,
  views_count       INTEGER DEFAULT 0,
  is_verified       BOOLEAN DEFAULT false,
  verified_by       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: notifications_log
-- ============================================================
CREATE TABLE notifications_log (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title        TEXT NOT NULL,
  body         TEXT NOT NULL,
  data         JSONB DEFAULT '{}',
  type         TEXT,
  is_read      BOOLEAN DEFAULT false,
  sent_via_fcm BOOLEAN DEFAULT false,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: fcm_tokens
-- ============================================================
CREATE TABLE fcm_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  token      TEXT NOT NULL,
  platform   TEXT CHECK (platform IN ('android','windows','ios','web')),
  is_active  BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(profile_id, platform)
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_profiles_firebase     ON profiles(firebase_uid);
CREATE INDEX idx_profiles_role         ON profiles(role);
CREATE INDEX idx_transporters_avail    ON transporters(is_available, is_validated);
CREATE INDEX idx_transporters_location ON transporters(current_lat, current_lng);
CREATE INDEX idx_transporters_premium  ON transporters(is_premium, premium_until);
CREATE INDEX idx_requests_status       ON transport_requests(status);
CREATE INDEX idx_requests_client       ON transport_requests(client_id);
CREATE INDEX idx_requests_transporter  ON transport_requests(transporter_id);
CREATE INDEX idx_listings_status       ON marketplace_listings(status, region_id);
CREATE INDEX idx_sup_referrals         ON supervisor_referrals(supervisor_id);
CREATE INDEX idx_commissions_request   ON commissions(request_id);
CREATE INDEX idx_notif_recipient       ON notifications_log(recipient_id, is_read);

-- ============================================================
-- FONCTIONS UTILITAIRES
-- ============================================================

-- Distance Haversine entre deux points (km)
CREATE OR REPLACE FUNCTION calculate_distance_km(
  lat1 DOUBLE PRECISION, lng1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lng2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
DECLARE
  R  CONSTANT DOUBLE PRECISION := 6371;
  dlat DOUBLE PRECISION := RADIANS(lat2 - lat1);
  dlng DOUBLE PRECISION := RADIANS(lng2 - lng1);
  a  DOUBLE PRECISION;
BEGIN
  a := SIN(dlat/2)^2 + COS(RADIANS(lat1)) * COS(RADIANS(lat2)) * SIN(dlng/2)^2;
  RETURN R * 2 * ASIN(SQRT(a));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Récupérer transporteurs disponibles triés (premium > proximité > note)
CREATE OR REPLACE FUNCTION get_nearby_transporters(
  user_lat           DOUBLE PRECISION,
  user_lng           DOUBLE PRECISION,
  radius_km          DOUBLE PRECISION DEFAULT 50,
  vehicle_type_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
  transporter_id            UUID,
  profile_id                UUID,
  full_name                 TEXT,
  avatar_url                TEXT,
  vehicle_type              TEXT,
  vehicle_photo_url         TEXT,
  is_premium                BOOLEAN,
  badge                     badge_level,
  average_rating            NUMERIC,
  total_ratings             INTEGER,
  distance_km               DOUBLE PRECISION,
  base_price_per_km         NUMERIC,
  minimum_price             NUMERIC,
  offers_handling           BOOLEAN,
  offers_transport_insurance BOOLEAN,
  current_lat               DOUBLE PRECISION,
  current_lng               DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id,
    p.id,
    p.full_name,
    p.avatar_url,
    t.vehicle_type,
    t.vehicle_photo_url,
    t.is_premium,
    t.badge,
    t.average_rating,
    t.total_ratings,
    calculate_distance_km(user_lat, user_lng, t.current_lat, t.current_lng),
    t.base_price_per_km,
    t.minimum_price,
    t.offers_handling,
    t.offers_transport_insurance,
    t.current_lat,
    t.current_lng
  FROM transporters t
  JOIN profiles p ON p.id = t.profile_id
  WHERE
    t.is_available = true
    AND t.is_validated = true
    AND t.current_lat IS NOT NULL
    AND t.current_lng IS NOT NULL
    AND calculate_distance_km(user_lat, user_lng, t.current_lat, t.current_lng) <= radius_km
    AND (vehicle_type_filter IS NULL OR t.vehicle_type = vehicle_type_filter)
  ORDER BY
    t.is_premium DESC,
    t.premium_until > NOW() DESC,
    calculate_distance_km(user_lat, user_lng, t.current_lat, t.current_lng) ASC,
    t.average_rating DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TRIGGER: Mise à jour note moyenne transporteur
-- ============================================================
CREATE OR REPLACE FUNCTION update_transporter_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE transporters SET
    average_rating = (
      SELECT COALESCE(AVG(score), 0)::NUMERIC(3,2)
      FROM ratings WHERE transporter_id = NEW.transporter_id AND is_visible = true
    ),
    total_ratings = (
      SELECT COUNT(*) FROM ratings
      WHERE transporter_id = NEW.transporter_id AND is_visible = true
    )
  WHERE id = NEW.transporter_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_rating
AFTER INSERT OR UPDATE ON ratings
FOR EACH ROW EXECUTE FUNCTION update_transporter_rating();

-- ============================================================
-- TRIGGER: Calcul split commissions à la complétion du transport
-- ============================================================
CREATE OR REPLACE FUNCTION create_transport_commissions()
RETURNS TRIGGER AS $$
DECLARE
  app_rate   NUMERIC;
  sup_rate   NUMERIC;
  sup        RECORD;
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Taux app depuis business_rules (région spécifique > global)
    SELECT (value->>'rate')::NUMERIC INTO app_rate
    FROM business_rules
    WHERE key = 'app_commission_rate'
      AND (region_id = NEW.region_id OR region_id IS NULL)
    ORDER BY region_id NULLS LAST LIMIT 1;
    app_rate := COALESCE(app_rate, 10.00);

    -- Insérer commission app
    INSERT INTO commissions(request_id, beneficiary_id, beneficiary_type, amount, rate_applied)
    VALUES (NEW.id, NULL, 'app', NEW.total_price * app_rate / 100, app_rate);

    -- Chercher superviseur du transporteur (actif et commission active)
    SELECT
      s.id AS sup_id,
      s.profile_id AS sup_profile_id,
      s.commission_from_transports_rate,
      s.commission_to_app_rate,
      s.is_commission_active
    INTO sup
    FROM supervisor_referrals sr
    JOIN supervisors s ON s.id = sr.supervisor_id
    WHERE sr.transporter_id = NEW.transporter_id
      AND sr.is_active = true
      AND s.is_commission_active = true
    LIMIT 1;

    IF FOUND THEN
      sup_rate := sup.commission_from_transports_rate;
      INSERT INTO commissions(request_id, beneficiary_id, beneficiary_type, amount, rate_applied)
      VALUES (NEW.id, sup.sup_profile_id, 'supervisor', NEW.total_price * sup_rate / 100, sup_rate);

      UPDATE supervisors SET
        total_gross_earnings = total_gross_earnings + (NEW.total_price * sup_rate / 100),
        total_app_fees_paid  = total_app_fees_paid + (NEW.total_price * sup.commission_to_app_rate / 100),
        total_net_earnings   = total_net_earnings + (NEW.total_price * (sup_rate - sup.commission_to_app_rate) / 100)
      WHERE id = sup.sup_id;
    END IF;

    -- Mettre à jour les montants de la requête
    UPDATE transport_requests SET
      app_commission_amount        = NEW.total_price * app_rate / 100,
      supervisor_commission_amount = CASE WHEN sup IS NOT NULL THEN NEW.total_price * COALESCE(sup.commission_from_transports_rate, 0) / 100 ELSE 0 END,
      transporter_net_amount       = NEW.total_price
                                     - (NEW.total_price * app_rate / 100)
                                     - CASE WHEN sup IS NOT NULL THEN NEW.total_price * COALESCE(sup.commission_from_transports_rate, 0) / 100 ELSE 0 END
    WHERE id = NEW.id;

    -- Stats transporteur
    UPDATE transporters SET total_transports = total_transports + 1
    WHERE id = NEW.transporter_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_create_commissions
AFTER UPDATE ON transport_requests
FOR EACH ROW EXECUTE FUNCTION create_transport_commissions();

-- ============================================================
-- TRIGGER: Incrémenter transporters_added_this_month
-- ============================================================
CREATE OR REPLACE FUNCTION increment_supervisor_monthly_adds()
RETURNS TRIGGER AS $$
DECLARE
  current_month TEXT := TO_CHAR(NOW(), 'YYYY-MM');
BEGIN
  UPDATE supervisors SET
    transporters_added_this_month = CASE
      WHEN current_month_year = current_month THEN transporters_added_this_month + 1
      ELSE 1
    END,
    current_month_year = current_month
  WHERE id = NEW.supervisor_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_supervisor_monthly_count
AFTER INSERT ON supervisor_referrals
FOR EACH ROW EXECUTE FUNCTION increment_supervisor_monthly_adds();

-- ============================================================
-- TRIGGER: Validation score du transporteur selon documents
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_validation_score()
RETURNS TRIGGER AS $$
DECLARE score INT := 0;
BEGIN
  IF NEW.vehicle_photo_url IS NOT NULL    THEN score := score + 20; END IF;
  IF NEW.face_photo_url IS NOT NULL       THEN score := score + 10; END IF;
  IF NEW.license_photo_url IS NOT NULL    THEN score := score + 20; END IF;
  IF NEW.registration_photo_url IS NOT NULL THEN score := score + 20; END IF;
  IF NEW.insurance_photo_url IS NOT NULL  THEN score := score + 20; END IF;
  IF NEW.technical_control_url IS NOT NULL THEN score := score + 10; END IF;

  NEW.validation_score := score;

  -- Attribution automatique du badge selon score
  NEW.badge := CASE
    WHEN score = 100 THEN 'platinum'::badge_level
    WHEN score >= 80  THEN 'gold'::badge_level
    WHEN score >= 60  THEN 'silver'::badge_level
    WHEN score >= 40  THEN 'bronze'::badge_level
    ELSE NULL
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validation_score
BEFORE INSERT OR UPDATE ON transporters
FOR EACH ROW EXECUTE FUNCTION calculate_validation_score();

-- ============================================================
-- TRIGGER: Vérification cap superviseur
-- ============================================================
CREATE OR REPLACE FUNCTION check_supervisor_cap()
RETURNS TRIGGER AS $$
DECLARE
  current_count INTEGER;
  max_allowed   INTEGER;
BEGIN
  SELECT COUNT(*) INTO current_count
  FROM supervisor_referrals
  WHERE supervisor_id = NEW.supervisor_id AND is_active = true;

  SELECT max_transporters INTO max_allowed
  FROM supervisors WHERE id = NEW.supervisor_id;

  IF current_count >= max_allowed THEN
    RAISE EXCEPTION 'Limite de transporteurs atteinte pour ce superviseur (%). Passez au tier supérieur.', max_allowed;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_supervisor_cap
BEFORE INSERT ON supervisor_referrals
FOR EACH ROW EXECUTE FUNCTION check_supervisor_cap();

-- ============================================================
-- TRIGGER: Expiration premium auto
-- ============================================================
CREATE OR REPLACE FUNCTION deactivate_expired_premium()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.ends_at < NOW() AND OLD.status = 'active' THEN
    NEW.status := 'expired';
    UPDATE transporters SET
      is_premium = false,
      premium_until = NULL,
      premium_type = NULL
    WHERE id = NEW.transporter_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE transporters          ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_requests    ENABLE ROW LEVEL SECURITY;
ALTER TABLE trackings             ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings               ENABLE ROW LEVEL SECURITY;
ALTER TABLE supervisors           ENABLE ROW LEVEL SECURITY;
ALTER TABLE supervisor_referrals  ENABLE ROW LEVEL SECURITY;
ALTER TABLE commissions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_listings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications_log     ENABLE ROW LEVEL SECURITY;
ALTER TABLE boutiques             ENABLE ROW LEVEL SECURITY;
ALTER TABLE premium_purchases     ENABLE ROW LEVEL SECURITY;

-- Helper: récupérer l'UID Firebase depuis le JWT Supabase (Third Party Auth)
CREATE OR REPLACE FUNCTION get_firebase_uid()
RETURNS TEXT AS $$
  SELECT COALESCE(
    auth.uid()::TEXT,
    current_setting('request.jwt.claims', true)::json->>'sub'
  );
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_profile_id()
RETURNS UUID AS $$
  SELECT id FROM profiles WHERE firebase_uid = get_firebase_uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE firebase_uid = get_firebase_uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- Policies: profiles
CREATE POLICY "profiles_read_all"  ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_own_write" ON profiles FOR ALL USING (firebase_uid = get_firebase_uid());
CREATE POLICY "profiles_admin_all" ON profiles FOR ALL USING (get_my_role() = 'admin');

-- Policies: transporters
CREATE POLICY "transporters_public_read"   ON transporters FOR SELECT USING (is_validated = true OR profile_id = get_my_profile_id());
CREATE POLICY "transporters_own_write"     ON transporters FOR ALL USING (profile_id = get_my_profile_id());
CREATE POLICY "transporters_admin"         ON transporters FOR ALL USING (get_my_role() = 'admin');
CREATE POLICY "transporters_supervisor_r"  ON transporters FOR SELECT USING (get_my_role() IN ('supervisor','admin'));

-- Policies: transport_requests
CREATE POLICY "requests_client"          ON transport_requests FOR ALL USING (client_id = get_my_profile_id());
CREATE POLICY "requests_transporter_r"   ON transport_requests FOR SELECT USING (transporter_id IN (SELECT id FROM transporters WHERE profile_id = get_my_profile_id()));
CREATE POLICY "requests_transporter_upd" ON transport_requests FOR UPDATE USING (transporter_id IN (SELECT id FROM transporters WHERE profile_id = get_my_profile_id()));
CREATE POLICY "requests_admin"           ON transport_requests FOR ALL USING (get_my_role() = 'admin');

-- Policies: trackings
CREATE POLICY "trackings_participants" ON trackings FOR SELECT USING (
  request_id IN (
    SELECT id FROM transport_requests
    WHERE client_id = get_my_profile_id()
       OR transporter_id IN (SELECT id FROM transporters WHERE profile_id = get_my_profile_id())
  )
);
CREATE POLICY "trackings_transporter_insert" ON trackings FOR INSERT WITH CHECK (
  transporter_id IN (SELECT id FROM transporters WHERE profile_id = get_my_profile_id())
);

-- Policies: supervisors
CREATE POLICY "supervisors_own"  ON supervisors FOR ALL USING (profile_id = get_my_profile_id());
CREATE POLICY "supervisors_admin" ON supervisors FOR ALL USING (get_my_role() = 'admin');

-- Policies: commissions
CREATE POLICY "commissions_own"   ON commissions FOR SELECT USING (beneficiary_id = get_my_profile_id());
CREATE POLICY "commissions_admin" ON commissions FOR ALL USING (get_my_role() = 'admin');

-- Policies: notifications
CREATE POLICY "notif_own"   ON notifications_log FOR ALL USING (recipient_id = get_my_profile_id());
CREATE POLICY "notif_admin" ON notifications_log FOR ALL USING (get_my_role() = 'admin');

-- Policies: marketplace
CREATE POLICY "listings_public_read" ON marketplace_listings FOR SELECT USING (status = 'active');
CREATE POLICY "listings_own_write"   ON marketplace_listings FOR ALL USING (seller_id = get_my_profile_id());
CREATE POLICY "listings_admin"       ON marketplace_listings FOR ALL USING (get_my_role() = 'admin');

-- Policies: boutiques
CREATE POLICY "boutiques_public_read" ON boutiques FOR SELECT USING (is_active = true);
CREATE POLICY "boutiques_admin"       ON boutiques FOR ALL USING (get_my_role() = 'admin');

-- Policies: premium_purchases
CREATE POLICY "premium_own"   ON premium_purchases FOR SELECT USING (transporter_id IN (SELECT id FROM transporters WHERE profile_id = get_my_profile_id()));
CREATE POLICY "premium_admin" ON premium_purchases FOR ALL USING (get_my_role() = 'admin');

-- ============================================================
-- DONNÉES INITIALES
-- ============================================================
INSERT INTO regions (name, country, currency, currency_symbol) VALUES
  ('Alger',       'Algeria', 'DZD', 'DA'),
  ('Oran',        'Algeria', 'DZD', 'DA'),
  ('Constantine', 'Algeria', 'DZD', 'DA'),
  ('Annaba',      'Algeria', 'DZD', 'DA'),
  ('Tlemcen',     'Algeria', 'DZD', 'DA'),
  ('Sétif',       'Algeria', 'DZD', 'DA');

INSERT INTO business_rules (key, value, description) VALUES
  ('app_commission_rate',               '{"rate": 10}',  'Commission app (%) sur chaque transport'),
  ('supervisor_commission_rate',        '{"rate": 5}',   'Commission superviseur (%) par défaut'),
  ('supervisor_app_fee_rate',           '{"rate": 2}',   'Frais app sur commission superviseur (%)'),
  ('supervisor_min_monthly_adds',       '{"count": 5}',  'Transporteurs min à ajouter/mois pour garder commissions'),
  ('supervisor_max_silver',             '{"count": 20}', 'Max transporteurs — tier Silver'),
  ('supervisor_max_gold',               '{"count": 50}', 'Max transporteurs — tier Gold'),
  ('supervisor_max_platinum',           '{"count": 150}','Max transporteurs — tier Platinum'),
  ('base_price_per_km',                 '{"price": 50}', 'Prix de base par km (DZD)'),
  ('handling_fee_rate',                 '{"rate": 15}',  'Frais manutention (%) par défaut'),
  ('insurance_rate',                    '{"rate": 3}',   'Taux assurance transport (%)'),
  ('marketplace_commission_rate',       '{"rate": 5}',   'Commission marketplace (%)'),
  ('tracking_default_interval_seconds', '{"seconds": 30}','Intervalle localisation standard (sec)'),
  ('tracking_premium_interval_seconds', '{"seconds": 5}', 'Intervalle localisation premium (sec)'),
  ('rating_min_count_to_display',       '{"count": 3}',  'Notes min avant affichage public'),
  ('surge_pricing_multiplier_peak',     '{"multiplier": 1.5}', 'Multiplicateur heures de pointe');

INSERT INTO marketplace_categories (name, icon_name, color_hex, sort_order) VALUES
  ('Transport & Déménagement', 'local_shipping',    '#FF6B35', 1),
  ('Matériaux & BTP',          'construction',      '#795548', 2),
  ('Alimentation & Agriculture','agriculture',      '#4CAF50', 3),
  ('Électronique & High-Tech', 'devices',           '#2196F3', 4),
  ('Meubles & Déco',           'chair',             '#9C27B0', 5),
  ('Véhicules & Pièces',       'directions_car',    '#FF9800', 6),
  ('Services Professionnels',  'business_center',   '#607D8B', 7),
  ('Autres',                   'category',          '#9E9E9E', 8);

INSERT INTO premium_options (name, type, description, duration_days, price, location_interval_seconds, position_boost, sort_order) VALUES
  ('Visibilité Premium 7j',   'visibility',         'Apparaître en 1er dans la liste pendant 7 jours',  7,  500,  NULL, 10, 1),
  ('Visibilité Premium 30j',  'visibility',         'Apparaître en 1er dans la liste pendant 30 jours', 30, 1500, NULL, 10, 2),
  ('Localisation Pro 7j',     'location_interval',  'Mise à jour GPS toutes les 5 secondes — 7 jours',  7,  300,  5,   0,  3),
  ('Localisation Pro 30j',    'location_interval',  'Mise à jour GPS toutes les 5 secondes — 30 jours', 30, 900,  5,   0,  4),
  ('Pack Complet 30j',        'badge_boost',        'Visibilité + Localisation Pro pendant 30 jours',   30, 2000, 5,   10, 5);

-- ============================================================
-- REALTIME: Activer dans dashboard Supabase
-- Tables à activer: trackings, transport_requests, notifications_log
-- Publication: supabase_realtime (INSERT pour trackings, ALL pour requests/notifs)
-- ============================================================
