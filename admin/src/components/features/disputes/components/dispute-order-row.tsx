"use client"

import { useState } from "react"
import { ChevronDown } from "lucide-react"
import { TableCell, TableRow } from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import {
  Item,
  ItemActions,
  ItemContent,
  ItemDescription,
  ItemGroup,
  ItemTitle,
} from "@/components/ui/item"
import { ToneBadge } from "@/components/tone-badge"
import { DisputeResolutionDialog } from "@/components/features/disputes/components/dispute-resolution-dialog"
import { formatRupiah, formatDateTime, cn } from "@/lib/utils"
import type { DisputeStatus } from "@/types/database"
import type { Tone } from "@/types/tone"
import type { DisputeOrderRowProps } from "@/components/features/disputes/types/dispute"

const statusMeta: Record<DisputeStatus, { label: string; tone: Tone }> = {
  pending: { label: "Menunggu", tone: "amber" },
  refunded: { label: "Dikembalikan", tone: "sky" },
  paid: { label: "Diteruskan", tone: "emerald" },
}

const initiatorLabel: Record<string, string> = {
  customer: "Pelanggan",
  provider: "Bengkel",
}

const sourceLabel: Record<string, string> = {
  dispute: "Sengketa Dana",
  behavior: "Laporan Perilaku",
}

export function DisputeOrderRow({ order, columnCount }: DisputeOrderRowProps) {
  const [open, setOpen] = useState(false)

  return (
    <>
      <TableRow
        className="cursor-pointer"
        onClick={() => setOpen((value) => !value)}
      >
        <TableCell className="w-10">
          <ChevronDown
            className={cn(
              "size-4 text-muted-foreground transition-transform",
              open ? "" : "-rotate-90"
            )}
          />
        </TableCell>
        <TableCell className="font-medium">
          {order.bengkelName ?? "—"}
        </TableCell>
        <TableCell>{order.customerName ?? "—"}</TableCell>
        <TableCell>{order.serviceType ?? "—"}</TableCell>
        <TableCell>{order.complaints.length} komplain</TableCell>
        <TableCell className="text-right">
          {formatRupiah(order.price)}
        </TableCell>
        <TableCell>
          {order.pendingCount > 0 ? (
            <ToneBadge tone="amber">{order.pendingCount} menunggu</ToneBadge>
          ) : (
            <ToneBadge tone="emerald">Selesai</ToneBadge>
          )}
        </TableCell>
      </TableRow>

      {open ? (
        <TableRow className="hover:bg-transparent">
          <TableCell colSpan={columnCount} className="bg-muted/30 p-4">
            <div className="mb-3 flex flex-wrap items-center gap-2">
              <span className="text-xs font-medium text-muted-foreground">
                ID Pesanan
              </span>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">
                {order.serviceRequestId}
              </code>
            </div>
            <ItemGroup>
              {order.complaints.map((complaint) => {
                const meta = statusMeta[complaint.status]
                return (
                  <Item
                    key={complaint.id}
                    variant="outline"
                    className="bg-card"
                  >
                    <ItemContent>
                      <ItemTitle className="flex-wrap">
                        <Badge variant="outline">
                          {sourceLabel[complaint.source] ?? complaint.source}
                        </Badge>
                        <ToneBadge
                          tone={
                            complaint.initiatorRole === "provider"
                              ? "sky"
                              : "neutral"
                          }
                        >
                          {initiatorLabel[complaint.initiatorRole] ??
                            complaint.initiatorRole}
                        </ToneBadge>
                        <span className="font-normal text-muted-foreground">
                          {complaint.initiatorName ?? "—"}
                        </span>
                      </ItemTitle>
                      <ItemDescription>{complaint.reason}</ItemDescription>
                      <span className="text-xs text-muted-foreground">
                        {formatDateTime(complaint.createdAt)}
                      </span>
                    </ItemContent>
                    <ItemActions>
                      <ToneBadge tone={meta.tone}>{meta.label}</ToneBadge>
                      <DisputeResolutionDialog dispute={complaint} />
                    </ItemActions>
                  </Item>
                )
              })}
            </ItemGroup>
          </TableCell>
        </TableRow>
      ) : null}
    </>
  )
}
