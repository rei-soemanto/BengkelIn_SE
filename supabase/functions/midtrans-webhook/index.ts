import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const MIDTRANS_SERVER_KEY = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";

/** Midtrans HTTP notification fields this webhook reads (snake_case per Midtrans). */
interface MidtransNotification {
    order_id?: string;
    status_code?: string;
    gross_amount?: string;
    signature_key?: string;
    transaction_status?: string;
    fraud_status?: string;
    payment_type?: string;
}

/**
 * Verifies the Midtrans notification signature:
 * SHA-512(order_id + status_code + gross_amount + server key) must equal `signatureKey`.
 * @param orderId - The `order_id` from the notification.
 * @param statusCode - The `status_code` from the notification.
 * @param grossAmount - The `gross_amount` from the notification.
 * @param signatureKey - The `signature_key` claimed by the notification.
 * @returns Whether the signature is authentic.
 */
async function verifySignature(orderId: string, statusCode: string, grossAmount: string, signatureKey: string): Promise<boolean> {
    const raw = orderId + statusCode + grossAmount + MIDTRANS_SERVER_KEY;
    const bytes = new TextEncoder().encode(raw);
    const digest = await crypto.subtle.digest("SHA-512", bytes);
    const hex = Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
    return hex === signatureKey;
}

/**
 * Maps a Midtrans transaction status (plus fraud status) to the topup status
 * vocabulary used by the `settle_topup` RPC.
 * @param transactionStatus - Midtrans `transaction_status`.
 * @param fraudStatus - Midtrans `fraud_status`, only meaningful for `capture`.
 * @returns The internal topup status.
 */
function mapTransactionStatus(transactionStatus: string, fraudStatus?: string): "success" | "pending" | "failed" | "expired" | "cancelled" {
    switch (transactionStatus) {
        case "capture": return fraudStatus === "challenge" ? "pending" : "success";
        case "settlement": return "success";
        case "pending": return "pending";
        case "deny":
        case "failure": return "failed";
        case "cancel": return "cancelled";
        case "expire": return "expired";
        default: return "pending";
    }
}

/**
 * Builds a standardized JSON response.
 * @param body - Serializable response payload.
 * @param status - HTTP status code (defaults to 200).
 * @returns The JSON `Response`.
 */
function json(body: unknown, status = 200): Response {
    return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req: Request) => {
    if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

    try {
        if (!MIDTRANS_SERVER_KEY) return json({ error: "MIDTRANS_SERVER_KEY is not configured" }, 500);

        let n: MidtransNotification;
        try { n = await req.json(); } catch { return json({ error: "Invalid JSON body" }, 400); }

        const orderId = String(n.order_id ?? "");
        const statusCode = String(n.status_code ?? "");
        const grossAmount = String(n.gross_amount ?? "");
        const signatureKey = String(n.signature_key ?? "");
        const transactionStatus = String(n.transaction_status ?? "");
        const fraudStatus = n.fraud_status ? String(n.fraud_status) : undefined;
        const paymentType = n.payment_type ? String(n.payment_type) : null;

        const valid = await verifySignature(orderId, statusCode, grossAmount, signatureKey);
        if (!valid) return json({ error: "Invalid signature" }, 403);

        const newStatus = mapTransactionStatus(transactionStatus, fraudStatus);
        const adminClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

        const { error } = await adminClient.rpc("settle_topup", {
            p_order_id: orderId, p_status: newStatus, p_payment_type: paymentType,
        });
        if (error) {
            const notFound = (error.message ?? "").toLowerCase().includes("not found");
            return json({ error: error.message }, notFound ? 404 : 500);
        }
        return json({ received: true, status: newStatus });
    } catch (err) {
        return json({ error: err instanceof Error ? err.message : "Internal server error" }, 500);
    }
});
