-- ============================================================
-- Kalori Matik — Phase 6: Yapay zeka kullanım sınırı
-- supabase_phase5.sql'den SONRA çalıştırın. Tekrar çalıştırılabilir.
-- ============================================================

-- Her yapay zeka analizi bir satır bırakır; kullanıcı başına günlük sınır uygulanır.
CREATE TABLE IF NOT EXISTS ai_usage (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ai_usage_user_created_idx
  ON ai_usage (user_id, created_at DESC);

-- RLS açık, hiçbir politika yok: tabloya yalnızca aşağıdaki fonksiyon erişir.
ALTER TABLE ai_usage ENABLE ROW LEVEL SECURITY;

-- Hakkı varsa bir kullanım kaydeder ve true döner; sınır dolduysa false döner.
CREATE OR REPLACE FUNCTION consume_ai_quota(p_limit INTEGER DEFAULT 30)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  used INTEGER;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Eski kayıtları temizle (tablo şişmesin)
  DELETE FROM ai_usage
  WHERE user_id = auth.uid() AND created_at < NOW() - INTERVAL '2 days';

  SELECT COUNT(*) INTO used
  FROM ai_usage
  WHERE user_id = auth.uid() AND created_at > NOW() - INTERVAL '24 hours';

  IF used >= p_limit THEN
    RETURN FALSE;
  END IF;

  INSERT INTO ai_usage (user_id) VALUES (auth.uid());
  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION consume_ai_quota(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION consume_ai_quota(INTEGER) TO authenticated;

SELECT 'Phase 6 kurulumu tamamlandı.' AS status;
