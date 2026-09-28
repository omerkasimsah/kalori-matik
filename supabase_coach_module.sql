-- ============================================================
-- Kalori Matik — Koç/Diyetisyen Gelişmiş Modül SQL
-- Supabase SQL Editor'de çalıştırın
-- ============================================================

-- Koç tarafından danışana atanan antrenman planları
CREATE TABLE IF NOT EXISTS workout_plans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  coach_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  client_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  week_day TEXT, -- 'Pazartesi', 'Salı', vb.
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Her planın egzersiz kalemleri (set/rep/süre)
CREATE TABLE IF NOT EXISTS workout_exercises (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  plan_id UUID REFERENCES workout_plans(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL, -- 'Güç', 'Kardio', 'HIIT', 'Esneklik'
  sets INTEGER DEFAULT 3,
  reps INTEGER DEFAULT 12,
  duration_sec INTEGER, -- Kardio için süre (saniye)
  rest_sec INTEGER DEFAULT 60,
  notes TEXT,
  order_index INTEGER DEFAULT 0
);

-- Koç tarafından danışana atanan beslenme planı öğünleri
CREATE TABLE IF NOT EXISTS nutrition_plans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  coach_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  client_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  meal_time TEXT NOT NULL, -- 'Kahvaltı', 'Öğle', 'Akşam', 'Ara Öğün'
  meal_name TEXT NOT NULL,
  target_calories INTEGER,
  target_protein NUMERIC,
  target_carbs NUMERIC,
  target_fat NUMERIC,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Koç notları / ilerleme yorumları
CREATE TABLE IF NOT EXISTS coach_notes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  coach_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  client_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  note TEXT NOT NULL,
  category TEXT DEFAULT 'genel', -- 'genel', 'beslenme', 'antrenman', 'motivasyon'
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- RLS politikaları
ALTER TABLE workout_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_notes ENABLE ROW LEVEL SECURITY;

-- Koç kendi planlarını yönetir
DROP POLICY IF EXISTS "Coach manages workout plans" ON workout_plans;
CREATE POLICY "Coach manages workout plans" ON workout_plans
  USING (auth.uid() = coach_id OR auth.uid() = client_id);

DROP POLICY IF EXISTS "Coach manages exercises" ON workout_exercises;
CREATE POLICY "Coach manages exercises" ON workout_exercises
  USING (
    EXISTS (SELECT 1 FROM workout_plans WHERE id = workout_exercises.plan_id AND (coach_id = auth.uid() OR client_id = auth.uid()))
  );

DROP POLICY IF EXISTS "Coach manages nutrition plans" ON nutrition_plans;
CREATE POLICY "Coach manages nutrition plans" ON nutrition_plans
  USING (auth.uid() = coach_id OR auth.uid() = client_id);

DROP POLICY IF EXISTS "Coach manages notes" ON coach_notes;
CREATE POLICY "Coach manages notes" ON coach_notes
  USING (auth.uid() = coach_id OR auth.uid() = client_id);

SELECT 'Koç/Diyetisyen modülü tabloları oluşturuldu.' AS status;
