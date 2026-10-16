-- ============================================================
-- Kalori Matik — Phase 4: Koç takibi + Google Play gereksinimleri
-- supabase_phase3.sql'den SONRA çalıştırın. Tekrar çalıştırılabilir.
-- ============================================================

-- 1. Koçun öğüne yorum bırakması
ALTER TABLE meal_logs
  ADD COLUMN IF NOT EXISTS coach_comment TEXT,
  ADD COLUMN IF NOT EXISTS coach_comment_at TIMESTAMPTZ;

-- Koç yalnızca bağlı danışanının öğününe ve yalnızca yorum alanına yazabilir.
CREATE OR REPLACE FUNCTION set_meal_feedback(p_meal_id UUID, p_comment TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM meal_logs m
    JOIN connections c ON c.client_id = m.user_id
    WHERE m.id = p_meal_id
      AND c.professional_id = auth.uid()
      AND c.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Bu öğüne yorum yapma yetkiniz yok';
  END IF;

  UPDATE meal_logs
  SET coach_comment = NULLIF(TRIM(p_comment), ''),
      coach_comment_at = CASE WHEN NULLIF(TRIM(p_comment), '') IS NULL THEN NULL ELSE NOW() END
  WHERE id = p_meal_id;
END;
$$;

REVOKE ALL ON FUNCTION set_meal_feedback(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION set_meal_feedback(UUID, TEXT) TO authenticated;

-- 2. Kilo takibi
CREATE TABLE IF NOT EXISTS weight_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  weight NUMERIC NOT NULL CHECK (weight > 20 AND weight < 400),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS weight_logs_user_created_idx
  ON weight_logs (user_id, created_at DESC);

ALTER TABLE weight_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own weight logs" ON weight_logs;
CREATE POLICY "Users manage own weight logs"
  ON weight_logs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Professionals view client weight logs" ON weight_logs;
CREATE POLICY "Professionals view client weight logs"
  ON weight_logs FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM connections
    WHERE connections.professional_id = auth.uid()
      AND connections.client_id = weight_logs.user_id
      AND connections.status = 'active'
  ));

-- 3. Uygulama içinden hesap silme (Google Play zorunluluğu).
-- auth.users silinince profiles, meal_logs, connections vb. CASCADE ile silinir.
CREATE OR REPLACE FUNCTION delete_my_account()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Giriş yapılmamış';
  END IF;
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_my_account() TO authenticated;

-- 4. Ad soyad (koç panelinde danışanı tanımak için)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS full_name TEXT;

-- 5. Danışan, koç bağlantısının kimden olduğunu görebilsin (profil adı/rolü)
DROP POLICY IF EXISTS "Clients can view their professionals" ON profiles;
CREATE POLICY "Clients can view their professionals"
  ON profiles FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM connections
    WHERE connections.client_id = auth.uid()
      AND connections.professional_id = profiles.id
      AND connections.status = 'active'
  ));

SELECT 'Phase 4 kurulumu tamamlandı.' AS status;
