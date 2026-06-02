"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { cn } from "@/lib/utils"
import { navLinks } from "@/components/nav-links"

export function MainNav() {
  const pathname = usePathname()

  return (
    <nav className="hidden items-center gap-4 text-sm lg:flex">
      {navLinks.map((link) => (
        <Link
          key={link.href}
          href={link.href}
          className={cn(
            "whitespace-nowrap transition-colors hover:text-foreground",
            pathname === link.href
              ? "font-medium text-foreground"
              : "text-muted-foreground"
          )}
        >
          {link.label}
        </Link>
      ))}
    </nav>
  )
}
