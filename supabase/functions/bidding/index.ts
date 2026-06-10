import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/** Request body shared by all bidding actions; fields beyond `action` vary per action. */
interface BiddingPayload {
    action?: string;
    latitude?: number;
    longitude?: number;
    radiusMeters?: number;
    serviceRequestId?: string;
    bengkelId?: string;
    price?: number;
    notes?: string;
}

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/**
 * Builds a standardized JSON response with CORS headers.
 * @param body - Serializable response payload.
 * @param status - HTTP status code (defaults to 200).
 * @returns The JSON `Response`.
 */
function json(body: unknown, status = 200): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
}

Deno.serve(async (req: Request) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

    try {
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

        let payload: BiddingPayload;
        try {
            payload = await req.json();
        } catch {
            return json({ error: "Invalid JSON body" }, 400);
        }

        const action = payload.action ?? "";
        const radiusMeters = payload.radiusMeters ?? 5000;

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

                const { data: bengkel, error: bengkelError } = await supabase
                    .from("bengkels")
                    .select("id, provider_uid")
                    .eq("id", payload.bengkelId)
                    .single();
                if (bengkelError || !bengkel || bengkel.provider_uid !== userId) {
                    return json({ error: "Bengkel bukan milik Anda" }, 403);
                }
                
                const price = Number(payload.price);
                if (!Number.isFinite(price) || price <= 0) {
                    return json({ error: "Harga tidak valid" }, 400);
                }
                if (order.price != null && price < Number(order.price)) {
                    return json({ error: "Tawaran di bawah harga pelanggan" }, 400);
                }

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
    } catch (err) {
        return json({ error: err instanceof Error ? err.message : "Internal server error" }, 500);
    }
});
