"use client"

import { TriangleAlert } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import type { ErrorBoundaryProps } from "@/types/error-boundary"

export default function AdminError({ unstable_retry }: ErrorBoundaryProps) {
  return (
    <div className="flex min-h-[60vh] items-center justify-center">
      <Card className="w-full max-w-md text-center">
        <CardHeader>
          <div className="mx-auto flex size-12 items-center justify-center rounded-full bg-destructive/10">
            <TriangleAlert className="size-6 text-destructive" />
          </div>
          <CardTitle>Gagal memuat halaman</CardTitle>
          <CardDescription>
            Data tidak dapat dimuat. Ini mungkin gangguan sementara pada server.
            Coba lagi dalam beberapa saat.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button onClick={() => unstable_retry()}>Coba Lagi</Button>
        </CardContent>
      </Card>
    </div>
  )
}
