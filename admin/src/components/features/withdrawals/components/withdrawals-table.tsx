import { Banknote } from "lucide-react"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import {
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
} from "@/components/ui/empty"
import { WithdrawalReviewDialog } from "@/components/features/withdrawals/components/withdrawal-review-dialog"
import { formatRupiah } from "@/lib/utils"
import type { WithdrawalStatus } from "@/types/database"
import type { WithdrawalsTableProps } from "@/components/features/withdrawals/types/withdrawal"

const statusMeta: Record<
  WithdrawalStatus,
  { label: string; variant: "default" | "secondary" | "outline" }
> = {
  pending: { label: "Menunggu", variant: "default" },
  approved: { label: "Disetujui", variant: "secondary" },
  rejected: { label: "Ditolak", variant: "outline" },
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
                <Badge variant={meta.variant}>{meta.label}</Badge>
              </TableCell>
              <TableCell className="text-right">
                <WithdrawalReviewDialog withdrawal={withdrawal} />
              </TableCell>
            </TableRow>
          )
        })}
      </TableBody>
    </Table>
  )
}
