-- ============================================================
-- Kalori Matik — Phase 5: Danışan onayı + güvenlik sıkılaştırma
-- supabase_phase4.sql'den SONRA çalıştırın. Tekrar çalıştırılabilir.
-- ============================================================

-- 1. Bağlantı durumları: 'pending' (davet) | 'active' (onaylı)
--    Koç yalnızca 'pending' bağlantı oluşturabilir; veriler 'active' olunca açılır.
ALTER TABLE connections ALTER COLUMN status SET DEFAULT 'pending';

DROP POLICY IF EXISTS "Professionals can insert connections" ON connections;
CREATE POLICY "Professionals can insert connections"
  ON connections FOR INSERT
  WITH CHECK (auth.uid() = professional_id AND status = 'pending');

-- Koç, bağlantının durumunu kendi başına değiştiremez (yalnızca danışan onaylar).
DROP POLICY IF EXISTS "Participants can delete connections" ON connections;
CREATE POLICY "Participants can delete connections"
  ON connections FOR DELETE
  USING (auth.uid() = professional_id OR auth.uid() = client_id);

-- 2. Danışanın bağlantılarını (koç adı/rolü ile) listelemesi
CREATE OR REPLACE FUNCTION my_connections()
RETURNS TABLE (
  id UUID,
  status TEXT,
  created_at TIMESTAMPTZ,
  professional_id UUID,
  professional_name TEXT,
  professional_role TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.id, c.status::TEXT, c.created_at, c.professional_id,
         p.full_name, p.role::TEXT
  FROM connections c
  LEFT JOIN profiles p ON p.id = c.professional_id
  WHERE c.client_id = auth.uid()
  ORDER BY c.created_at DESC;
$$;

REVOKE ALL ON FUNCTION my_connections() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION my_connections() TO authenticated;

-- 3. Davete yanıt: kabul → active, ret → silinir
CREATE OR REPLACE FUNCTION respond_to_connection(p_id UUID, p_accept BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM connections
    WHERE id = p_id AND client_id = auth.uid() AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'Davet bulunamadı';
  END IF;

  IF p_accept THEN
    UPDATE connections SET status = 'active' WHERE id = p_id;
  ELSE
    DELETE FROM connections WHERE id = p_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION respond_to_connection(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION respond_to_connection(UUID, BOOLEAN) TO authenticated;

-- 4. Koçun yazma yetkisi yalnızca ONAYLI danışanlar için
DROP POLICY IF EXISTS "Coach manages workout plans" ON workout_plans;
DROP POLICY IF EXISTS "Client reads workout plans" ON workout_plans;
CREATE POLICY "Coach manages workout plans" ON workout_plans
  USING (auth.uid() = coach_id AND EXISTS (
    SELECT 1 FROM connections c WHERE c.professional_id = auth.uid()
      AND c.client_id = workout_plans.client_id AND c.status = 'active'))
  WITH CHECK (auth.uid() = coach_id AND EXISTS (
    SELECT 1 FROM connections c WHERE c.professional_id = auth.uid()
      AND c.client_id = workout_plans.client_id AND c.status = 'active'));
CREATE POLICY "Client reads workout plans" ON workout_plans
  FOR SELECT USING (auth.uid() = client_id);

DROP POLICY IF EXISTS "Coach manages exercises" ON workout_exercises;
DROP POLICY IF EXISTS "Client reads exercises" ON workout_exercises;
CREATE POLICY "Coach manages exercises" ON workout_exercises
  USING (EXISTS (SELECT 1 FROM workout_plans w WHERE w.id = workout_exercises.plan_id
    AND w.coach_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM workout_plans w WHERE w.id = workout_exercises.plan_id
    AND w.coach_id = auth.uid()));
CREATE POLICY "Client reads exercises" ON workout_exercises
  FOR SELECT USING (EXISTS (SELECT 1 FROM workout_plans w
    WHERE w.id = workout_exercises.plan_id AND w.client_id = auth.uid()));

DROP POLICY IF EXISTS "Coach manages nutrition plans" ON nutrition_plans;
DROP POLICY IF EXISTS "Client reads nutrition plans" ON nutrition_plans;
CREATE POLICY "Coach manages nutrition plans" ON nutrition_plans
  USING (auth.uid() = coach_id AND EXISTS (
    SELECT 1 FROM connections c WHERE c.professional_id = auth.uid()
      AND c.client_id = nutrition_plans.client_id AND c.status = 'active'))
  WITH CHECK (auth.uid() = coach_id AND EXISTS (
    SELECT 1 FROM connections c WHERE c.professional_id = auth.uid()
      AND c.client_id = nutrition_plans.client_id AND c.status = 'active'));
CREATE POLICY "Client reads nutrition plans" ON nutrition_plans
  FOR SELECT USING (auth.uid() = client_id);

DROP POLICY IF EXISTS "Coach manages notes" ON coach_notes;
DROP POLICY IF EXISTS "Client reads notes" ON coach_notes;
CREATE POLICY "Coach manages notes" ON coach_notes
  USING (auth.uid() = coach_id AND EXISTS (
    SELECT 1 FROM connections c WHERE c.professional_id = auth.uid()
      AND c.client_id = coach_notes.client_id AND c.status = 'active'))
  WITH CHECK (auth.uid() = coach_id AND EXISTS (
    SELECT 1 FROM connections c WHERE c.professional_id = auth.uid()
      AND c.client_id = coach_notes.client_id AND c.status = 'active'));
CREATE POLICY "Client reads notes" ON coach_notes
  FOR SELECT USING (auth.uid() = client_id);

-- 5. Koç, danışanın profilinde kimlik alanlarını (rol, KaloriID, ad) değiştiremez
CREATE OR REPLACE FUNCTION protect_profile_identity()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM NEW.id THEN
    NEW.role := OLD.role;
    NEW.kalori_id := OLD.kalori_id;
    NEW.full_name := OLD.full_name;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_protect_profile_identity ON profiles;
CREATE TRIGGER trigger_protect_profile_identity
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION protect_profile_identity();

-- 6. Önceki sürümde eklenmiş, onay beklemeyen bağlantılar onaylı kalır (geriye uyum).
UPDATE connections SET status = 'active' WHERE status IS NULL;

SELECT 'Phase 5 kurulumu tamamlandı.' AS status;
