import React from 'react'
import { Composer } from './Composer'
import { PdfViewProvider } from './context'

interface IProps {
  readonly url: string | null
}

export class PdfView extends React.PureComponent<IProps> {
  public static readonly displayName = 'PdfView'

  private validateUrl(url: string | null): string | null {
    if (!url) return null

    const trimmedUrl = url.trim()
    if (trimmedUrl.length === 0) return null

    // Basic URL validation - check if it's a valid format
    if (
      trimmedUrl.startsWith('http://') ||
      trimmedUrl.startsWith('https://') ||
      trimmedUrl.startsWith('file://') ||
      trimmedUrl.startsWith('blob:') ||
      trimmedUrl.startsWith('/') ||
      trimmedUrl.startsWith('./') ||
      trimmedUrl.startsWith('../')
    ) {
      return trimmedUrl
    }

    return null
  }

  private renderError(): React.ReactElement {
    return (
      <div className="flex h-full w-full items-center justify-center">
        <div className="flex flex-col items-center justify-center rounded-lg border border-yellow-200 bg-yellow-50 p-8 text-center dark:border-yellow-800 dark:bg-yellow-900/20">
          <div className="mb-4 text-4xl">📄</div>
          <h3 className="mb-2 text-lg font-semibold text-yellow-800 dark:text-yellow-200">
            No PDF URL Provided
          </h3>
          <p className="text-sm text-yellow-700 dark:text-yellow-300">
            Please provide a valid PDF URL to view the document.
          </p>
        </div>
      </div>
    )
  }

  public override render(): React.ReactElement {
    const { url } = this.props
    const validatedUrl = this.validateUrl(url)

    if (!validatedUrl) {
      return this.renderError()
    }

    return (
      <PdfViewProvider url={validatedUrl}>
        <Composer />
      </PdfViewProvider>
    )
  }
}
