import { GlobalErrorClient } from './global-error-client'

export const dynamic = 'force-dynamic'

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <html lang="es">
      <body>
        <GlobalErrorClient error={error} />
      </body>
    </html>
  )
}
