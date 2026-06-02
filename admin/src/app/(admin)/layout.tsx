import { requireAdmin } from "@/lib/auth/dal"
import { AdminHeader } from "@/components/admin-header"

export default async function AdminLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  await requireAdmin()

  return (
    <div className="flex min-h-full flex-col">
      <AdminHeader />
      <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-6">
        {children}
      </main>
    </div>
  )
}
