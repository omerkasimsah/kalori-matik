-- ============================================================
-- Kalori Matik — Phase 3 Veritabanı Güncellemesi
-- supabase_setup.sql, supabase_phase25.sql ve supabase_coach_module.sql
-- dosyalarından SONRA Supabase SQL Editor'de çalıştırın.
-- Tekrar çalıştırılması güvenlidir (idempotent).
-- ============================================================

-- 1. Kullanıcılar kendi öğünlerini düzenleyip silebilsin
DROP POLICY IF EXISTS "Users can update own meal logs" ON meal_logs;
CREATE POLICY "Users can update own meal logs"
  ON meal_logs FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own meal logs" ON meal_logs;
CREATE POLICY "Users can delete own meal logs"
  ON meal_logs FOR DELETE
  USING (auth.uid() = user_id);

-- 2. Sorgu performansı: kullanıcı + tarih bazlı öğün sorguları
CREATE INDEX IF NOT EXISTS meal_logs_user_created_idx
  ON meal_logs (user_id, created_at DESC);

-- 3. Koçların KaloriID ile danışan bulabilmesi.
-- RLS, henüz bağlantı kurulmamış profilleri gizlediğinden doğrudan sorgu
-- her zaman boş döner. Bu fonksiyon yalnızca id ve rol bilgisini açığa çıkarır.
CREATE OR REPLACE FUNCTION find_client_by_kalori_id(p_kalori_id TEXT)
RETURNS TABLE (id UUID, role VARCHAR)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id, p.role
  FROM profiles p
  WHERE p.kalori_id = UPPER(TRIM(p_kalori_id))
    AND auth.uid() IS NOT NULL
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION find_client_by_kalori_id(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION find_client_by_kalori_id(TEXT) TO authenticated;

-- 4. Danışan veya koç bağlantıyı sonlandırabilsin
DROP POLICY IF EXISTS "Participants can delete connections" ON connections;
CREATE POLICY "Participants can delete connections"
  ON connections FOR DELETE
  USING (auth.uid() = professional_id OR auth.uid() = client_id);

SELECT 'Phase 3 kurulumu tamamlandı.' AS status;
