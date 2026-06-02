import { Banknote } from "lucide-react"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
} from "@/components/ui/empty"
import { ToneBadge } from "@/components/tone-badge"
import { WithdrawalReviewDialog } from "@/components/features/withdrawals/components/withdrawal-review-dialog"
import { formatRupiah } from "@/lib/utils"
import type { WithdrawalStatus } from "@/types/database"
import type { Tone } from "@/types/tone"
import type { WithdrawalsTableProps } from "@/components/features/withdrawals/types/withdrawal"

const statusMeta: Record<WithdrawalStatus, { label: string; tone: Tone }> = {
  pending: { label: "Menunggu", tone: "amber" },
  approved: { label: "Disetujui", tone: "emerald" },
  rejected: { label: "Ditolak", tone: "rose" },
}

export function WithdrawalsTable({ withdrawals }: WithdrawalsTableProps) {
  if (withdrawals.length === 0) {
    return (
      <Empty>
        <EmptyHeader>
          <EmptyMedia variant="icon">
            <Banknote />
          </EmptyMedia>
          <EmptyTitle>Tidak ada permintaan penarikan</EmptyTitle>
          <EmptyDescription>
            Permintaan penarikan saldo dari pengguna akan muncul di sini.
          </EmptyDescription>
        </EmptyHeader>
      </Empty>
    )
  }

  return (
    <div className="overflow-hidden rounded-xl border bg-card shadow-sm">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Pengguna</TableHead>
            <TableHead>Bank</TableHead>
            <TableHead className="text-right">Jumlah</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="text-right">Aksi</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {withdrawals.map((withdrawal) => {
            const meta = statusMeta[withdrawal.status]
            return (
              <TableRow key={withdrawal.id}>
                <TableCell className="font-medium">
                  {withdrawal.userName ?? "—"}
                </TableCell>
                <TableCell>{withdrawal.bankName ?? "—"}</TableCell>
                <TableCell className="text-right">
                  {formatRupiah(withdrawal.amount)}
                </TableCell>
                <TableCell>
                  <ToneBadge tone={meta.tone}>{meta.label}</ToneBadge>
                </TableCell>
                <TableCell className="text-right">
                  <WithdrawalReviewDialog withdrawal={withdrawal} />
                </TableCell>
              </TableRow>
            )
          })}
        </TableBody>
      </Table>
    </div>
  )
}
