import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { LiteralBox } from '@/component/LiteralBox'
import { useImageViewViewModel } from '../context'

export const LiteralPane: React.FC = () => {
  const viewmodel = useImageViewViewModel()
  const content = useStateValue(viewmodel.data$)
  const literalContent = useStateValue(viewmodel.literalContent$)
  const [loading, setLoading] = React.useState<boolean>(false)
  const [error, setError] = React.useState<string | null>(null)

  // Calculate and cache literal content when this pane is rendered
  React.useEffect(() => {
    if (!content?.url) {
      setError(null)
      return
    }

    // If content is already cached, use it
    if (literalContent) {
      setLoading(false)
      setError(null)
      return
    }

    setLoading(true)
    setError(null)

    const convertToBase64 = async (): Promise<void> => {
      try {
        const response = await fetch(content.url)
        if (!response.ok) {
          throw new Error(`Failed to fetch image: ${response.status}`)
        }

        const blob = await response.blob()

        // Convert blob to base64 using FileReader to avoid stack overflow
        const base64 = await new Promise<string>((resolve, reject) => {
          const reader = new FileReader()
          reader.onload = () => {
            const result = reader.result as string
            // Extract base64 part after "data:...;base64,"
            const base64Data = result.split(',')[1]
            resolve(base64Data)
          }
          reader.onerror = () => reject(reader.error)
          reader.readAsDataURL(blob)
        })

        const mimeType = blob.type || 'application/octet-stream'
        const base64WithPrefix = `data:${mimeType};base64,${base64}`

        // Cache the result in viewmodel
        viewmodel.literalContent$.next(base64WithPrefix)
      } catch (err) {
        console.error('Error converting image to base64:', err)
        setError(err instanceof Error ? err.message : 'Unknown error')
      } finally {
        setLoading(false)
      }
    }

    void convertToBase64()
  }, [content?.url, literalContent, viewmodel])

  if (loading) {
    return (
      <div className="box-border size-full flex justify-center">
        <div className="flex items-center text-gray-500 dark:text-gray-400">
          Converting to base64...
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="box-border size-full flex justify-center">
        <div className="flex items-center bg-gray-100 text-red-500 dark:bg-gray-800 dark:text-red-400">
          Error: {error}
        </div>
      </div>
    )
  }

  if (!literalContent) {
    return (
      <div className="box-border size-full flex justify-center">
        <div className="flex items-center bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400">
          No Content Found
        </div>
      </div>
    )
  }

  return (
    <LiteralBox content={literalContent}>
      <div className="w-full h-full p-4 text-sm font-mono bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100 overflow-auto">
        <div className="whitespace-pre-wrap break-all font-mono text-xs leading-relaxed">
          {literalContent}
        </div>
      </div>
    </LiteralBox>
  )
}

LiteralPane.displayName = 'ImageViewLiteralPane'
