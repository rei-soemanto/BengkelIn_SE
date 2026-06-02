"use client"

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import { BengkelMapPreview } from "@/components/features/bengkels/components/bengkel-map-preview"
import { ConfirmActionButton } from "@/components/features/bengkels/components/confirm-action-button"
import { useBengkelApproval } from "@/components/features/bengkels/hooks/use-bengkel-approval"
import type { BengkelApprovalDialogProps } from "@/components/features/bengkels/types/bengkel"

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-xs text-muted-foreground">{label}</span>
      <span className="text-sm wrap-break-word">{value}</span>
    </div>
  )
}

export function BengkelApprovalDialog({ bengkel }: BengkelApprovalDialogProps) {
  const { pending, approve, reject } = useBengkelApproval()

  return (
    <Dialog>
      <DialogTrigger render={<Button variant="outline" size="sm" />}>
        Tinjau
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{bengkel.name}</DialogTitle>
          <DialogDescription>
            Tinjau detail pengajuan sebelum menyetujui atau menolak.
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col gap-3">
          <DetailRow
            label="Nama Pemohon"
            value={bengkel.requesterName ?? "—"}
          />
          <DetailRow label="Email" value={bengkel.requesterEmail ?? "—"} />
          <DetailRow
            label="Nomor Telepon"
            value={bengkel.requesterPhone ?? "—"}
          />
          <Separator />
          <DetailRow label="Nama Bengkel" value={bengkel.name} />
          <DetailRow label="Alamat" value={bengkel.address} />
          <BengkelMapPreview
            name={bengkel.name}
            address={bengkel.address}
            latitude={bengkel.latitude}
            longitude={bengkel.longitude}
          />
        </div>

        <DialogFooter>
          <ConfirmActionButton
            label="Tolak"
            variant="destructive"
            title="Tolak pengajuan?"
            description={`Pengajuan bengkel "${bengkel.name}" akan ditandai sebagai ditolak.`}
            confirmLabel="Tolak"
            disabled={pending}
            onConfirm={() => reject(bengkel.id)}
          />
          <ConfirmActionButton
            label="Setujui"
            variant="default"
            title="Setujui bengkel?"
            description={`Bengkel "${bengkel.name}" akan diverifikasi dan tampil di aplikasi.`}
            confirmLabel="Setujui"
            disabled={pending}
            onConfirm={() => approve(bengkel.id)}
          />
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
