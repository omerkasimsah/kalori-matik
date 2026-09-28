-- ============================================================
-- Kalori Matik — Phase 2.5 Veritabanı (TAM KURULUM)
-- Supabase SQL Editor'de çalıştırın
-- ============================================================

-- 1. Eksik kolonları ekle
ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS target_weight_loss NUMERIC,
  ADD COLUMN IF NOT EXISTS target_days INTEGER,
  ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'client',
  ADD COLUMN IF NOT EXISTS kalori_id VARCHAR(10) UNIQUE;

-- 2. connections tablosunu oluştur (yoksa)
CREATE TABLE IF NOT EXISTS connections (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  professional_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  client_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(professional_id, client_id)
);

-- 3. RLS aktif et
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;

-- 4. connections RLS politikaları
DROP POLICY IF EXISTS "Professionals can view their connections" ON connections;
CREATE POLICY "Professionals can view their connections"
  ON connections FOR SELECT
  USING (auth.uid() = professional_id OR auth.uid() = client_id);

DROP POLICY IF EXISTS "Professionals can insert connections" ON connections;
CREATE POLICY "Professionals can insert connections"
  ON connections FOR INSERT
  WITH CHECK (auth.uid() = professional_id);

-- 5. KaloriID otomatik oluşturma fonksiyonu
CREATE OR REPLACE FUNCTION generate_kalori_id()
RETURNS TRIGGER AS $$
DECLARE
  new_id VARCHAR(10);
  exists_check INTEGER;
BEGIN
  IF NEW.kalori_id IS NULL THEN
    LOOP
      new_id := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 6));
      SELECT COUNT(*) INTO exists_check FROM profiles WHERE kalori_id = new_id;
      EXIT WHEN exists_check = 0;
    END LOOP;
    NEW.kalori_id := new_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Trigger: insert sırasında KaloriID ata
DROP TRIGGER IF EXISTS trigger_generate_kalori_id ON profiles;
CREATE TRIGGER trigger_generate_kalori_id
  BEFORE INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION generate_kalori_id();

-- 7. Mevcut kayıtlara KaloriID ekle (henüz yoksa)
UPDATE profiles 
SET kalori_id = UPPER(SUBSTRING(MD5(RANDOM()::TEXT || id::TEXT) FROM 1 FOR 6))
WHERE kalori_id IS NULL;

-- 8. Profesyonellerin danışan profilini görmesi için politika
DROP POLICY IF EXISTS "Professionals can view client profiles" ON profiles;
CREATE POLICY "Professionals can view client profiles"
  ON profiles FOR SELECT
  USING (
    auth.uid() = id
    OR EXISTS (
      SELECT 1 FROM connections
      WHERE connections.professional_id = auth.uid()
        AND connections.client_id = profiles.id
        AND connections.status = 'active'
    )
  );

-- 9. Profesyonellerin danışan meal_logs'unu görmesi
DROP POLICY IF EXISTS "Professionals can view client meal logs" ON meal_logs;
CREATE POLICY "Professionals can view client meal logs"
  ON meal_logs FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM connections
      WHERE connections.professional_id = auth.uid()
        AND connections.client_id = meal_logs.user_id
        AND connections.status = 'active'
    )
  );

-- 10. Profesyonellerin danışan profilini güncellemesi
DROP POLICY IF EXISTS "Professionals can update client profiles" ON profiles;
CREATE POLICY "Professionals can update client profiles"
  ON profiles FOR UPDATE
  USING (
    auth.uid() = id
    OR EXISTS (
      SELECT 1 FROM connections
      WHERE connections.professional_id = auth.uid()
        AND connections.client_id = profiles.id
        AND connections.status = 'active'
    )
  );

-- Tamamlandı!
SELECT 'Kurulum tamamlandi. Mevcut kullanicilar icin KaloriID atandi.' AS status;
