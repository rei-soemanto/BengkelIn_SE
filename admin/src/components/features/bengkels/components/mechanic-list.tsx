import { Mail, Phone, Wrench } from "lucide-react"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import type { MechanicListProps } from "@/components/features/bengkels/types/bengkel"

export function MechanicList({ mechanics }: MechanicListProps) {
  if (mechanics.length === 0) {
    return (
      <div className="flex items-center gap-2 rounded-lg border border-dashed p-3 text-sm text-muted-foreground">
        <Wrench className="size-4" />
        Belum ada mekanik terdaftar di bengkel ini.
      </div>
    )
  }

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Nama Mekanik</TableHead>
          <TableHead>Email</TableHead>
          <TableHead>Telepon</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {mechanics.map((mechanic) => (
          <TableRow key={mechanic.id}>
            <TableCell className="font-medium">
              {mechanic.name ?? "—"}
            </TableCell>
            <TableCell>
              <span className="flex items-center gap-1.5 text-muted-foreground">
                <Mail className="size-3.5" />
                {mechanic.email ?? "—"}
              </span>
            </TableCell>
            <TableCell>
              <span className="flex items-center gap-1.5 text-muted-foreground">
                <Phone className="size-3.5" />
                {mechanic.phone ?? "—"}
              </span>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}
