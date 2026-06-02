export interface ConfirmActionButtonProps {
  label: string
  variant: "default" | "destructive"
  title: string
  description: string
  confirmLabel: string
  disabled: boolean
  onConfirm: () => void
}
