"use client"

import Link from "next/link"
import { ExternalLink } from "lucide-react"
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
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { ConfirmActionButton } from "@/components/confirm-action-button"
import { useDisputeResolution } from "@/components/features/disputes/hooks/use-dispute-resolution"
import { formatRupiah, formatDateTime } from "@/lib/utils"
import type { DisputeResolutionDialogProps } from "@/components/features/disputes/types/dispute"

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-xs text-muted-foreground">{label}</span>
      <span className="text-sm wrap-break-word">{value}</span>
    </div>
  )
}

const initiatorLabel: Record<string, string> = {
  customer: "Pelanggan",
  provider: "Bengkel",
}

export function DisputeResolutionDialog({
  dispute,
}: DisputeResolutionDialogProps) {
  const { pending, refund, payout } = useDisputeResolution()
  const isPending = dispute.status === "pending"

  return (
    <Dialog>
      <DialogTrigger
        render={<Button variant="outline" size="sm" />}
      >
        {isPending ? "Tinjau" : "Lihat"}
      </DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Komplain {dispute.serviceType ?? "Pesanan"}</DialogTitle>
          <DialogDescription>
            Tinjau detail pesanan dan laporan sebelum memutuskan saldo.
          </DialogDescription>
        </DialogHeader>

        <div className="flex max-h-[60vh] flex-col gap-4 overflow-y-auto">
          <div className="flex flex-col gap-2 rounded-lg bg-muted p-3">
            <div className="flex items-center justify-between gap-2">
              <span className="text-xs font-medium text-muted-foreground">
                Laporan dibuat oleh
              </span>
              <Badge variant="secondary">
                {initiatorLabel[dispute.initiatorRole] ?? dispute.initiatorRole}
              </Badge>
            </div>
            <span className="text-sm font-medium">
              {dispute.initiatorName ?? "—"}
            </span>
            <p className="text-sm wrap-break-word">{dispute.reason}</p>
            {dispute.proofUrl ? (
              <Button
                variant="link"
                size="sm"
                className="h-auto justify-start p-0"
                nativeButton={false}
                render={
                  <Link
                    href={dispute.proofUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                  />
                }
              >
                <ExternalLink className="size-3.5" />
                Lihat bukti
              </Button>
            ) : null}
            <span className="text-xs text-muted-foreground">
              {formatDateTime(dispute.createdAt)}
            </span>
          </div>

          <Separator />

          <div className="grid gap-3 sm:grid-cols-2">
            <DetailRow label="Pelanggan" value={dispute.customerName ?? "—"} />
            <DetailRow label="Email Pelanggan" value={dispute.customerEmail ?? "—"} />
            <DetailRow label="Bengkel" value={dispute.bengkelName ?? "—"} />
            <DetailRow label="Pemilik Bengkel" value={dispute.providerName ?? "—"} />
            <DetailRow label="Alamat Bengkel" value={dispute.bengkelAddress ?? "—"} />
            <DetailRow label="Email Pemilik" value={dispute.providerEmail ?? "—"} />
          </div>

          <Separator />

          <div className="grid gap-3 sm:grid-cols-2">
            <DetailRow label="Jenis Layanan" value={dispute.serviceType ?? "—"} />
            <DetailRow label="Nilai Pesanan" value={formatRupiah(dispute.price)} />
            <DetailRow
              label="Pesanan Dibuat"
              value={formatDateTime(dispute.orderCreatedAt)}
            />
            <DetailRow
              label="Deskripsi"
              value={dispute.description ?? "—"}
            />
          </div>
        </div>

        {isPending ? (
          <DialogFooter>
            <ConfirmActionButton
              label="Teruskan ke Bengkel"
              variant="default"
              title="Teruskan saldo ke bengkel?"
              description={`Saldo sebesar ${formatRupiah(dispute.price)} akan dipindahkan dari pelanggan ke bengkel "${dispute.bengkelName ?? "—"}". Tindakan ini tidak dapat dibatalkan.`}
              confirmLabel="Teruskan"
              disabled={pending}
              onConfirm={() => payout(dispute.id)}
            />
            <ConfirmActionButton
              label="Kembalikan ke Pelanggan"
              variant="destructive"
              title="Kembalikan saldo ke pelanggan?"
              description={`Saldo sebesar ${formatRupiah(dispute.price)} akan dikembalikan ke saldo pelanggan dan bengkel tidak menerima pembayaran. Tindakan ini tidak dapat dibatalkan.`}
              confirmLabel="Kembalikan"
              disabled={pending}
              onConfirm={() => refund(dispute.id)}
            />
          </DialogFooter>
        ) : (
          <DialogFooter>
            <p className="text-sm text-muted-foreground">
              Komplain ini telah diselesaikan pada{" "}
              {formatDateTime(dispute.resolvedAt)}.
            </p>
          </DialogFooter>
        )}
      </DialogContent>
    </Dialog>
  )
}
