"use client"

import { useTransition } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import {
  refundDispute,
  payoutDispute,
} from "@/components/features/disputes/services/dispute-actions"

export function useDisputeResolution() {
  const router = useRouter()
  const [pending, startTransition] = useTransition()

  function run(
    action: (id: string) => Promise<{ ok: boolean; error?: string }>,
    id: string,
    successMessage: string
  ) {
    startTransition(async () => {
      const result = await action(id)
      if (result.ok) {
        toast.success(successMessage)
        router.refresh()
      } else {
        toast.error(result.error ?? "Terjadi kesalahan. Coba lagi.")
      }
    })
  }

  return {
    pending,
    refund: (id: string) =>
      run(refundDispute, id, "Saldo dikembalikan ke pelanggan."),
    payout: (id: string) =>
      run(payoutDispute, id, "Saldo diteruskan ke bengkel."),
  }
}
