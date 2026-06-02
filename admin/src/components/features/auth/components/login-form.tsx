"use client"

import { ShieldCheck } from "lucide-react"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Spinner } from "@/components/ui/spinner"
import { useLoginForm } from "@/components/features/auth/hooks/use-login-form"

export function LoginForm() {
  const { state, action, pending } = useLoginForm()

  return (
    <Card className="w-full max-w-sm shadow-lg">
      <CardHeader className="text-center">
        <div className="mx-auto mb-2 flex size-10 items-center justify-center rounded-lg bg-muted">
          <ShieldCheck className="size-5" />
        </div>
        <CardTitle>Masuk Admin BengkelIn</CardTitle>
        <CardDescription>
          Khusus akun dengan akses admin. Hubungi pengelola untuk mendapatkan
          akses.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form action={action}>
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="email">Email</FieldLabel>
              <Input
                id="email"
                name="email"
                type="email"
                placeholder="admin@bengkelin.id"
                autoComplete="email"
                required
              />
            </Field>
            <Field>
              <FieldLabel htmlFor="password">Kata Sandi</FieldLabel>
              <Input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                required
              />
            </Field>
            {state.error ? (
              <Alert variant="destructive">
                <AlertDescription>{state.error}</AlertDescription>
              </Alert>
            ) : null}
            <Button type="submit" disabled={pending}>
              {pending ? <Spinner /> : null}
              Masuk
            </Button>
          </FieldGroup>
        </form>
      </CardContent>
    </Card>
  )
}
