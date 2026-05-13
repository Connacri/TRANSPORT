-- Migration: Initial Schema for Cargoza
-- This script sets up the tables, RLS policies, and functions for the Cargoza app.

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. REGIONS
CREATE TABLE IF NOT EXISTS public.regions (
    id text PRIMARY KEY,
    name text NOT NULL,
    country text NOT NULL,
    currency text DEFAULT 'DZD' NOT NULL,
    currency_symbol text DEFAULT 'DA' NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);

-- 3. PROFILES
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    firebase_uid text UNIQUE NOT NULL,
    email text UNIQUE NOT NULL,
    full_name text,
    phone text,
    role text DEFAULT 'public' NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_email_verified boolean DEFAULT false NOT NULL,
    avatar_url text,
    region_id text REFERENCES public.regions(id),
    last_seen timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 4. TRANSPORTERS
CREATE TABLE IF NOT EXISTS public.transporters (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    vehicle_type text NOT NULL,
    vehicle_brand text,
    vehicle_model text,
    vehicle_year integer,
    vehicle_plate text NOT NULL,
    vehicle_capacity_kg numeric,
    vehicle_capacity_m3 numeric,
    vehicle_photo_url text NOT NULL,
    face_photo_url text,
    license_photo_url text,
    registration_photo_url text,
    insurance_photo_url text,
    technical_control_url text,
    is_validated boolean DEFAULT false NOT NULL,
    validation_score integer DEFAULT 0 NOT NULL,
    badge text,
    validated_by uuid REFERENCES public.profiles(id),
    validated_at timestamp with time zone,
    suspension_reason text,
    is_available boolean DEFAULT false NOT NULL,
    offers_handling boolean DEFAULT false NOT NULL,
    handling_fee_rate numeric DEFAULT 0 NOT NULL,
    offers_transport_insurance boolean DEFAULT false NOT NULL,
    insurance_rate_percent numeric DEFAULT 0 NOT NULL,
    base_price_per_km numeric,
    minimum_price numeric,
    is_premium boolean DEFAULT false NOT NULL,
    premium_until timestamp with time zone,
    premium_type text,
    location_interval_seconds integer DEFAULT 30 NOT NULL,
    average_rating numeric DEFAULT 0 NOT NULL,
    total_ratings integer DEFAULT 0 NOT NULL,
    total_transports integer DEFAULT 0 NOT NULL,
    current_lat numeric,
    current_lng numeric,
    last_location_at timestamp with time zone,
    region_id text REFERENCES public.regions(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 5. TRANSPORT REQUESTS
CREATE TABLE IF NOT EXISTS public.transport_requests (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.profiles(id) NOT NULL,
    transporter_id uuid REFERENCES public.transporters(id),
    pickup_lat numeric NOT NULL,
    pickup_lng numeric NOT NULL,
    pickup_address text,
    dropoff_lat numeric NOT NULL,
    dropoff_lng numeric NOT NULL,
    dropoff_address text,
    estimated_distance_km numeric,
    estimated_duration_min integer,
    cargo_description text,
    cargo_weight_kg numeric,
    needs_handling boolean DEFAULT false NOT NULL,
    needs_transport_insurance boolean DEFAULT false NOT NULL,
    base_price numeric,
    handling_fee numeric DEFAULT 0 NOT NULL,
    insurance_fee numeric DEFAULT 0 NOT NULL,
    total_price numeric,
    currency text DEFAULT 'DZD' NOT NULL,
    app_commission_amount numeric,
    supervisor_commission_amount numeric,
    transporter_net_amount numeric,
    status text DEFAULT 'pending' NOT NULL,
    payment_status text DEFAULT 'pending' NOT NULL,
    payment_boutique_id text,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    accepted_at timestamp with time zone,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    cancellation_reason text,
    region_id text REFERENCES public.regions(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 6. TRACKINGS
CREATE TABLE IF NOT EXISTS public.trackings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    request_id uuid REFERENCES public.transport_requests(id) ON DELETE CASCADE NOT NULL,
    transporter_id uuid REFERENCES public.transporters(id) NOT NULL,
    lat numeric NOT NULL,
    lng numeric NOT NULL,
    speed_kmh numeric,
    heading numeric,
    accuracy_m numeric,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 7. RATINGS
CREATE TABLE IF NOT EXISTS public.ratings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    request_id uuid REFERENCES public.transport_requests(id) NOT NULL,
    transporter_id uuid REFERENCES public.transporters(id) NOT NULL,
    client_id uuid REFERENCES public.profiles(id) NOT NULL,
    score integer NOT NULL CHECK (score >= 1 AND score <= 5),
    comment text,
    is_visible boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 8. SUPERVISORS
CREATE TABLE IF NOT EXISTS public.supervisors (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    tier text DEFAULT 'silver' NOT NULL,
    max_transporters integer DEFAULT 20 NOT NULL,
    commission_from_transports_rate numeric DEFAULT 5.0 NOT NULL,
    commission_to_app_rate numeric DEFAULT 2.0 NOT NULL,
    current_month_year text,
    transporters_added_this_month integer DEFAULT 0 NOT NULL,
    min_monthly_add_required integer DEFAULT 5 NOT NULL,
    is_commission_active boolean DEFAULT true NOT NULL,
    commission_suspended_reason text,
    total_gross_earnings numeric DEFAULT 0 NOT NULL,
    total_app_fees_paid numeric DEFAULT 0 NOT NULL,
    total_net_earnings numeric DEFAULT 0 NOT NULL,
    parent_supervisor_id uuid REFERENCES public.supervisors(id),
    referral_code text UNIQUE,
    region_id text REFERENCES public.regions(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 9. SUPERVISOR REFERRALS
CREATE TABLE IF NOT EXISTS public.supervisor_referrals (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    supervisor_id uuid REFERENCES public.supervisors(id) ON DELETE CASCADE NOT NULL,
    transporter_id uuid REFERENCES public.transporters(id) ON DELETE CASCADE NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    UNIQUE(supervisor_id, transporter_id)
);

-- 10. NOTIFICATIONS LOG
CREATE TABLE IF NOT EXISTS public.notifications_log (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    recipient_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    type text,
    is_read boolean DEFAULT false NOT NULL,
    sent_via_fcm boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 11. FCM TOKENS
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    token text NOT NULL,
    platform text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    UNIQUE(profile_id, platform)
);

-- 12. MARKETPLACE
CREATE TABLE IF NOT EXISTS public.marketplace_categories (
    id text PRIMARY KEY,
    name text NOT NULL,
    icon text,
    sort_order integer DEFAULT 0 NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_listings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    seller_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    description text,
    category_id text REFERENCES public.marketplace_categories(id),
    type text DEFAULT 'product' NOT NULL,
    price numeric,
    is_price_negotiable boolean DEFAULT false NOT NULL,
    currency text DEFAULT 'DZD' NOT NULL,
    images_urls text[] DEFAULT '{}'::text[] NOT NULL,
    region_id text REFERENCES public.regions(id),
    city text,
    status text DEFAULT 'active' NOT NULL,
    commission_rate numeric DEFAULT 5.0 NOT NULL,
    is_premium boolean DEFAULT false NOT NULL,
    premium_until timestamp with time zone,
    views_count integer DEFAULT 0 NOT NULL,
    is_verified boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 13. BUSINESS RULES
CREATE TABLE IF NOT EXISTS public.business_rules (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    key text UNIQUE NOT NULL,
    value jsonb NOT NULL,
    region_id text REFERENCES public.regions(id),
    applies_to_role text,
    description text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 14. PREMIUM OPTIONS & PURCHASES
CREATE TABLE IF NOT EXISTS public.premium_options (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    type text NOT NULL,
    description text,
    duration_days integer NOT NULL,
    price numeric NOT NULL,
    currency text DEFAULT 'DZD' NOT NULL,
    location_interval_seconds integer,
    position_boost integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    region_id text REFERENCES public.regions(id),
    sort_order integer DEFAULT 0 NOT NULL
);

CREATE TABLE IF NOT EXISTS public.premium_purchases (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    transporter_id uuid REFERENCES public.transporters(id) ON DELETE CASCADE NOT NULL,
    option_id uuid REFERENCES public.premium_options(id) NOT NULL,
    boutique_id text,
    amount_paid numeric NOT NULL,
    status text DEFAULT 'pending_payment' NOT NULL,
    validated_by uuid REFERENCES public.profiles(id),
    validated_at timestamp with time zone,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 15. BOUTIQUES (Points de paiement)
CREATE TABLE IF NOT EXISTS public.boutiques (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    address text,
    phone text,
    region_id text REFERENCES public.regions(id),
    status text DEFAULT 'pending' NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- ─── ROW LEVEL SECURITY (RLS) ───────────────────────────────────

-- Since the app uses Firebase Auth and requests are coming as 'anon',
-- we will enable RLS and add permissive policies for now.
-- In a real production environment, you should verify the Firebase JWT.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transporters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transport_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trackings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supervisors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supervisor_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.premium_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.premium_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boutiques ENABLE ROW LEVEL SECURITY;

-- Permissive policies for 'anon' role (development/testing)
DO $$ 
DECLARE 
    t text;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
          AND table_type = 'BASE TABLE'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Anon All Access" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Anon All Access" ON public.%I FOR ALL USING (true) WITH CHECK (true)', t);
    END LOOP;
END $$;

-- ─── FUNCTIONS & RPC ──────────────────────────────────────────

-- Nearby transporters function
CREATE OR REPLACE FUNCTION get_nearby_transporters(
  user_lat numeric,
  user_lng numeric,
  radius_km numeric,
  vehicle_type_filter text DEFAULT NULL
)
RETURNS SETOF jsonb AS $$
BEGIN
  RETURN QUERY
  SELECT row_to_json(t_all)::jsonb
  FROM (
    SELECT t.*, row_to_json(p) as profiles
    FROM transporters t
    JOIN profiles p ON t.profile_id = p.id
    WHERE p.is_active = true
      AND t.is_validated = true
      AND t.is_available = true
      AND (vehicle_type_filter IS NULL OR t.vehicle_type = vehicle_type_filter)
      AND (
        6371 * acos(
          cos(radians(user_lat)) * cos(radians(t.current_lat)) *
          cos(radians(t.current_lng) - radians(user_lng)) +
          sin(radians(user_lat)) * sin(radians(t.current_lat))
        )
      ) <= radius_km
  ) t_all;
END;
$$ LANGUAGE plpgsql;

-- ─── TRIGGERS FOR UPDATED_AT ────────────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DO $$ 
DECLARE 
    t text;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
          AND table_name IN ('profiles', 'transporters', 'transport_requests', 'supervisors', 'fcm_tokens', 'marketplace_listings', 'business_rules')
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON public.%I', t);
        EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column()', t);
    END LOOP;
END $$;
