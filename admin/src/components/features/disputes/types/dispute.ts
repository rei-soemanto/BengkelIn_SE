import type { DisputeStatus, DisputeInitiatorRole } from "@/types/database"

export interface Dispute {
  id: string
  status: DisputeStatus
  reason: string
  proofUrl: string | null
  initiatorRole: DisputeInitiatorRole
  initiatorName: string | null
  createdAt: string | null
  resolvedAt: string | null
  serviceRequestId: string
  serviceType: string | null
  description: string | null
  price: number | null
  orderStatus: string | null
  orderCreatedAt: string | null
  customerId: string
  customerName: string | null
  customerEmail: string | null
  bengkelId: string | null
  bengkelName: string | null
  bengkelAddress: string | null
  providerUid: string | null
  providerName: string | null
  providerEmail: string | null
}

export interface DisputeActionResult {
  ok: boolean
  error?: string
}

export interface DisputesTableProps {
  disputes: Dispute[]
}

export interface DisputeResolutionDialogProps {
  dispute: Dispute
}
