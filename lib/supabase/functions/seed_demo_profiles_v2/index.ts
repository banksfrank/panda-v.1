// Supabase Edge Function: seed_demo_profiles_v2
// Deterministic identity + photos seeding using SEED + PERSON_ID.

const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Mode = "stats" | "seed" | "clear" | "seedAll";

type RequestBody = {
  mode?: Mode;
  perCity?: number;
  dryRun?: boolean;
  seed?: string;
  photosPerProfile?: number;
  overwritePhotos?: boolean;
};

function jsonResponse(body: unknown, init?: ResponseInit) {
  return new Response(JSON.stringify(body), {
    headers: { ...CORS_HEADERS, "content-type": "application/json; charset=utf-8" },
    ...init,
  });
}

function clampInt(v: unknown, def: number, min: number, max: number) {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isFinite(n)) return def;
  return Math.max(min, Math.min(max, Math.trunc(n)));
}

function fnv1a32(input: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

class XorShift32 {
  private x: number;
  constructor(seed: number) {
    this.x = (seed >>> 0) || 0x12345678;
  }
  nextU32(): number {
    let x = this.x;
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    this.x = x >>> 0;
    return this.x;
  }
  nextFloat(): number {
    return this.nextU32() / 0xffffffff;
  }
  pick<T>(arr: readonly T[]): T {
    return arr[Math.floor(this.nextFloat() * arr.length)];
  }
  int(min: number, maxInclusive: number): number {
    const span = maxInclusive - min + 1;
    return min + (this.nextU32() % span);
  }
}

const COUNTRIES: Array<{ country: string; cities: string[] }> = [
  { country: "Nigeria", cities: ["Lagos", "Abuja", "Ibadan", "Port Harcourt"] },
  { country: "Kenya", cities: ["Nairobi", "Mombasa", "Kisumu"] },
  { country: "Ghana", cities: ["Accra", "Kumasi"] },
  { country: "South Africa", cities: ["Cape Town", "Johannesburg", "Durban"] },
];

const FIRST_NAMES_W = ["Amina", "Zara", "Nia", "Tola", "Imani", "Sade", "Lerato", "Nandi", "Amara", "Chioma", "Asha", "Ayana"] as const;
const FIRST_NAMES_M = ["Noah", "Ethan", "Kofi", "Tunde", "Malik", "Kwame", "Ade", "Siyabonga", "Emeka", "Jabari", "Sefu", "Thabo"] as const;
const PROFESSIONS = ["Software Engineer", "Product Designer", "Nurse", "Teacher", "Analyst", "Entrepreneur", "Marketing", "Photographer", "Lawyer", "Chef"] as const;
const INTERESTS = ["Coffee", "Travel", "Afrobeats", "Movies", "Fitness", "Food", "Museums", "Hiking", "Books", "Gaming", "Photography", "Live music"] as const;
const LOOKING_FOR = ["Dating", "Relationship", "Friends"] as const;

function buildIdentity({ baseSeed, personId, country, city }: { baseSeed: string; personId: string; country: string; city: string }) {
  const seedMaterial = `${baseSeed}|${personId}`;
  const rng = new XorShift32(fnv1a32(seedMaterial));

  const gender = rng.nextFloat() < 0.52 ? "Woman" : "Man";
  const name = gender === "Woman" ? rng.pick(FIRST_NAMES_W) : rng.pick(FIRST_NAMES_M);
  const age = rng.int(19, 42);
  const profession = rng.pick(PROFESSIONS);
  const lookingFor = rng.pick(LOOKING_FOR);

  const interests = new Set<string>();
  while (interests.size < 4) interests.add(rng.pick(INTERESTS));

  const bioTemplates = [
    "Coffee dates, good playlists, and spontaneous weekend plans.",
    "Quiet confidence, big laughs. Ask me about my latest obsession.",
    "Gym sometimes, food always. Looking for someone kind and curious.",
    "Bookstore afternoons + live music nights. Let’s make it fun.",
  ] as const;

  const bio = `${rng.pick(bioTemplates)}\n\n${profession} • ${city}`;

  // Deterministic photo URLs. We derive per-photo keys from the same identity seed.
  // This keeps the identity locked while still producing multiple distinct images.
  const seedKeyBase = `panda-${fnv1a32(seedMaterial).toString(16)}`;
  const photos = [
    `https://picsum.photos/seed/${seedKeyBase}-a/900/1200`,
    `https://picsum.photos/seed/${seedKeyBase}-b/900/1200`,
    `https://picsum.photos/seed/${seedKeyBase}-c/900/1200`,
  ];

  return {
    seedKeyBase,
    gender,
    name,
    age,
    bio,
    profession,
    lookingFor,
    interests: Array.from(interests),
    location: `${city}, ${country}`,
    country,
    city,
    photos,
  };
}

async function maybeInsertPhotoMetadata({
  admin,
  profileId,
  seed,
  photos,
}: {
  // We intentionally use `any` here because this repo doesn't ship generated Database types.
  // Without them, supabase-js types infer table inserts as `never`.
  admin: any;
  profileId: string;
  seed: string;
  photos: string[];
}) {
  // Optional table: public.profile_photos
  // If it doesn't exist, we just skip without failing the whole run.
  try {
    const rows = photos.map((url, idx) => ({
      profile_id: profileId,
      idx,
      seed,
      url,
      source: "picsum",
      created_at: new Date().toISOString(),
    }));

    const { error } = await (admin as any).from("profile_photos").upsert(rows as any, { onConflict: "profile_id,idx" });
    if (error) throw error;
  } catch (_) {
    // ignore
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse({ ok: false, error: "POST only" }, { status: 405 });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey) return jsonResponse({ ok: false, error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }, { status: 500 });

  const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });

  let body: RequestBody = {};
  try {
    body = (await req.json()) as RequestBody;
  } catch (_) {
    body = {};
  }

  const mode: Mode = body.mode ?? "seed";
  const perCity = clampInt(body.perCity, 16, 1, 50);
  const dryRun = body.dryRun === true;
  const baseSeed = (body.seed ?? "847392").trim() || "847392";
  const photosPerProfile = clampInt(body.photosPerProfile, 3, 1, 6);
  const overwritePhotos = body.overwritePhotos === true;

  // Stats: count discoverable and seeded profiles.
  if (mode === "stats") {
    const { count: discoverableProfiles, error: e1 } = await admin
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("is_active", true)
      .eq("is_discoverable", true);

    if (e1) return jsonResponse({ ok: false, error: e1.message }, { status: 500 });

    const { count: seededProfiles, error: e2 } = await admin
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("seed_source", "seed_demo_profiles_v2");

    // seededProfiles count is optional (if column doesn't exist)
    const seeded = e2 ? null : seededProfiles;

    return jsonResponse({ ok: true, mode, perCity, discoverableProfiles, seededProfiles: seeded, countries: COUNTRIES.length });
  }

  // Clear: remove seeded demo profiles.
  if (mode === "clear" || mode === "seedAll") {
    if (dryRun) {
      return jsonResponse({ ok: true, mode, dryRun, plannedDelete: "profiles where seed_source = seed_demo_profiles_v2" });
    }

    // If seed_source column doesn't exist, we can't safely delete.
    const del = await admin.from("profiles").delete().eq("seed_source", "seed_demo_profiles_v2");
    if (del.error) {
      return jsonResponse({ ok: false, mode, error: del.error.message }, { status: 500 });
    }

    if (mode === "clear") return jsonResponse({ ok: true, mode, deleted: (del.data as unknown[] | null)?.length ?? null });
  }

  // Seed: insert deterministic profiles. We mark them with seed_source for repeatable runs.
  const plan: Array<{ country: string; target: number; existing: number; toInsert: number }> = [];
  const profilesToInsert: Array<Record<string, unknown>> = [];

  for (const entry of COUNTRIES) {
    const target = entry.cities.length * perCity;

    const { data: existingRows, error: existingErr } = await admin
      .from("profiles")
      .select("id")
      .eq("seed_source", "seed_demo_profiles_v2")
      .eq("country", entry.country);

    // If seed_source doesn't exist, we still can seed, but we can't count existing reliably.
    const existing = existingErr ? 0 : (existingRows?.length ?? 0);
    const toInsert = Math.max(0, target - existing);

    plan.push({ country: entry.country, target, existing, toInsert });

    if (toInsert <= 0) continue;

    // Deterministic person_id generation: country/city + index.
    let produced = 0;
    for (const city of entry.cities) {
      for (let i = 0; i < perCity; i++) {
        if (produced >= toInsert) break;
        const personId = `${entry.country}:${city}:${i}`;
        const identity = buildIdentity({ baseSeed, personId, country: entry.country, city });

        const photos = identity.photos.slice(0, photosPerProfile);

        // Use a deterministic but unique-ish profile id for demo seed.
        const profileId = `seedv2_${fnv1a32(`${baseSeed}|${personId}`).toString(16)}`;
        const nowIso = new Date().toISOString();

        profilesToInsert.push({
          id: profileId,
          name: identity.name,
          age: identity.age,
          bio: identity.bio,
          location: identity.location,
          city: identity.city,
          country: identity.country,
          profession: identity.profession,
          tribe: null,
          phone: null,
          date_of_birth: null,
          photos,
          interests: identity.interests,
          gender: identity.gender,
          looking_for: identity.lookingFor,
          is_active: true,
          is_discoverable: true,
          seed_source: "seed_demo_profiles_v2",
          seed: baseSeed,
          person_id: personId,
          created_at: nowIso,
          updated_at: nowIso,
        });

        produced++;
      }
      if (produced >= toInsert) break;
    }
  }

  if (dryRun) {
    return jsonResponse({ ok: true, mode: mode === "seedAll" ? "seedAll" : "seed", dryRun, plannedInsert: profilesToInsert.length, plan });
  }

  let inserted = 0;
  try {
    // Upsert so it is idempotent.
    // If overwritePhotos=false we try to avoid overwriting existing photos.
    if (!overwritePhotos) {
      for (const p of profilesToInsert) {
        const id = String(p.id);
        const { data: existing, error: exErr } = await admin.from("profiles").select("id,photos").eq("id", id).maybeSingle();
        if (!exErr && existing?.photos && Array.isArray(existing.photos) && existing.photos.length > 0) {
          // Keep existing photos.
          delete (p as Record<string, unknown>).photos;
        }
      }
    }

    const { data, error } = await admin.from("profiles").upsert(profilesToInsert, { onConflict: "id" }).select("id,seed,person_id,photos");
    if (error) throw error;

    inserted = data?.length ?? 0;

    // Best-effort metadata upsert.
    if (Array.isArray(data)) {
      for (const row of data) {
        const id = String((row as any).id);
        const seed = String((row as any).seed ?? baseSeed);
        const photos = Array.isArray((row as any).photos) ? (row as any).photos.map(String) : [];
        await maybeInsertPhotoMetadata({ admin, profileId: id, seed, photos });
      }
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonResponse({ ok: false, mode, error: msg, hint: "Ensure profiles has columns: seed_source, seed, person_id (or remove them), and that RLS allows service-role writes." }, { status: 500 });
  }

  return jsonResponse({ ok: true, mode, inserted, plan, seed: baseSeed, photosPerProfile, overwritePhotos });
});
