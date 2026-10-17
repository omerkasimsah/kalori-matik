// Supabase Edge Function: analyze-food
// Gemini API anahtarını uygulamanın dışında (sunucuda) tutar.
//
// Kurulum:
//   supabase secrets set GEMINI_API_KEY=<anahtarın>
//   supabase functions deploy analyze-food
//
// Fonksiyon varsayılan olarak oturum (JWT) ister; yalnızca giriş yapmış
// kullanıcılar çağırabilir.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DAILY_LIMIT = Number(Deno.env.get("AI_DAILY_LIMIT") ?? "30");
const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const MAX_IMAGE_CHARS = 4_000_000; // ~3 MB base64
const ALLOWED_MIME = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
]);

const PROMPT = `Sen uzman bir diyetisyensin. Fotoğraftaki yemeği/yemekleri tanı ve tabaktaki toplam porsiyonu tahmin et.
SADECE GEÇERLİ BİR JSON objesi döndür. Markdown blokları (\`\`\`json) KULLANMA.
Beklenen format:
{
  "name": "Yemek Adı (Türkçe)",
  "calories": 450,
  "protein": 25.5,
  "carbs": 40.0,
  "fat": 12.0,
  "insight": "Kısa, motive edici ve bilgilendirici Türkçe besin notu (max 1 cümle)"
}
Fotoğrafta yiyecek yoksa "name" alanını "Yiyecek bulunamadı" ve tüm sayıları 0 yap.
Değerler tahmini olabilir. Rakamlar DAIMA sayı türünde olsun (string değil).`;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // Kullanıcı başına günlük analiz sınırı (supabase_phase6.sql)
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );
  const { data: allowed, error: quotaError } = await supabase.rpc(
    "consume_ai_quota",
    { p_limit: DAILY_LIMIT },
  );
  if (quotaError) return json({ error: "quota_check_failed" }, 500);
  if (allowed !== true) return json({ error: "daily_limit", limit: DAILY_LIMIT }, 429);

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return json({ error: "server_not_configured" }, 500);

  let payload: { image?: string; mimeType?: string };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const image = payload.image;
  const mimeType = payload.mimeType ?? "image/jpeg";
  if (!image || typeof image !== "string") {
    return json({ error: "image_required" }, 400);
  }
  if (image.length > MAX_IMAGE_CHARS) return json({ error: "image_too_large" }, 413);
  if (!ALLOWED_MIME.has(mimeType)) return json({ error: "unsupported_type" }, 415);

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: PROMPT },
            { inline_data: { mime_type: mimeType, data: image } },
          ],
        }],
        generationConfig: { temperature: 0.4, responseMimeType: "application/json" },
      }),
    },
  );

  if (!res.ok) {
    // Ayrıntıyı istemciye sızdırmadan durum kodunu ilet
    return json({ error: "upstream_error", status: res.status }, 502);
  }

  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== "string") return json({ error: "empty_response" }, 502);
  return json({ text });
});
