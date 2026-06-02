// BengkelIn — bidding edge function (Marketplace tier).
// Actions: ordersForMechanic (nearby open orders), mechanicsForCustomer
// (nearby verified bengkels), placeBid (upsert a revisable offer).
//
// Adapted from MbengkelIn's `bidding` function to BengkelIn conventions:
// open-order status is the lowercase 'pending' and the customer's offered price
// is read from service_requests.estimated_price. All DB authority stays in the
// SECURITY DEFINER RPCs (accept_bid lives in SQL, not here).
//
// DRAFT — deploy via the Supabase MCP / `supabase functions deploy bidding`
// only after the companion migration is applied and verified.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user) return json({ error: "Unauthorized" }, 401);
  const userId = userData.user.id;

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const action = payload.action as string;
  const radiusMeters = (payload.radiusMeters as number) ?? 5000;

  switch (action) {
    case "ordersForMechanic": {
      const { data, error } = await supabase.rpc("nearby_service_requests", {
        p_lat: payload.latitude,
        p_lon: payload.longitude,
        p_radius_m: radiusMeters,
      });
      if (error) return json({ error: error.message }, 400);
      return json({ orders: data });
    }
    case "mechanicsForCustomer": {
      const { data, error } = await supabase.rpc("nearby_bengkels", {
        p_lat: payload.latitude,
        p_lon: payload.longitude,
        p_radius_m: radiusMeters,
      });
      if (error) return json({ error: error.message }, 400);
      return json({ mechanics: data });
    }
    case "placeBid": {
      // Re-verify the order is still open before writing, and block self-bids
      // (the DB trigger enforces the self-bid rule too — this is a clean early error).
      const { data: order, error: orderError } = await supabase
        .from("service_requests")
        .select("id, status, bengkel_id, customer_id")
        .eq("id", payload.serviceRequestId)
        .single();
      if (orderError || !order) return json({ error: "Order not found" }, 404);
      if (order.customer_id === userId) {
        return json({ error: "Tidak dapat menawar order sendiri" }, 403);
      }
      if (order.status !== "pending" || order.bengkel_id !== null) {
        return json({ error: "Order sudah tidak menerima tawaran" }, 409);
      }

      // Upsert on (service_request_id, provider_uid) so a bengkel can revise a
      // previously-declined offer; resetting status to 'pending' re-surfaces it.
      const { data, error } = await supabase
        .from("bids")
        .upsert(
          {
            service_request_id: payload.serviceRequestId,
            provider_uid: userId,
            bengkel_id: payload.bengkelId,
            price: payload.price,
            notes: payload.notes ?? null,
            status: "pending",
          },
          { onConflict: "service_request_id,provider_uid" },
        )
        .select()
        .single();
      if (error) return json({ error: error.message }, 400);
      return json({ bid: data });
    }
    default:
      return json({ error: "Unknown action" }, 400);
  }
});
