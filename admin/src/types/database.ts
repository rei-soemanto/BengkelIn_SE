export type BengkelStatus = "Pending" | "Verified" | "Rejected"

export interface UserRow {
  id: string
  name: string | null
  profile_image_url: string | null
  balance: number | null
  role: string | null
  is_mechanic: boolean | null
  is_provider: boolean | null
}

export interface BengkelRow {
  id: string
  provider_uid: string
  name: string
  address: string
  latitude: number | null
  longitude: number | null
  status: BengkelStatus
  average_rating: number | null
  total_reviews: number | null
  created_at: string | null
}

export interface PendingBengkelRpcRow {
  id: string
  provider_uid: string
  name: string
  address: string
  latitude: number | null
  longitude: number | null
  status: BengkelStatus
  created_at: string | null
  requester_name: string | null
  requester_email: string | null
  requester_phone: string | null
}

export interface MechanicSummary {
  id: string
  name: string | null
  email: string | null
  phone: string | null
}

export interface VerifiedBengkelRpcRow {
  id: string
  provider_uid: string
  name: string
  address: string
  latitude: number | null
  longitude: number | null
  created_at: string | null
  average_rating: number | null
  total_reviews: number | null
  provider_name: string | null
  provider_email: string | null
  provider_phone: string | null
  mechanics: MechanicSummary[]
}
