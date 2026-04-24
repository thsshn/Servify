-- ═══════════════════════════════════════════════════════
--  SERVIFY — SUPABASE SETUP SQL
--  Run this entire file in: Supabase Dashboard → SQL Editor
--  Order matters — run top to bottom.
-- ═══════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────
-- 1. TABLES
-- ─────────────────────────────────────────────────────

-- profiles: one row per auth.users user, created on signup
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT,
  phone       TEXT,
  location    TEXT,
  role        TEXT NOT NULL DEFAULT 'seeker',   -- 'seeker' | 'provider' | 'admin'
  banned      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ
);

-- providers: extended profile for provider accounts
CREATE TABLE IF NOT EXISTS public.providers (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  business_name TEXT,
  category      TEXT,
  description   TEXT,
  tagline       TEXT,
  about         TEXT,
  years         INT,
  ssm           TEXT,
  phone         TEXT,
  email         TEXT,
  website       TEXT,
  facebook      TEXT,
  instagram     TEXT,
  addr1         TEXT,
  addr2         TEXT,
  city          TEXT,
  postcode      TEXT,
  state         TEXT,
  service_area  TEXT,
  hours         JSONB,
  gallery       JSONB,
  services_json TEXT,
  cover_url     TEXT,
  avatar_url    TEXT,
  status        TEXT NOT NULL DEFAULT 'pending',  -- 'pending' | 'active' | 'suspended'
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ
);

-- listings: individual service listings posted by providers
CREATE TABLE IF NOT EXISTS public.listings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  category      TEXT NOT NULL,
  description   TEXT,
  price         NUMERIC(10,2) NOT NULL DEFAULT 0,
  location      TEXT,
  phone         TEXT,
  provider_name TEXT,
  status        TEXT NOT NULL DEFAULT 'pending',  -- 'pending' | 'active' | 'rejected'
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- contacts: messages from the contact form and help requests
CREATE TABLE IF NOT EXISTS public.contacts (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT,
  email      TEXT,
  subject    TEXT,
  message    TEXT NOT NULL,
  user_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- reviews: customer reviews on listings
CREATE TABLE IF NOT EXISTS public.reviews (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id     UUID NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  reviewer_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewer_name  TEXT NOT NULL DEFAULT 'Anonymous',
  rating         INT NOT NULL DEFAULT 5 CHECK (rating BETWEEN 1 AND 5),
  comment        TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add updated_at index for listings (used in activity log queries)
CREATE INDEX IF NOT EXISTS idx_listings_updated_at ON public.listings(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_listings_status     ON public.listings(status);
CREATE INDEX IF NOT EXISTS idx_listings_user_id    ON public.listings(user_id);
CREATE INDEX IF NOT EXISTS idx_contacts_created_at ON public.contacts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_listing_id  ON public.reviews(listing_id);


-- ─────────────────────────────────────────────────────
-- 2. TRIGGER: auto-create profiles row on signup
--    Ensures profiles table is always populated even if
--    the client-side upsert fails (e.g. email not confirmed yet)
-- ─────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, created_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'seeker'),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ─────────────────────────────────────────────────────
-- 3. STORAGE BUCKET: provider-media
--    Create this bucket in Storage → New Bucket if it
--    doesn't exist, then run the policies below.
-- ─────────────────────────────────────────────────────

-- Allow authenticated users to upload to their own folder
-- (Run in Storage → Policies if not using SQL editor)
INSERT INTO storage.buckets (id, name, public)
VALUES ('provider-media', 'provider-media', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: allow authenticated uploads
CREATE POLICY "Authenticated users can upload provider media"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'provider-media');

CREATE POLICY "Provider media is publicly readable"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'provider-media');

CREATE POLICY "Users can update their own media"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'provider-media' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own media"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'provider-media' AND auth.uid()::text = (storage.foldername(name))[1]);


-- ─────────────────────────────────────────────────────
-- 4. ROW LEVEL SECURITY (RLS)
-- ─────────────────────────────────────────────────────

-- Enable RLS on all tables
ALTER TABLE public.profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews   ENABLE ROW LEVEL SECURITY;


-- ── profiles ──
-- Users can read and write their own profile
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

-- Admin can read all profiles (used in admin panel fallback)
CREATE POLICY "Admin can view all profiles"
  ON public.profiles FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

CREATE POLICY "Admin can update all profiles"
  ON public.profiles FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );


-- ── providers ──
-- Providers can read and write their own extended profile
CREATE POLICY "Providers can view own provider record"
  ON public.providers FOR SELECT TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Providers can insert own provider record"
  ON public.providers FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Providers can update own provider record"
  ON public.providers FOR UPDATE TO authenticated
  USING (auth.uid() = id);

-- Public can read providers (needed for seeker view of provider-profile)
CREATE POLICY "Anyone can view provider profiles"
  ON public.providers FOR SELECT TO anon
  USING (true);


-- ── listings ──
-- Anyone (including unauthenticated) can view active listings
CREATE POLICY "Anyone can view active listings"
  ON public.listings FOR SELECT TO anon
  USING (status = 'active');

-- Authenticated users can view active listings (and their own)
CREATE POLICY "Authenticated users can view active listings"
  ON public.listings FOR SELECT TO authenticated
  USING (status = 'active' OR user_id = auth.uid());

-- Providers can insert their own listings
CREATE POLICY "Providers can insert listings"
  ON public.listings FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Providers can update their own listings
CREATE POLICY "Providers can update own listings"
  ON public.listings FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- Providers can delete their own listings
CREATE POLICY "Providers can delete own listings"
  ON public.listings FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Admin can view, update, delete all listings
CREATE POLICY "Admin can view all listings"
  ON public.listings FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

CREATE POLICY "Admin can update all listings"
  ON public.listings FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

CREATE POLICY "Admin can delete all listings"
  ON public.listings FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );


-- ── contacts ──
-- Anyone can submit a contact message
CREATE POLICY "Anyone can insert contact messages"
  ON public.contacts FOR INSERT TO anon
  WITH CHECK (true);

CREATE POLICY "Authenticated users can insert contact messages"
  ON public.contacts FOR INSERT TO authenticated
  WITH CHECK (true);

-- Providers can view messages addressed to their listings
-- (Full inbox feature — simplified: providers read messages where user_id matches a listing they own)
CREATE POLICY "Providers can view enquiries about their listings"
  ON public.contacts FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );


-- ── reviews ──
-- Anyone can read reviews
CREATE POLICY "Anyone can read reviews"
  ON public.reviews FOR SELECT TO anon
  USING (true);

CREATE POLICY "Authenticated users can read reviews"
  ON public.reviews FOR SELECT TO authenticated
  USING (true);

-- Authenticated users can post reviews
CREATE POLICY "Authenticated users can post reviews"
  ON public.reviews FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reviewer_id);

-- Admin can delete reviews
CREATE POLICY "Admin can delete reviews"
  ON public.reviews FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );


-- ─────────────────────────────────────────────────────
-- 5. MAKE YOUR ACCOUNT AN ADMIN
--    Replace the email below with your actual admin email,
--    then run this AFTER you have signed up.
-- ─────────────────────────────────────────────────────

-- UPDATE public.profiles
-- SET role = 'admin'
-- WHERE id = (SELECT id FROM auth.users WHERE email = 'YOUR_ADMIN_EMAIL@example.com');


-- ─────────────────────────────────────────────────────
-- 6. VERIFY SETUP
-- ─────────────────────────────────────────────────────
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
