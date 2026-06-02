import { ShieldCheck } from "lucide-react"
import {
  Table,
  TableBody,
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
import { DisputeOrderRow } from "@/components/features/disputes/components/dispute-order-row"
import type { DisputesTableProps } from "@/components/features/disputes/types/dispute"

const columnCount = 7

export function DisputesTable({ orders }: DisputesTableProps) {
  if (orders.length === 0) {
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
            <TableHead className="w-10" />
            <TableHead>Bengkel</TableHead>
            <TableHead>Pelanggan</TableHead>
            <TableHead>Layanan</TableHead>
            <TableHead>Komplain</TableHead>
            <TableHead className="text-right">Nilai</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {orders.map((order) => (
            <DisputeOrderRow
              key={order.serviceRequestId}
              order={order}
              columnCount={columnCount}
            />
          ))}
        </TableBody>
      </Table>
    </div>
  )
}
