// supabase/functions/stripe_webhook/index.ts

import Stripe from "npm:stripe@14.25.0";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type, stripe-signature",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

async function updateProfilePremium(args: { userId: string; premiumUntil: Date | null; stripeCustomerId?: string; stripeSubscriptionId?: string; plan?: string }) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey) throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");

  const patch: Record<string, unknown> = {
    premium_until: args.premiumUntil ? args.premiumUntil.toISOString() : null,
    updated_at: new Date().toISOString(),
  };
  if (args.stripeCustomerId) patch.stripe_customer_id = args.stripeCustomerId;
  if (args.stripeSubscriptionId) patch.stripe_subscription_id = args.stripeSubscriptionId;
  if (args.plan) patch.premium_plan = args.plan;

  const res = await fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${encodeURIComponent(args.userId)}`, {
    method: "PATCH",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify(patch),
  });

  if (!res.ok) {
    const t = await res.text().catch(() => "");
    throw new Error(`Failed to update profile premium: ${res.status} ${t}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!stripeSecretKey) return json({ error: "Missing STRIPE_SECRET_KEY" }, 500);
  if (!webhookSecret) return json({ error: "Missing STRIPE_WEBHOOK_SECRET" }, 500);

  const stripe = new Stripe(stripeSecretKey, { apiVersion: "2023-10-16" });

  try {
    const sig = req.headers.get("stripe-signature");
    if (!sig) return json({ error: "Missing stripe-signature" }, 400);

    const raw = await req.text();
    const event = stripe.webhooks.constructEvent(raw, sig, webhookSecret);

    // We primarily care about:
    // - checkout.session.completed (get subscription id)
    // - customer.subscription.updated (period_end)
    // - customer.subscription.deleted

    if (event.type === "checkout.session.completed") {
      const session = event.data.object as Stripe.Checkout.Session;
      const userId = session.metadata?.user_id as string | undefined;
      const plan = session.metadata?.plan as string | undefined;
      const subscriptionId = (session.subscription as string | null) ?? undefined;
      const customerId = (session.customer as string | null) ?? undefined;

      if (userId && subscriptionId) {
        // We don't yet know the current period end here reliably in all cases.
        // We'll set a temporary premium_until of now + 1 day and let subscription.updated correct it.
        await updateProfilePremium({
          userId,
          premiumUntil: new Date(Date.now() + 24 * 60 * 60 * 1000),
          stripeCustomerId: customerId,
          stripeSubscriptionId: subscriptionId,
          plan,
        });
      }

      return json({ received: true });
    }

    if (event.type === "customer.subscription.updated" || event.type === "customer.subscription.created") {
      const sub = event.data.object as Stripe.Subscription;
      const userId = sub.metadata?.user_id as string | undefined;
      const plan = sub.metadata?.plan as string | undefined;
      if (userId) {
        const premiumUntil = new Date(sub.current_period_end * 1000);
        await updateProfilePremium({
          userId,
          premiumUntil,
          stripeCustomerId: (sub.customer as string | undefined) ?? undefined,
          stripeSubscriptionId: sub.id,
          plan,
        });
      }
      return json({ received: true });
    }

    if (event.type === "customer.subscription.deleted") {
      const sub = event.data.object as Stripe.Subscription;
      const userId = sub.metadata?.user_id as string | undefined;
      const plan = sub.metadata?.plan as string | undefined;
      if (userId) await updateProfilePremium({ userId, premiumUntil: null, stripeSubscriptionId: sub.id, plan });
      return json({ received: true });
    }

    return json({ received: true, ignored: true });
  } catch (e) {
    return json({ error: (e as Error)?.message ?? String(e) }, 400);
  }
});
