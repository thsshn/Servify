-- ═══════════════════════════════════════════════════════
--  SERVIFY — FEATURES UPDATE SQL
--  Run in Supabase Dashboard → SQL Editor
--  Adds: saved_listings, view_count, reviews submit RLS
-- ═══════════════════════════════════════════════════════

-- Add saved_listings to profiles (array of listing IDs)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS saved_listings UUID[] DEFAULT '{}';

-- Add view_count to listings
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS view_count INT NOT NULL DEFAULT 0;

-- Function to safely increment view count
CREATE OR REPLACE FUNCTION public.increment_listing_views(listing_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.listings SET view_count = view_count + 1 WHERE id = listing_id;
END;
$$;

-- Allow anyone to call the increment function
GRANT EXECUTE ON FUNCTION public.increment_listing_views(UUID) TO anon, authenticated;

-- Allow users to update their own saved_listings in profiles
DROP POLICY IF EXISTS "Users can update own saved listings" ON public.profiles;
CREATE POLICY "Users can update own saved listings"
  ON public.profiles FOR UPDATE TO authenticated
  USING (auth.uid() = id);
