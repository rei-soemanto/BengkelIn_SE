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

export type DisputeStatus = "pending" | "refunded" | "paid"
export type DisputeInitiatorRole = "customer" | "provider"

export interface DisputeRpcRow {
  id: string
  status: DisputeStatus
  reason: string
  proof_url: string | null
  initiator_role: DisputeInitiatorRole
  initiator_name: string | null
  created_at: string | null
  resolved_at: string | null
  service_request_id: string
  service_type: string | null
  description: string | null
  price: number | null
  order_status: string | null
  order_created_at: string | null
  customer_id: string
  customer_name: string | null
  customer_email: string | null
  bengkel_id: string | null
  bengkel_name: string | null
  bengkel_address: string | null
  provider_uid: string | null
  provider_name: string | null
  provider_email: string | null
}

export type WithdrawalStatus = "pending" | "approved" | "rejected"

export interface WithdrawalRpcRow {
  id: string
  user_id: string
  user_name: string | null
  user_email: string | null
  amount: number
  bank_name: string | null
  bank_account_number: string | null
  bank_account_name: string | null
  status: WithdrawalStatus
  notes: string | null
  created_at: string | null
  updated_at: string | null
  user_balance: number | null
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
