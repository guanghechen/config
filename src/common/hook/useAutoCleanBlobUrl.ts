import React from 'react'

export const useAutoCleanBlobUrl = (url: string | null): void => {
  const prevUrlRef = React.useRef<string | null>(null)

  React.useEffect(() => {
    // Clean up previous URL when URL changes
    if (prevUrlRef.current && prevUrlRef.current !== url) {
      URL.revokeObjectURL(prevUrlRef.current)
    }
    prevUrlRef.current = url ?? null
  }, [url])

  React.useEffect(() => {
    // Only clean up on unmount
    return () => {
      if (prevUrlRef.current) {
        URL.revokeObjectURL(prevUrlRef.current)
      }
    }
  }, [])
}
