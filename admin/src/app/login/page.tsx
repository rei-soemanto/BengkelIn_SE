import { redirect } from "next/navigation"
import { getAdminUser } from "@/lib/auth/dal"
import { LoginForm } from "@/components/features/auth/components/login-form"

export default async function LoginPage() {
  const admin = await getAdminUser()

  if (admin) {
    redirect("/")
  }

  return (
    <main className="flex flex-1 items-center justify-center p-4">
      <LoginForm />
    </main>
  )
}
