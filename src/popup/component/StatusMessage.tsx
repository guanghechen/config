interface IStatusMessageProps {
  readonly error: string | null
  readonly message: string
}

export function StatusMessage({ error, message }: IStatusMessageProps) {
  if (!message) return null

  return (
    <p
      id="appearance-status"
      className={error ? 'status-message status-message-error' : 'status-message'}
      role={error ? 'alert' : 'status'}
      aria-live="polite"
    >
      {message}
    </p>
  )
}
