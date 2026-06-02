import { Inbox } from "lucide-react"
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
import { BengkelApprovalDialog } from "@/components/features/bengkels/components/bengkel-approval-dialog"
import type { PendingBengkelsTableProps } from "@/components/features/bengkels/types/bengkel"

export function PendingBengkelsTable({ bengkels }: PendingBengkelsTableProps) {
  if (bengkels.length === 0) {
    return (
      <Empty>
        <EmptyHeader>
          <EmptyMedia variant="icon">
            <Inbox />
          </EmptyMedia>
          <EmptyTitle>Belum ada pengajuan bengkel</EmptyTitle>
          <EmptyDescription>
            Pengajuan bengkel baru akan muncul di sini untuk ditinjau.
          </EmptyDescription>
        </EmptyHeader>
      </Empty>
    )
  }

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Nama Bengkel</TableHead>
          <TableHead>Pemohon</TableHead>
          <TableHead>Alamat</TableHead>
          <TableHead className="text-right">Aksi</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {bengkels.map((bengkel) => (
          <TableRow key={bengkel.id}>
            <TableCell className="font-medium">{bengkel.name}</TableCell>
            <TableCell>{bengkel.requesterName ?? "—"}</TableCell>
            <TableCell className="max-w-xs truncate" title={bengkel.address}>
              {bengkel.address}
            </TableCell>
            <TableCell className="text-right">
              <BengkelApprovalDialog bengkel={bengkel} />
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}
