// supabase/functions/create_stripe_checkout_session/index.ts

import Stripe from "npm:stripe@14.25.0";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type PlanId = "monthly" | "3months" | "6months" | "year";

type RequestBody = {
  plan: PlanId;
  // Optional override: where Stripe should return the user after payment.
  // If absent, we fall back to Origin header.
  returnUrl?: string;
};

const PLAN_CONFIG: Record<PlanId, { amountUsd: number; interval: "month" | "year"; intervalCount: number; label: string }> = {
  monthly: { amountUsd: 12, interval: "month", intervalCount: 1, label: "Monthly" },
  "3months": { amountUsd: 27, interval: "month", intervalCount: 3, label: "3 Months" },
  "6months": { amountUsd: 43, interval: "month", intervalCount: 6, label: "6 Months" },
  year: { amountUsd: 75, interval: "year", intervalCount: 1, label: "1 Year" },
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
  if (!stripeSecretKey) return json({ error: "Missing STRIPE_SECRET_KEY" }, 500);

  const stripe = new Stripe(stripeSecretKey, { apiVersion: "2023-10-16" });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({ error: "Missing Authorization bearer token" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in function env" }, 500);
    }

    const body = (await req.json().catch(() => null)) as RequestBody | null;
    const plan = body?.plan;
    if (!plan || !(plan in PLAN_CONFIG)) return json({ error: "Invalid plan" }, 400);

    // Validate the user via Supabase Auth.
    const userRes = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: { Authorization: authHeader, apikey: serviceRoleKey },
    });
    if (!userRes.ok) return json({ error: "Unauthorized" }, 401);
    const user = await userRes.json();
    const userId = user?.id as string | undefined;
    const email = (user?.email as string | undefined) ?? undefined;
    if (!userId) return json({ error: "Unauthorized" }, 401);

    const origin = req.headers.get("Origin") ?? "";
    const returnUrl = (body?.returnUrl && body.returnUrl.trim().length > 0)
      ? body.returnUrl.trim()
      : (origin ? `${origin}/home` : "https://example.com");

    const cfg = PLAN_CONFIG[plan];
    const amountCents = Math.round(cfg.amountUsd * 100);

    // Create a metered-by-duration subscription price on the fly.
    // This keeps setup simple inside Dreamflow; for production you should pre-create Prices in Stripe.
    const product = await stripe.products.create({
      name: `Panda Premium — ${cfg.label}`,
      metadata: { app: "panda", plan, user_id: userId },
    });

    const price = await stripe.prices.create({
      currency: "usd",
      unit_amount: amountCents,
      recurring: { interval: cfg.interval, interval_count: cfg.intervalCount },
      product: product.id,
      metadata: { app: "panda", plan, user_id: userId },
    });

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer_email: email,
      line_items: [{ price: price.id, quantity: 1 }],
      allow_promotion_codes: true,
      subscription_data: {
        metadata: { app: "panda", plan, user_id: userId },
      },
      metadata: { app: "panda", plan, user_id: userId },
      // Stripe hosted Checkout URLs. Works well on web + mobile.
      success_url: `${returnUrl}?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${returnUrl}?checkout=cancel`,
    });

    return json({ url: session.url, sessionId: session.id });
  } catch (e) {
    return json({ error: (e as Error)?.message ?? String(e) }, 500);
  }
});
