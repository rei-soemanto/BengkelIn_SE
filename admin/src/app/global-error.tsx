"use client"

import "./globals.css"
import { Button } from "@/components/ui/button"
import type { ErrorBoundaryProps } from "@/types/error-boundary"

export default function GlobalError({ unstable_retry }: ErrorBoundaryProps) {
  return (
    <html lang="id">
      <body className="flex min-h-screen flex-col items-center justify-center gap-4 p-6 text-center antialiased">
        <h1 className="text-xl font-semibold">Terjadi kesalahan</h1>
        <p className="text-muted-foreground max-w-sm text-sm">
          Aplikasi sedang mengalami gangguan. Silakan coba lagi dalam beberapa
          saat.
        </p>
        <Button onClick={() => unstable_retry()}>Coba Lagi</Button>
      </body>
    </html>
  )
}
