// Supabase Edge Function: user_discover
//
// Purpose:
// - Authenticated discover endpoint for the app
// - Returns active + discoverable profiles, excluding the current user
// - Supports simple filtering + pagination
// - Designed to work with RLS by forwarding the caller JWT to PostgREST

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS_HEADERS, "content-type": "application/json; charset=utf-8" } });
}

function requireBearerAuth(req: Request) {
  const auth = req.headers.get("authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) throw new Error("Missing Authorization header");
  return auth;
}

type RequestBody = {
  limit?: number;
  offset?: number;
  ageMin?: number;
  ageMax?: number;
  country?: string;
  city?: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });

  try {
    const authHeader = requireBearerAuth(req);

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    if (!supabaseUrl || !anonKey) return jsonResponse({ ok: false, error: "Missing SUPABASE_URL or SUPABASE_ANON_KEY" }, 500);

    const body = (await req.json().catch(() => ({}))) as RequestBody;
    const limit = Math.max(1, Math.min(100, body.limit ?? 50));
    const offset = Math.max(0, body.offset ?? 0);

    const ageMin = body.ageMin == null ? null : Math.max(18, Math.min(99, body.ageMin));
    const ageMax = body.ageMax == null ? null : Math.max(18, Math.min(99, body.ageMax));

    const supabase = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false },
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userRes, error: userErr } = await supabase.auth.getUser();
    if (userErr) return jsonResponse({ ok: false, error: userErr.message }, 401);

    const myId = userRes.user?.id;
    if (!myId) return jsonResponse({ ok: false, error: "Unauthenticated" }, 401);

    let q = supabase
      .from("profiles")
      .select("id,name,age,bio,location,city,country,profession,tribe,phone,date_of_birth,photos,interests,gender,looking_for,created_at,updated_at", { count: "exact" })
      .eq("is_active", true)
      .eq("is_discoverable", true)
      .neq("id", myId);

    if (ageMin != null) q = q.gte("age", ageMin);
    if (ageMax != null) q = q.lte("age", ageMax);
    if ((body.country ?? "").trim().length > 0) q = q.eq("country", (body.country ?? "").trim());
    if ((body.city ?? "").trim().length > 0) q = q.eq("city", (body.city ?? "").trim());

    // Stable ordering for pagination.
    q = q.order("updated_at", { ascending: false, nullsFirst: false }).range(offset, offset + limit - 1);

    const { data, error, count } = await q;
    if (error) return jsonResponse({ ok: false, error: error.message }, 500);

    return jsonResponse({ ok: true, limit, offset, total: count ?? null, profiles: data ?? [] });
  } catch (e) {
    return jsonResponse({ ok: false, error: (e as Error).message ?? String(e) }, 500);
  }
});
