import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MEDIA_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

type Allowed = { id: string; name: string };

const SYSTEM =
  "You identify foods in a meal photo for a Vietnamese nutrition diary. " +
  "Only use foods from the provided catalog, by id. For each food you can see, " +
  "estimate the edible weight in grams on the plate, using the plate, bowl and " +
  "chopsticks for scale. Leave out anything you cannot match to the catalog. " +
  "If the photo shows no food, return an empty list.";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!geminiKey && !apiKey) return json({ error: "not_configured" }, 503);

  const auth = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: auth } } },
  );
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user) return json({ error: "unauthorized" }, 401);

  let body: { image?: string; mediaType?: string; foods?: Allowed[] };
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }
  const image = body.image ?? "";
  const mediaType = body.mediaType ?? "image/jpeg";
  const foods = (body.foods ?? []).filter(
    (f) => typeof f?.id === "string" && typeof f?.name === "string",
  ).slice(0, 400);
  if (!image || !MEDIA_TYPES.has(mediaType) || foods.length === 0) {
    return json({ error: "bad_request" }, 400);
  }
  if (image.length * 0.75 > MAX_IMAGE_BYTES) {
    return json({ error: "image_too_large" }, 413);
  }

  const ids = foods.map((f) => f.id);
  const catalog = foods.map((f) => `${f.id}: ${f.name}`).join("\n");
  const clean = (list: { food: string; grams: number }[] | undefined) =>
    (list ?? []).filter(
      (it) =>
        ids.includes(it.food) && Number.isFinite(it.grams) && it.grams > 0 &&
        it.grams < 3000,
    );

  if (geminiKey) {
    const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM }] },
          contents: [{
            role: "user",
            parts: [
              { inline_data: { mime_type: mediaType, data: image } },
              { text: `Catalog (id: name):\n${catalog}` },
            ],
          }],
          generationConfig: {
            temperature: 0,
            responseMimeType: "application/json",
            responseSchema: {
              type: "OBJECT",
              properties: {
                items: {
                  type: "ARRAY",
                  items: {
                    type: "OBJECT",
                    properties: {
                      food: { type: "STRING" },
                      grams: { type: "NUMBER" },
                    },
                    required: ["food", "grams"],
                  },
                },
              },
              required: ["items"],
            },
          },
        }),
      },
    );
    if (res.status === 429) return json({ error: "busy" }, 429);
    if (!res.ok) {
      console.error("[food-photo] gemini", res.status, await res.text());
      return json({ error: "upstream" }, 502);
    }
    try {
      const out = await res.json();
      if (out?.promptFeedback?.blockReason) return json({ items: [], refused: true });
      const text = (out?.candidates?.[0]?.content?.parts ?? [])
        .map((p: { text?: string }) => p.text ?? "")
        .join("");
      const parsed = JSON.parse(text) as { items?: { food: string; grams: number }[] };
      return json({ items: clean(parsed.items) });
    } catch {
      return json({ error: "parse_failed" }, 502);
    }
  }

  const client = new Anthropic({ apiKey });

  try {
    const response = await client.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: {
        effort: "low",
        format: {
          type: "json_schema",
          schema: {
            type: "object",
            properties: {
              items: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    food: { type: "string", enum: ids },
                    grams: { type: "number" },
                  },
                  required: ["food", "grams"],
                  additionalProperties: false,
                },
              },
            },
            required: ["items"],
            additionalProperties: false,
          },
        },
      },
      system: SYSTEM,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: { type: "base64", media_type: mediaType, data: image },
            },
            { type: "text", text: `Catalog (id: name):\n${catalog}` },
          ],
        },
      ],
    } as Anthropic.Beta.MessageCreateParamsNonStreaming);

    if (response.stop_reason === "refusal") {
      return json({ items: [], refused: true });
    }
    const text = response.content
      .filter((b) => b.type === "text")
      .map((b) => (b as { text: string }).text)
      .join("");
    const parsed = JSON.parse(text) as { items?: { food: string; grams: number }[] };
    return json({ items: clean(parsed.items) });
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) return json({ error: "busy" }, 429);
    if (error instanceof Anthropic.APIError) return json({ error: "upstream" }, 502);
    return json({ error: "parse_failed" }, 502);
  }
});
