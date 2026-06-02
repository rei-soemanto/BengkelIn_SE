"use client"

import { Store } from "lucide-react"
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import {
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
} from "@/components/ui/empty"
import { BengkelMapPreview } from "@/components/features/bengkels/components/bengkel-map-preview"
import { MechanicList } from "@/components/features/bengkels/components/mechanic-list"
import type { VerifiedBengkelsListProps } from "@/components/features/bengkels/types/bengkel"

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-xs text-muted-foreground">{label}</span>
      <span className="text-sm wrap-break-word">{value}</span>
    </div>
  )
}

export function VerifiedBengkelsList({ bengkels }: VerifiedBengkelsListProps) {
  if (bengkels.length === 0) {
    return (
      <Empty>
        <EmptyHeader>
          <EmptyMedia variant="icon">
            <Store />
          </EmptyMedia>
          <EmptyTitle>Belum ada bengkel terverifikasi</EmptyTitle>
          <EmptyDescription>
            Bengkel yang telah disetujui akan muncul di sini.
          </EmptyDescription>
        </EmptyHeader>
      </Empty>
    )
  }

  return (
    <Accordion multiple>
      {bengkels.map((bengkel) => (
        <AccordionItem key={bengkel.id} value={bengkel.id}>
          <AccordionTrigger>
            <span className="flex flex-1 items-center justify-between gap-2 pr-2">
              <span className="flex flex-col gap-0.5">
                <span>{bengkel.name}</span>
                <span className="text-xs font-normal text-muted-foreground">
                  {bengkel.providerName ?? "—"}
                </span>
              </span>
              <Badge variant="secondary">
                {bengkel.mechanics.length} mekanik
              </Badge>
            </span>
          </AccordionTrigger>
          <AccordionContent>
            <div className="flex flex-col gap-4">
              <div className="grid gap-3 sm:grid-cols-2">
                <DetailRow
                  label="Pemilik"
                  value={bengkel.providerName ?? "—"}
                />
                <DetailRow
                  label="Email Pemilik"
                  value={bengkel.providerEmail ?? "—"}
                />
                <DetailRow
                  label="Telepon Pemilik"
                  value={bengkel.providerPhone ?? "—"}
                />
                <DetailRow label="Alamat" value={bengkel.address} />
              </div>

              <BengkelMapPreview
                name={bengkel.name}
                address={bengkel.address}
                latitude={bengkel.latitude}
                longitude={bengkel.longitude}
              />

              <Separator />

              <div className="flex flex-col gap-2">
                <span className="text-sm font-medium">
                  Mekanik ({bengkel.mechanics.length})
                </span>
                <MechanicList mechanics={bengkel.mechanics} />
              </div>
            </div>
          </AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  )
}
