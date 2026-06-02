"use client"

import { LogOut } from "lucide-react"
import { Button } from "@/components/ui/button"
import { logout } from "@/components/features/auth/services/auth-actions"

export function LogoutButton() {
  return (
    <form action={logout}>
      <Button type="submit" variant="outline" size="sm">
        <LogOut />
        Keluar
      </Button>
    </form>
  )
}
