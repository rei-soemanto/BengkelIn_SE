"use client"

import { useActionState } from "react"
import { login } from "@/components/features/auth/services/auth-actions"
import type { LoginFormState } from "@/components/features/auth/types/auth"

const initialState: LoginFormState = {}

export function useLoginForm() {
  const [state, action, pending] = useActionState(login, initialState)
  return { state, action, pending }
}
