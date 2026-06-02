import type { BengkelStatus, MechanicSummary } from "@/types/database"

export interface Bengkel {
  id: string
  providerUid: string
  name: string
  address: string
  latitude: number | null
  longitude: number | null
  status: BengkelStatus
  createdAt: string | null
}

export interface PendingBengkelDetail extends Bengkel {
  requesterName: string | null
  requesterEmail: string | null
  requesterPhone: string | null
}

export interface ApprovalActionResult {
  ok: boolean
  error?: string
}

export interface PendingBengkelsTableProps {
  bengkels: PendingBengkelDetail[]
}

export interface BengkelApprovalDialogProps {
  bengkel: PendingBengkelDetail
}

export interface BengkelMapPreviewProps {
  name: string
  address: string
  latitude: number | null
  longitude: number | null
}

export interface VerifiedBengkel {
  id: string
  providerUid: string
  name: string
  address: string
  latitude: number | null
  longitude: number | null
  createdAt: string | null
  averageRating: number | null
  totalReviews: number | null
  providerName: string | null
  providerEmail: string | null
  providerPhone: string | null
  mechanics: MechanicSummary[]
}

export interface VerifiedBengkelsListProps {
  bengkels: VerifiedBengkel[]
}

export interface MechanicListProps {
  mechanics: MechanicSummary[]
}

export interface ConfirmActionButtonProps {
  label: string
  variant: "default" | "destructive"
  title: string
  description: string
  confirmLabel: string
  disabled: boolean
  onConfirm: () => void
}
