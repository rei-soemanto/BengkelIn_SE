// BengkelIn — bidding edge function (Marketplace tier).
// Actions: ordersForMechanic (nearby open orders), mechanicsForCustomer
// (nearby verified bengkels), placeBid (upsert a revisable offer).
// Open-order status is lowercase 'pending'; the customer's offered price is read
// from service_requests.price (bigint). accept_bid lives in SQL, not here.
//
// DEPLOYED 2026-06-02 to project ipxwpxozreksmuiztwcy (version 5, verify_jwt on).

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
      const { data: order, error: orderError } = await supabase
        .from("service_requests")
        .select("id, status, bengkel_id, customer_id, price")
        .eq("id", payload.serviceRequestId)
        .single();
      if (orderError || !order) return json({ error: "Order not found" }, 404);
      if (order.customer_id === userId) {
        return json({ error: "Tidak dapat menawar order sendiri" }, 403);
      }
      if (order.status !== "pending" || order.bengkel_id !== null) {
        return json({ error: "Order sudah tidak menerima tawaran" }, 409);
      }

      // The bengkel being bid on must belong to the caller.
      const { data: bengkel, error: bengkelError } = await supabase
        .from("bengkels")
        .select("id, provider_uid")
        .eq("id", payload.bengkelId)
        .single();
      if (bengkelError || !bengkel || bengkel.provider_uid !== userId) {
        return json({ error: "Bengkel bukan milik Anda" }, 403);
      }

      // Bid must meet the customer's price floor.
      const price = Number(payload.price);
      if (!Number.isFinite(price) || price <= 0) {
        return json({ error: "Harga tidak valid" }, 400);
      }
      if (order.price != null && price < Number(order.price)) {
        return json({ error: "Tawaran di bawah harga pelanggan" }, 400);
      }

      // Upsert on (service_request_id, provider_uid) so a bengkel can revise a
      // previously-declined offer; resetting status to 'Pending' re-surfaces it.
      // Bid statuses are capitalized (Pending/Accepted/Rejected/Expired/AutoRejected)
      // to match the customer-side card, which is case-sensitive — unlike the lowercase
      // service_requests.status vocabulary.
      const { data, error } = await supabase
        .from("bids")
        .upsert(
          {
            service_request_id: payload.serviceRequestId,
            provider_uid: userId,
            bengkel_id: payload.bengkelId,
            price,
            notes: payload.notes ?? null,
            status: "Pending",
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
