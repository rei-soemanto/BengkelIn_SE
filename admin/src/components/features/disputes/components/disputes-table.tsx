import { ShieldCheck } from "lucide-react"
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
import { DisputeResolutionDialog } from "@/components/features/disputes/components/dispute-resolution-dialog"
import { formatRupiah } from "@/lib/utils"
import type { DisputeStatus } from "@/types/database"
import type { Tone } from "@/types/tone"
import type { DisputesTableProps } from "@/components/features/disputes/types/dispute"

const statusMeta: Record<DisputeStatus, { label: string; tone: Tone }> = {
  pending: { label: "Menunggu", tone: "amber" },
  refunded: { label: "Dikembalikan", tone: "sky" },
  paid: { label: "Diteruskan", tone: "emerald" },
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
    <div className="overflow-hidden rounded-xl border bg-card shadow-sm">
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
                  <ToneBadge
                    tone={
                      dispute.initiatorRole === "provider" ? "sky" : "neutral"
                    }
                  >
                    {initiatorLabel[dispute.initiatorRole] ??
                      dispute.initiatorRole}
                  </ToneBadge>
                </TableCell>
                <TableCell className="text-right">
                  {formatRupiah(dispute.price)}
                </TableCell>
                <TableCell>
                  <ToneBadge tone={meta.tone}>{meta.label}</ToneBadge>
                </TableCell>
                <TableCell className="text-right">
                  <DisputeResolutionDialog dispute={dispute} />
                </TableCell>
              </TableRow>
            )
          })}
        </TableBody>
      </Table>
    </div>
  )
}
