import { ShieldCheck } from "lucide-react"
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
import { DisputeResolutionDialog } from "@/components/features/disputes/components/dispute-resolution-dialog"
import { formatRupiah } from "@/lib/utils"
import type { DisputeStatus } from "@/types/database"
import type { DisputesTableProps } from "@/components/features/disputes/types/dispute"

const statusMeta: Record<
  DisputeStatus,
  { label: string; variant: "default" | "secondary" | "outline" }
> = {
  pending: { label: "Menunggu", variant: "default" },
  refunded: { label: "Dikembalikan", variant: "outline" },
  paid: { label: "Diteruskan", variant: "secondary" },
}

const initiatorLabel: Record<string, string> = {
  customer: "Pelanggan",
  provider: "Bengkel",
}

export function DisputesTable({ disputes }: DisputesTableProps) {
  if (disputes.length === 0) {
    return (
      <Empty>
        <EmptyHeader>
          <EmptyMedia variant="icon">
            <ShieldCheck />
          </EmptyMedia>
          <EmptyTitle>Tidak ada komplain</EmptyTitle>
          <EmptyDescription>
            Komplain pesanan dari pelanggan maupun bengkel akan muncul di sini.
          </EmptyDescription>
        </EmptyHeader>
      </Empty>
    )
  }

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Bengkel</TableHead>
          <TableHead>Pelanggan</TableHead>
          <TableHead>Pelapor</TableHead>
          <TableHead className="text-right">Nilai</TableHead>
          <TableHead>Status</TableHead>
          <TableHead className="text-right">Aksi</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {disputes.map((dispute) => {
          const meta = statusMeta[dispute.status]
          return (
            <TableRow key={dispute.id}>
              <TableCell className="font-medium">
                {dispute.bengkelName ?? "—"}
              </TableCell>
              <TableCell>{dispute.customerName ?? "—"}</TableCell>
              <TableCell>
                {initiatorLabel[dispute.initiatorRole] ?? dispute.initiatorRole}
              </TableCell>
              <TableCell className="text-right">
                {formatRupiah(dispute.price)}
              </TableCell>
              <TableCell>
                <Badge variant={meta.variant}>{meta.label}</Badge>
              </TableCell>
              <TableCell className="text-right">
                <DisputeResolutionDialog dispute={dispute} />
              </TableCell>
            </TableRow>
          )
        })}
      </TableBody>
    </Table>
  )
}
