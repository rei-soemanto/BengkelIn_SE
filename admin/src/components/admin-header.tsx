import Link from "next/link"
import { Wrench } from "lucide-react"
import { LogoutButton } from "@/components/features/auth/components/logout-button"

export function AdminHeader() {
  return (
    <header className="sticky top-0 z-40 border-b bg-background/95 backdrop-blur">
      <div className="mx-auto flex h-14 w-full max-w-5xl items-center justify-between gap-4 px-4">
        <div className="flex items-center gap-6">
          <Link href="/" className="flex items-center gap-2 font-medium">
            <Wrench className="size-4" />
            BengkelIn Admin
          </Link>
          <nav className="flex items-center gap-4 text-sm text-muted-foreground">
            <Link href="/" className="transition-colors hover:text-foreground">
              Dasbor
            </Link>
            <Link
              href="/bengkels"
              className="transition-colors hover:text-foreground"
            >
              Persetujuan Bengkel
            </Link>
            <Link
              href="/bengkels/terverifikasi"
              className="transition-colors hover:text-foreground"
            >
              Bengkel Terverifikasi
            </Link>
          </nav>
        </div>
        <LogoutButton />
      </div>
    </header>
  )
}
