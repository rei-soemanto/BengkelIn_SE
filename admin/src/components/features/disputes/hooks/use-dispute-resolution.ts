"use client"

import { useTransition } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import {
  refundDispute,
  payoutDispute,
} from "@/components/features/disputes/services/dispute-actions"
import type { DisputeSource } from "@/types/database"

export function useDisputeResolution() {
  const router = useRouter()
  const [pending, startTransition] = useTransition()

  function run(
    action: (
      id: string,
      source: DisputeSource
    ) => Promise<{ ok: boolean; error?: string }>,
    id: string,
    source: DisputeSource,
    successMessage: string
  ) {
    startTransition(async () => {
      const result = await action(id, source)
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
    refund: (id: string, source: DisputeSource) =>
      run(refundDispute, id, source, "Saldo dikembalikan ke pelanggan."),
    payout: (id: string, source: DisputeSource) =>
      run(payoutDispute, id, source, "Saldo diteruskan ke bengkel."),
  }
}
