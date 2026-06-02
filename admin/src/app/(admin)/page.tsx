import Link from "next/link"
import { ClipboardList, Store } from "lucide-react"
import { requireAdmin } from "@/lib/auth/dal"
import {
  countPendingBengkels,
  countVerifiedBengkels,
} from "@/components/features/bengkels/services/bengkel-service"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Button } from "@/components/ui/button"

export default async function DashboardPage() {
  const admin = await requireAdmin()
  const [pendingCount, verifiedCount] = await Promise.all([
    countPendingBengkels(),
    countVerifiedBengkels(),
  ])

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1">
        <h1 className="font-heading text-xl font-medium">
          Halo, {admin.name ?? "Admin"}
        </h1>
        <p className="text-sm text-muted-foreground">
          Selamat datang di dasbor admin BengkelIn.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Card>
          <CardHeader>
            <div className="mb-1 flex size-9 items-center justify-center rounded-lg bg-muted">
              <ClipboardList className="size-4" />
            </div>
            <CardTitle>Persetujuan Bengkel</CardTitle>
            <CardDescription>
              {pendingCount > 0
                ? `${pendingCount} pengajuan menunggu ditinjau.`
                : "Tidak ada pengajuan yang menunggu."}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button nativeButton={false} render={<Link href="/bengkels" />}>
              Tinjau pengajuan
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div className="mb-1 flex size-9 items-center justify-center rounded-lg bg-muted">
              <Store className="size-4" />
            </div>
            <CardTitle>Bengkel Terverifikasi</CardTitle>
            <CardDescription>
              {verifiedCount > 0
                ? `${verifiedCount} bengkel aktif terdaftar.`
                : "Belum ada bengkel terverifikasi."}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button
              variant="outline"
              nativeButton={false}
              render={<Link href="/bengkels/terverifikasi" />}
            >
              Lihat daftar
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
