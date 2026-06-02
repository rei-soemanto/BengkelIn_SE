import "server-only"

import { cache } from "react"
import { redirect } from "next/navigation"
import { createClient } from "@/lib/supabase/server"
import type { AdminUser } from "@/types/auth"
import type { UserRow } from "@/types/database"

export const getAdminUser = cache(async (): Promise<AdminUser | null> => {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    return null
  }

  const { data, error } = await supabase
    .from("users")
    .select("id, name, role")
    .eq("id", user.id.toLowerCase())
    .single<Pick<UserRow, "id" | "name" | "role">>()

  if (error || data?.role !== "ADMIN") {
    return null
  }

  return {
    id: data.id,
    email: user.email ?? null,
    name: data.name,
  }
})

export async function requireAdmin(): Promise<AdminUser> {
  const admin = await getAdminUser()

  if (!admin) {
    redirect("/login")
  }

  return admin
}
