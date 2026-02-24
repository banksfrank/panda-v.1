// Supabase Edge Function: seed_demo_profiles
//
// Matches the requested pseudocode behavior:
// - For each country, decide how many profiles to seed based on country.size
// - For each profile: generate UUIDs for person_id and profile_id
// - Use LOCAL_DATA for local names/cities/tribes (fallbacks provided)
// - Generate interests + bio
// - Idempotent inserts: re-running seeds only the missing count per country
// - Clear mode deletes only the previously-seeded rows

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type Mode = "seed" | "clear" | "stats" | "seedAll";

type CountrySize = "large" | "medium" | "small";

type RequestBody = {
  mode?: Mode;
  dryRun?: boolean;

  // Back-compat (Admin screen uses this). If provided, this overrides size-based counts.
  // Total per country = perCity * cityPool.length
  perCity?: number;
};

type CountryDef = { name: string; size: CountrySize };

type LocalCountryData = { cities: readonly string[]; tribes: readonly string[]; names: readonly string[] };

const SEED_LABEL = "DEMO_SEED";

// User-facing mini-tagline. We keep `label` reserved for the seed marker so that:
// - clear() can delete seeded rows only
// - seed() can stay idempotent per country
const PROFILE_TAGLINES = ["Starter community profile", "New here"] as const;


function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS_HEADERS, "content-type": "application/json; charset=utf-8" } });
}

function ensureAdminOrServiceOnly(req: Request) {
  const auth = req.headers.get("authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) throw new Error("Missing Authorization header");
}

function randomBetween(min: number, max: number) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomOne<T>(arr: readonly T[]) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function randomOneOrNull<T>(arr?: readonly T[]) {
  if (!arr || arr.length === 0) return null;
  return randomOne(arr);
}

function randomUnique(arr: readonly string[], count: number) {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy.slice(0, Math.min(count, copy.length));
}

function getProfileCount(size: CountrySize) {
  if (size === "large") return randomBetween(50, 60);
  if (size === "medium") return randomBetween(45, 50);
  return randomBetween(40, 45);
}

function generateInterests() {
  return randomUnique(INTERESTS, randomBetween(3, 6));
}

function generateBio(params: { name: string; city: string; country: string; interests: readonly string[]; profession: string }) {
  const { name, city, country, interests, profession } = params;
  const vibe = randomOne(["curious", "warm", "adventurous", "low-key", "ambitious", "playful"]);
  const i1 = interests[0] ?? "good conversations";
  const i2 = interests[1] ?? "coffee";

  const templates = [
    `${name} here — ${profession} in ${city}. I’m feeling ${vibe} lately. Let’s swap ${i1} spots and try ${i2} together.`,
    `New connections in ${city}, ${country}. Into ${interests.slice(0, 3).join(", ")}. Bonus points if you can recommend a hidden gem.`,
    `If you’re down for ${i1} and a great playlist, we’ll get along. ${city} is better with good company.`,
    `I’m a ${profession} who loves ${i2} and spontaneous plans. Say hi if you’re in ${city}!`,
  ];

  return randomOne(templates);
}

function generateConsistentFace(personId: string, sceneType: string) {
  // Deterministic image per (personId, sceneType). This gives a "consistent face" across runs.
  const seed = encodeURIComponent(`${personId}-${sceneType}`);
  return `https://picsum.photos/seed/${seed}/600/800`;
}

type PhotoSeedRow = {
  photo_id: string;
  profile_id: string;
  person_id: string;
  image_url: string;
  scene_type: string;
  created_at: string;
  updated_at: string;
  // Optional: if your `photos` table includes a `label` column like `profiles` does.
  label?: string;
};

function generatePhotoRows(profileId: string, personId: string, nowIso: string): PhotoSeedRow[] {
  const photoCount = randomBetween(3, 5);
  const scenes = ["portrait", "outdoor", "lifestyle", "activity", "social"] as const;

  const rows: PhotoSeedRow[] = [];
  for (let i = 0; i < photoCount; i++) {
    const sceneType = scenes[i] ?? "portrait";
    rows.push({
      photo_id: crypto.randomUUID(),
      profile_id: profileId,
      person_id: personId,
      image_url: generateConsistentFace(personId, sceneType),
      scene_type: sceneType,
      created_at: nowIso,
      updated_at: nowIso,
      label: SEED_LABEL,
    });
  }

  return rows;
}

function generatePhotos(profileId: string, personId: string, nowIso: string) {
  // For Flutter compatibility we keep `profiles.photos` as a list of URLs.
  const photoRows = generatePhotoRows(profileId, personId, nowIso);
  return {
    urls: photoRows.map((p) => p.image_url),
    photoRows,
  };
}

const COUNTRIES: ReadonlyArray<CountryDef> = [
  { name: "United States", size: "large" },
  { name: "India", size: "large" },
  { name: "Brazil", size: "large" },
  { name: "Nigeria", size: "large" },

  { name: "United Kingdom", size: "medium" },
  { name: "France", size: "medium" },
  { name: "Germany", size: "medium" },
  { name: "Spain", size: "medium" },
  { name: "Italy", size: "medium" },
  { name: "Canada", size: "medium" },
  { name: "Mexico", size: "medium" },
  { name: "Argentina", size: "medium" },
  { name: "South Africa", size: "medium" },
  { name: "Kenya", size: "medium" },
  { name: "Tanzania", size: "medium" },
  { name: "Uganda", size: "medium" },
  { name: "Egypt", size: "medium" },

  { name: "Norway", size: "small" },
  { name: "Netherlands", size: "small" },
  { name: "Sweden", size: "small" },
  { name: "United Arab Emirates", size: "small" },
  { name: "Qatar", size: "small" },
  { name: "Singapore", size: "small" },
  { name: "Philippines", size: "small" },
  { name: "Indonesia", size: "small" },
  { name: "Ghana", size: "small" },
  { name: "Senegal", size: "small" },
  { name: "Morocco", size: "small" },
  { name: "Tunisia", size: "small" },
  { name: "Rwanda", size: "small" },
  { name: "Zimbabwe", size: "small" },
  { name: "Zambia", size: "small" },
  { name: "Botswana", size: "small" },
  { name: "Namibia", size: "small" },
  { name: "Cameroon", size: "small" },
];

// Localized pools; expand as needed. Cities are used for random selection.
const LOCAL_DATA: Record<string, LocalCountryData> = {
  Uganda: {
    cities: ["Kampala", "Gulu", "Mbarara", "Jinja"],
    tribes: ["Baganda", "Banyankole", "Acholi", "Basoga"],
    names: ["Moses", "Aisha", "Brian", "Grace"],
  },
  Nigeria: {
    cities: ["Lagos", "Abuja", "Kano"],
    tribes: ["Yoruba", "Igbo", "Hausa"],
    names: ["Chinedu", "Amina", "Tunde", "Ngozi"],
  },

  "United States": {
    cities: ["New York", "Los Angeles", "Chicago", "Austin"],
    tribes: ["Black American", "Latino", "Irish-American", "Cherokee", "Navajo"],
    names: ["Ava", "Noah", "Mia", "Liam", "Sophia", "Ethan"],
  },
  India: {
    cities: ["Mumbai", "Delhi", "Bengaluru", "Hyderabad"],
    tribes: ["Punjabi", "Tamil", "Bengali", "Marathi", "Gujarati"],
    names: ["Riya", "Arjun", "Aanya", "Ishaan", "Priya", "Rahul"],
  },
  Brazil: {
    cities: ["São Paulo", "Rio de Janeiro", "Brasília"],
    tribes: ["Paulista", "Carioca", "Mineiro", "Baiano"],
    names: ["Diego", "Camila", "Lucas", "Mariana", "Rafael", "Ana"],
  },
  "United Kingdom": {
    cities: ["London", "Manchester", "Birmingham"],
    tribes: ["English", "Scottish", "Welsh", "Irish"],
    names: ["Oliver", "Amelia", "Harry", "Isla", "Theo", "Freya"],
  },
  France: {
    cities: ["Paris", "Lyon", "Marseille"],
    tribes: ["Breton", "Provençal", "Alsatian", "Corsican"],
    names: ["Chloé", "Hugo", "Léa", "Lucas", "Camille", "Thomas"],
  },
  Germany: {
    cities: ["Berlin", "Munich", "Hamburg"],
    tribes: ["Bavarian", "Saxon", "Swabian", "Rhinelander"],
    names: ["Lina", "Leon", "Mia", "Ben", "Anna", "Felix"],
  },
  Spain: {
    cities: ["Madrid", "Barcelona", "Valencia"],
    tribes: ["Catalan", "Andalusian", "Basque", "Galician"],
    names: ["Mateo", "Lucía", "Sofía", "Daniel", "Martín", "Elena"],
  },
  Italy: {
    cities: ["Rome", "Milan", "Naples"],
    tribes: ["Sicilian", "Roman", "Neapolitan", "Tuscan"],
    names: ["Giulia", "Lorenzo", "Sofia", "Marco", "Chiara", "Matteo"],
  },
  Canada: {
    cities: ["Toronto", "Vancouver", "Montreal"],
    tribes: ["French Canadian", "English Canadian", "First Nations", "Métis"],
    names: ["Emma", "Noah", "Olivia", "Liam", "Sophie", "Ethan"],
  },
  Mexico: {
    cities: ["Mexico City", "Guadalajara", "Monterrey"],
    tribes: ["Mestizo", "Maya", "Nahua", "Zapotec"],
    names: ["Sofía", "Diego", "Valeria", "Mateo", "Camila", "Luis"],
  },
  Argentina: {
    cities: ["Buenos Aires", "Córdoba", "Rosario"],
    tribes: ["Porteño", "Gaucho", "Mestizo"],
    names: ["Sofía", "Mateo", "Valentina", "Thiago", "Martina", "Nicolás"],
  },
  "South Africa": {
    cities: ["Cape Town", "Johannesburg", "Durban"],
    tribes: ["Zulu", "Xhosa", "Sotho", "Afrikaner"],
    names: ["Thandi", "Sipho", "Amahle", "Lebo", "Naledi", "Siyabonga"],
  },
  Kenya: {
    cities: ["Nairobi", "Mombasa", "Kisumu"],
    tribes: ["Kikuyu", "Luo", "Kalenjin", "Luhya"],
    names: ["Wanjiku", "Akinyi", "Kamau", "Otieno", "Njeri", "Mwangi"],
  },
  Tanzania: {
    cities: ["Dar es Salaam", "Arusha", "Mwanza"],
    tribes: ["Sukuma", "Chagga", "Haya", "Hehe"],
    names: ["Asha", "Neema", "Baraka", "Juma", "Zawadi", "Hassan"],
  },
  Egypt: {
    cities: ["Cairo", "Alexandria", "Giza"],
    tribes: ["Egyptian Arab", "Nubian", "Bedouin"],
    names: ["Omar", "Mariam", "Youssef", "Nour", "Ahmed", "Salma"],
  },
  Norway: {
    cities: ["Oslo", "Bergen", "Trondheim"],
    tribes: ["Norwegian", "Sámi"],
    names: ["Nora", "Lars", "Ingrid", "Sofia", "Ola", "Emil"],
  },
  Netherlands: {
    cities: ["Amsterdam", "Rotterdam", "Utrecht"],
    tribes: ["Dutch", "Frisian"],
    names: ["Sanne", "Daan", "Noa", "Sem", "Lotte", "Milan"],
  },
  Sweden: {
    cities: ["Stockholm", "Gothenburg", "Malmö"],
    tribes: ["Swedish", "Sámi"],
    names: ["Freja", "Oscar", "Elsa", "Noah", "Maja", "Elias"],
  },
  "United Arab Emirates": {
    cities: ["Dubai", "Abu Dhabi", "Sharjah"],
    tribes: ["Emirati", "Arab"],
    names: ["Alya", "Saeed", "Noor", "Omar", "Mariam", "Khalid"],
  },
  Qatar: {
    cities: ["Doha", "Al Rayyan", "Al Wakrah"],
    tribes: ["Qatari", "Arab"],
    names: ["Hamad", "Noor", "Mariam", "Fahad", "Aisha", "Khalifa"],
  },
  Singapore: {
    cities: ["Central", "Queenstown", "Tampines"],
    tribes: ["Chinese", "Malay", "Indian"],
    names: ["Wei", "Jun", "Aisyah", "Nur", "Arjun", "Ananya"],
  },
  Philippines: {
    cities: ["Manila", "Cebu City", "Davao City"],
    tribes: ["Tagalog", "Cebuano", "Ilocano"],
    names: ["Maria", "Jose", "Juan", "Angel", "Kathryn", "Paolo"],
  },
  Indonesia: {
    cities: ["Jakarta", "Surabaya", "Bandung"],
    tribes: ["Javanese", "Sundanese", "Balinese"],
    names: ["Putri", "Budi", "Ayu", "Rizki", "Dewi", "Andi"],
  },
  Ghana: {
    cities: ["Accra", "Kumasi", "Takoradi"],
    tribes: ["Akan", "Ewe", "Ga"],
    names: ["Ama", "Kofi", "Abena", "Kwame", "Akosua", "Yaw"],
  },
  Senegal: {
    cities: ["Dakar", "Thiès", "Saint-Louis"],
    tribes: ["Wolof", "Serer", "Pulaar"],
    names: ["Awa", "Mamadou", "Fatou", "Cheikh", "Mariama", "Ibrahima"],
  },
  Morocco: {
    cities: ["Casablanca", "Rabat", "Marrakesh"],
    tribes: ["Arab", "Amazigh"],
    names: ["Youssef", "Khadija", "Omar", "Salma", "Amine", "Nadia"],
  },
  Tunisia: {
    cities: ["Tunis", "Sfax", "Sousse"],
    tribes: ["Tunisian Arab", "Amazigh"],
    names: ["Sami", "Amina", "Yassine", "Ines", "Ahmed", "Sarra"],
  },
  Rwanda: {
    cities: ["Kigali", "Huye", "Rubavu"],
    tribes: ["Hutu", "Tutsi", "Twa"],
    names: ["Aline", "Eric", "Clarisse", "Patrick", "Diane", "Claude"],
  },
  Zimbabwe: {
    cities: ["Harare", "Bulawayo", "Mutare"],
    tribes: ["Shona", "Ndebele"],
    names: ["Tariro", "Tawanda", "Rudo", "Farai", "Nyasha", "Simba"],
  },
  Zambia: {
    cities: ["Lusaka", "Ndola", "Livingstone"],
    tribes: ["Bemba", "Tonga", "Lozi"],
    names: ["Chanda", "Mwila", "Natasha", "Kelvin", "Thandiwe", "Brian"],
  },
  Botswana: {
    cities: ["Gaborone", "Francistown", "Maun"],
    tribes: ["Tswana", "Kalanga"],
    names: ["Kago", "Amantle", "Neo", "Thabo", "Onalenna", "Kelebogile"],
  },
  Namibia: {
    cities: ["Windhoek", "Swakopmund", "Walvis Bay"],
    tribes: ["Ovambo", "Herero", "Nama"],
    names: ["Tate", "Nandi", "Amutenya", "Elago", "Nangula", "Petrus"],
  },
  Cameroon: {
    cities: ["Douala", "Yaoundé", "Bamenda"],
    tribes: ["Bamileke", "Fang", "Fulani"],
    names: ["Nadia", "Junior", "Amina", "Blaise", "Chantal", "Brice"],
  },
};

const PROFESSIONS = [
  "Product Designer",
  "Software Engineer",
  "Nurse",
  "Teacher",
  "Entrepreneur",
  "Photographer",
  "Chef",
  "Marketing Manager",
  "Data Analyst",
  "Fitness Coach",
  "Architect",
  "Doctor",
  "Musician",
  "Researcher",
  "Travel Writer",
  "UX Writer",
  "Barista",
  "Event Planner",
];

const INTERESTS = [
  "Hiking",
  "Coffee",
  "Cooking",
  "Yoga",
  "Travel",
  "Photography",
  "Reading",
  "Music",
  "Art",
  "Gaming",
  "Fitness",
  "Tech",
  "Pets",
  "Outdoors",
  "Foodie",
  "Dancing",
  "Museums",
  "Beach days",
  "Cinema",
  "Running",
  "Cycling",
  "Journaling",
  "Volunteering",
  "Language exchange",
];

const GENDERS = ["Woman", "Man", "Non-binary"] as const;
const LOOKING_FOR = ["Women", "Men", "Everyone"] as const;

function countryFallbackCities(country: string) {
  // Minimal fallback to keep seeding working if LOCAL_DATA is missing.
  // (Prefer adding the country to LOCAL_DATA.)
  const map: Record<string, readonly string[]> = {
    Uganda: ["Kampala", "Entebbe", "Gulu"],
    Nigeria: ["Lagos", "Abuja", "Port Harcourt"],
  };
  return map[country] ?? ["Capital", "Downtown", "Uptown"];
}

function countryFallbackNames(country: string) {
  const map: Record<string, readonly string[]> = {
    Uganda: ["Moses", "Aisha", "Brian", "Grace"],
    Nigeria: ["Chinedu", "Amina", "Tunde", "Ngozi"],
  };
  return map[country] ?? ["Alex", "Jordan", "Sam", "Taylor", "Casey", "Riley"];
}

function countryFallbackTribes(country: string) {
  const map: Record<string, readonly string[]> = {
    Uganda: ["Baganda", "Banyankole", "Acholi", "Basoga"],
    Nigeria: ["Yoruba", "Igbo", "Hausa"],
  };
  return map[country] ?? [];
}

function getLocal(countryName: string): LocalCountryData {
  return (
    LOCAL_DATA[countryName] ?? {
      cities: countryFallbackCities(countryName),
      tribes: countryFallbackTribes(countryName),
      names: countryFallbackNames(countryName),
    }
  );
}

type ClearResult = { deleted: number; deletedPhotos: number | null };

async function clearSeeded(admin: any, dryRun: boolean): Promise<ClearResult> {
  if (dryRun) return { deleted: 0, deletedPhotos: 0 };

  const { error, count } = await admin.from("profiles").delete({ count: "exact" }).eq("label", SEED_LABEL);
  if (error) throw new Error(error.message);

  let deletedPhotos: number | null = null;
  try {
    const { error: photoErr, count: photoCount } = await admin.from("photos").delete({ count: "exact" }).eq("label", SEED_LABEL);
    if (photoErr) {
      const msg = (photoErr.message ?? "").toLowerCase();
      if (msg.includes("relation") && msg.includes("photos") && msg.includes("does not exist")) deletedPhotos = null;
      else if (msg.includes("column") && msg.includes("label") && msg.includes("does not exist")) deletedPhotos = null;
      else deletedPhotos = null;
    } else {
      deletedPhotos = photoCount ?? 0;
    }
  } catch (_) {
    deletedPhotos = null;
  }

  return { deleted: count ?? 0, deletedPhotos };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });

  try {
    ensureAdminOrServiceOnly(req);

    const body = (await req.json().catch(() => ({}))) as RequestBody;
    const mode: Mode = body.mode ?? "seed";
    const dryRun = body.dryRun === true;
    const perCity = body.perCity == null ? null : Math.max(1, Math.min(200, body.perCity));

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) return jsonResponse({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }, 500);

    const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });

    let seedAllPlannedDelete: number | null = null;
    let seedAllDeleted = 0;
    let seedAllDeletedPhotos: number | null = null;

    if (mode === "seedAll") {
      // Equivalent to:
      //   await clearDemoProfiles();
      //   await generateAllProfiles();
      // but done server-side in a single request.
      if (dryRun) {
        const { count: seededCount, error: seededErr } = await admin.from("profiles").select("id", { count: "exact", head: true }).eq("label", SEED_LABEL);
        if (seededErr) return jsonResponse({ error: seededErr.message }, 500);
        seedAllPlannedDelete = seededCount ?? 0;
      } else {
        const cleared = await clearSeeded(admin, false);
        seedAllDeleted = cleared.deleted;
        seedAllDeletedPhotos = cleared.deletedPhotos;
      }

      // Then we fall through into the normal seeding logic below.
    }

    if (mode === "clear") {
      if (dryRun) return jsonResponse({ ok: true, mode, dryRun: true });

      try {
        const cleared = await clearSeeded(admin, false);
        return jsonResponse({ ok: true, mode, deleted: cleared.deleted, deletedPhotos: cleared.deletedPhotos });
      } catch (e) {
        return jsonResponse({ error: (e as Error).message ?? String(e) }, 500);
      }
    }

    if (mode === "stats") {
      const { count, error } = await admin.from("profiles").select("id", { count: "exact", head: true }).eq("is_discoverable", true);
      if (error) return jsonResponse({ error: error.message }, 500);

      const { count: seededCount, error: seededErr } = await admin.from("profiles").select("id", { count: "exact", head: true }).eq("label", SEED_LABEL);
      if (seededErr) return jsonResponse({ error: seededErr.message }, 500);

      return jsonResponse({ ok: true, mode, discoverableProfiles: count ?? null, seededProfiles: seededCount ?? null, countries: COUNTRIES.length, perCity });
    }

    // mode === 'seed'
    const plan: Array<{ country: string; target: number; existing: number; toInsert: number }> = [];
    const rows: Record<string, unknown>[] = [];
    const photoRows: PhotoSeedRow[] = [];

    for (const country of COUNTRIES) {
      const local = getLocal(country.name);

      const target = perCity != null ? perCity * local.cities.length : getProfileCount(country.size);

      // Idempotency: only insert the missing profiles for this country.
      const { count: existingCount, error: existingErr } = await admin
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("label", SEED_LABEL)
        .eq("country", country.name);

      if (existingErr) return jsonResponse({ error: existingErr.message, country: country.name }, 500);

      const existing = existingCount ?? 0;
      const toInsert = Math.max(0, target - existing);
      plan.push({ country: country.name, target, existing, toInsert });

      for (let i = 0; i < toInsert; i++) {
        const person_id = crypto.randomUUID();
        const profile_id = crypto.randomUUID();

        const name = randomOne(local.names);
        const age = randomBetween(18, 90);
        const city = randomOne(local.cities);
        const tribe = randomOneOrNull(local.tribes);
        const interests = generateInterests();
        const profession = randomOne(PROFESSIONS);
        const gender = randomOne(GENDERS);
        const looking_for = randomOne(LOOKING_FOR);
        const tagline = randomOne(PROFILE_TAGLINES);
        const now = new Date().toISOString();

        const bio = generateBio({ name, city, country: country.name, interests, profession });

        const generatedPhotos = generatePhotos(profile_id, person_id, now);
        photoRows.push(...generatedPhotos.photoRows);

        rows.push({
          // Common schemas: either `id` is the PK, or `profile_id` exists.
          // We set BOTH (same UUID) to match the requested pseudocode while keeping compatibility.
          id: profile_id,
          profile_id,
          person_id,
          name,
          age,
          country: country.name,
          city,
          tribe,
          interests,
          bio,
          location: `${city}, ${country.name}`,
          profession,
          gender,
          looking_for,
          photos: generatedPhotos.urls,
          phone: null,
          date_of_birth: null,
          label: SEED_LABEL,
          tagline,
          is_active: true,
          is_discoverable: true,
          created_at: now,
          updated_at: now,
        });
      }
    }

    const planned = plan.reduce((acc, p) => acc + p.toInsert, 0);

    if (dryRun) {
      if (mode === "seedAll") {
        return jsonResponse({ ok: true, mode, dryRun: true, plannedDelete: seedAllPlannedDelete, plannedInsert: planned, plan });
      }
      return jsonResponse({ ok: true, mode, dryRun: true, plannedInsert: planned, plan });
    }

    if (!rows.length) {
      if (mode === "seedAll") {
        return jsonResponse({ ok: true, mode, deleted: seedAllDeleted, deletedPhotos: seedAllDeletedPhotos, inserted: 0, plan });
      }
      return jsonResponse({ ok: true, mode, inserted: 0, plan });
    }

    // Insert in chunks to keep payloads reasonable.
    const chunkSize = 250;
    let inserted = 0;

    for (let i = 0; i < rows.length; i += chunkSize) {
      const chunk = rows.slice(i, i + chunkSize);
      const { error } = await admin.from("profiles").insert(chunk);
      if (error) {
        const msg = (error.message ?? "").toLowerCase();
        if (msg.includes("column") && msg.includes("tagline") && msg.includes("does not exist")) {
          // If your `profiles` table doesn't have `tagline` yet, retry without it.
          const retryChunk = chunk.map(({ tagline: _tagline, ...rest }) => rest);
          const { error: retryErr } = await admin.from("profiles").insert(retryChunk);
          if (retryErr) return jsonResponse({ error: retryErr.message, at: { i, chunkSize }, retry: "without_tagline" }, 500);
          inserted += retryChunk.length;
          continue;
        }
        return jsonResponse({ error: error.message, at: { i, chunkSize } }, 500);
      }
      inserted += chunk.length;
    }

    // Optional: also insert photo rows if you have a `photos` table.
    // This matches the pseudocode's `insertPhoto({ photo_id, profile_id, person_id, image_url, scene_type })`.
    // If the table doesn’t exist (or schema differs), we keep the seed successful because Flutter uses `profiles.photos`.
    let insertedPhotos: number | null = null;
    if (photoRows.length) {
      try {
        const photoChunkSize = 500;
        let photoInserted = 0;

        for (let i = 0; i < photoRows.length; i += photoChunkSize) {
          const chunk = photoRows.slice(i, i + photoChunkSize);
          const { error } = await admin.from("photos").insert(chunk);
          if (error) {
            const msg = (error.message ?? "").toLowerCase();
            if (msg.includes("relation") && msg.includes("photos") && msg.includes("does not exist")) {
              insertedPhotos = null;
              break;
            }
            if (msg.includes("column") && msg.includes("label") && msg.includes("does not exist")) {
              // Retry without `label` if your `photos` table doesn't have it.
              const retryChunk = chunk.map(({ label: _label, ...rest }) => rest);
              const { error: retryErr } = await admin.from("photos").insert(retryChunk);
              if (retryErr) throw retryErr;
              photoInserted += retryChunk.length;
              continue;
            }
            throw error;
          }
          photoInserted += chunk.length;
        }

        if (insertedPhotos == null) {
          // no-op: photos table missing
        } else {
          insertedPhotos = photoInserted;
        }
      } catch (e) {
        // Don’t fail the entire seed if photos insertion fails, because profiles are the source of truth for the app.
        insertedPhotos = null;
      }
    }

    if (mode === "seedAll") {
      return jsonResponse({ ok: true, mode, deleted: seedAllDeleted, deletedPhotos: seedAllDeletedPhotos, inserted, insertedPhotos, plan });
    }
    return jsonResponse({ ok: true, mode, inserted, insertedPhotos, plan });
  } catch (e) {
    return jsonResponse({ error: (e as Error).message ?? String(e) }, 500);
  }
});
