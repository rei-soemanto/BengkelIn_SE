export interface ErrorBoundaryProps {
  error: Error & { digest?: string }
  unstable_retry: () => void
}
