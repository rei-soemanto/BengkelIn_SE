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
import { ConfirmActionButton } from "@/components/confirm-action-button"
import { useWithdrawalReview } from "@/components/features/withdrawals/hooks/use-withdrawal-review"
import { formatRupiah, formatDateTime } from "@/lib/utils"
import type { WithdrawalReviewDialogProps } from "@/components/features/withdrawals/types/withdrawal"

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-xs text-muted-foreground">{label}</span>
      <span className="text-sm wrap-break-word">{value}</span>
    </div>
  )
}

export function WithdrawalReviewDialog({
  withdrawal,
}: WithdrawalReviewDialogProps) {
  const { pending, approve, reject } = useWithdrawalReview()
  const isPending = withdrawal.status === "pending"

  return (
    <Dialog>
      <DialogTrigger render={<Button variant="outline" size="sm" />}>
        {isPending ? "Tinjau" : "Lihat"}
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{formatRupiah(withdrawal.amount)}</DialogTitle>
          <DialogDescription>
            Tinjau permintaan penarikan saldo sebelum menyetujui atau menolak.
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col gap-3">
          <DetailRow label="Pengguna" value={withdrawal.userName ?? "—"} />
          <DetailRow label="Email" value={withdrawal.userEmail ?? "—"} />
          <DetailRow
            label="Saldo Tersisa"
            value={formatRupiah(withdrawal.userBalance)}
          />
          <Separator />
          <DetailRow
            label="Jumlah Penarikan"
            value={formatRupiah(withdrawal.amount)}
          />
          <DetailRow label="Bank" value={withdrawal.bankName ?? "—"} />
          <DetailRow
            label="Nomor Rekening"
            value={withdrawal.bankAccountNumber ?? "—"}
          />
          <DetailRow
            label="Atas Nama"
            value={withdrawal.bankAccountName ?? "—"}
          />
          <DetailRow
            label="Diajukan"
            value={formatDateTime(withdrawal.createdAt)}
          />
        </div>

        {isPending ? (
          <DialogFooter>
            <ConfirmActionButton
              label="Tolak"
              variant="destructive"
              title="Tolak penarikan?"
              description={`Permintaan penarikan ${formatRupiah(withdrawal.amount)} akan ditolak dan saldo dikembalikan ke pengguna.`}
              confirmLabel="Tolak"
              disabled={pending}
              onConfirm={() => reject(withdrawal.id)}
            />
            <ConfirmActionButton
              label="Setujui"
              variant="default"
              title="Setujui penarikan?"
              description={`Permintaan penarikan ${formatRupiah(withdrawal.amount)} ke rekening ${withdrawal.bankName ?? "—"} a.n. ${withdrawal.bankAccountName ?? "—"} akan disetujui. Pastikan transfer dana sudah dilakukan.`}
              confirmLabel="Setujui"
              disabled={pending}
              onConfirm={() => approve(withdrawal.id)}
            />
          </DialogFooter>
        ) : (
          <DialogFooter>
            <p className="text-sm text-muted-foreground">
              Penarikan ini telah diproses pada{" "}
              {formatDateTime(withdrawal.updatedAt)}.
            </p>
          </DialogFooter>
        )}
      </DialogContent>
    </Dialog>
  )
}
