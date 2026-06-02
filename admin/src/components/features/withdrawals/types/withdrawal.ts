import type { WithdrawalStatus } from "@/types/database"

export interface Withdrawal {
  id: string
  userId: string
  userName: string | null
  userEmail: string | null
  amount: number
  bankName: string | null
  bankAccountNumber: string | null
  bankAccountName: string | null
  status: WithdrawalStatus
  notes: string | null
  createdAt: string | null
  updatedAt: string | null
  userBalance: number | null
}

export interface WithdrawalActionResult {
  ok: boolean
  error?: string
}

export interface WithdrawalsTableProps {
  withdrawals: Withdrawal[]
}

export interface WithdrawalReviewDialogProps {
  withdrawal: Withdrawal
}
