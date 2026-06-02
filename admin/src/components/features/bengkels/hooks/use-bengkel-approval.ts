"use client"

import { useTransition } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import {
  approveBengkel,
  rejectBengkel,
} from "@/components/features/bengkels/services/bengkel-actions"

export function useBengkelApproval() {
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
    approve: (id: string) =>
      run(approveBengkel, id, "Bengkel berhasil disetujui."),
    reject: (id: string) => run(rejectBengkel, id, "Pengajuan bengkel ditolak."),
  }
}
