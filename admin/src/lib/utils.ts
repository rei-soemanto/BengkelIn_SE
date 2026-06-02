import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

const rupiahFormatter = new Intl.NumberFormat("id-ID", {
  style: "currency",
  currency: "IDR",
  maximumFractionDigits: 0,
})

export function formatRupiah(amount: number | null): string {
  return rupiahFormatter.format(amount ?? 0)
}

const dateTimeFormatter = new Intl.DateTimeFormat("id-ID", {
  dateStyle: "medium",
  timeStyle: "short",
})

export function formatDateTime(value: string | null): string {
  if (!value) {
    return "—"
  }
  return dateTimeFormatter.format(new Date(value))
}
