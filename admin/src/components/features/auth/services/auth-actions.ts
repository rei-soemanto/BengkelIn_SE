"use server"

import { redirect } from "next/navigation"
import { createClient } from "@/lib/supabase/server"
import type { LoginFormState } from "@/components/features/auth/types/auth"
import type { UserRow } from "@/types/database"

const INVALID_CREDENTIALS =
  "Email atau kata sandi salah, atau akun tidak memiliki akses admin."

export async function login(
  _prevState: LoginFormState,
  formData: FormData
): Promise<LoginFormState> {
  const email = String(formData.get("email") ?? "").trim()
  const password = String(formData.get("password") ?? "")

  if (!email || !password) {
    return { error: "Email dan kata sandi wajib diisi." }
  }

  const supabase = await createClient()

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (error || !data.user) {
    return { error: INVALID_CREDENTIALS }
  }

  const { data: profile } = await supabase
    .from("users")
    .select("role")
    .eq("id", data.user.id.toLowerCase())
    .single<Pick<UserRow, "role">>()

  if (profile?.role !== "ADMIN") {
    await supabase.auth.signOut()
    return { error: INVALID_CREDENTIALS }
  }

  redirect("/")
}

export async function logout(): Promise<void> {
  const supabase = await createClient()
  await supabase.auth.signOut()
  redirect("/login")
}
