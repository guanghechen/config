import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { IPrismThemeScheme } from '@/component/code-highlighter'
import { CodeHighlighter, vscDarkTheme, vscLightTheme } from '@/component/code-highlighter'
import { LiteralBox } from '@/component/LiteralBox'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import { useImageViewViewModel } from '../context'

export const LiteralPane: React.FC = () => {
  const site = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(site.theme$)
  const themeScheme: IPrismThemeScheme = theme === SiteTheme.DARKEN ? vscDarkTheme : vscLightTheme

  const viewmodel = useImageViewViewModel()
  const content = useStateValue(viewmodel.data$)
  const [base64Content, setBase64Content] = React.useState<string | null>(null)
  const [loading, setLoading] = React.useState<boolean>(false)
  const [error, setError] = React.useState<string | null>(null)

  // Convert blob URL to base64 data URL
  React.useEffect(() => {
    if (!content?.url) {
      setBase64Content(null)
      setError(null)
      return
    }

    setLoading(true)
    setError(null)

    const convertToBase64 = async (): Promise<void> => {
      try {
        const response = await fetch(content.url)
        if (!response.ok) {
          throw new Error(`Failed to fetch blob: ${response.status}`)
        }

        const blob = await response.blob()
        const arrayBuffer = await blob.arrayBuffer()
        const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)))
        const mimeType = blob.type || 'application/octet-stream'
        const base64WithPrefix = `data:${mimeType};base64,${base64}`

        setBase64Content(base64WithPrefix)
      } catch (err) {
        console.error('Error converting blob to base64:', err)
        setError(err instanceof Error ? err.message : 'Unknown error')
        setBase64Content(null)
      } finally {
        setLoading(false)
      }
    }

    void convertToBase64()
  }, [content?.url])

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

  if (!base64Content) {
    return (
      <div className="box-border size-full flex justify-center">
        <div className="flex items-center bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400">
          No Content Found
        </div>
      </div>
    )
  }

  return (
    <LiteralBox content={base64Content}>
      <div className="w-full h-full p-4 text-sm font-mono bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100 overflow-auto">
        <div className="whitespace-pre-wrap break-all font-mono text-xs leading-relaxed">
          {base64Content}
        </div>
      </div>
    </LiteralBox>
  )
}

LiteralPane.displayName = 'ImageViewLiteralPane'
