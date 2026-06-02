import Link from "next/link"
import { Wrench } from "lucide-react"
import { LogoutButton } from "@/components/features/auth/components/logout-button"
import { MainNav } from "@/components/main-nav"
import { MobileNav } from "@/components/mobile-nav"

export function AdminHeader() {
  return (
    <header className="sticky top-0 z-40 border-b bg-background/95 shadow-sm backdrop-blur">
      <div className="mx-auto flex h-14 w-full max-w-5xl items-center justify-between gap-2 px-4 min-[2000px]:max-w-[1600px] min-[2560px]:max-w-[2000px] lg:px-6">
        <div className="flex min-w-0 items-center gap-2 lg:gap-6">
          <MobileNav />
          <Link
            href="/"
            className="flex shrink-0 items-center gap-2 font-medium"
          >
            <Wrench className="size-4" />
            <span className="truncate">BengkelIn Admin</span>
          </Link>
          <MainNav />
        </div>
        <LogoutButton />
      </div>
    </header>
  )
}
