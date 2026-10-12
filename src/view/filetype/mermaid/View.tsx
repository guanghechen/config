import { CodeType } from '@yozora/ast'
import React from 'react'
import { CodeRenderer } from '@/container/markdown/renderer/code'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly loading: boolean
}

export const MermaidView: React.FC<IProps> = ({ content, contentError, loading }) => {
  return (
    <div className="h-full w-full overflow-auto p-4" data-filetype="mermaid" aria-busy={loading}>
      {contentError ? (
        <p role="alert" className="whitespace-pre-wrap text-red-600 dark:text-red-400">
          {contentError}
        </p>
      ) : content === null ? (
        <p role="status">Loading Mermaid diagram…</p>
      ) : !content.trim() ? (
        <p role="status">This Mermaid file is empty.</p>
      ) : (
        <React.Suspense fallback={<p role="status">Loading Mermaid diagram…</p>}>
          <CodeRenderer type={CodeType} lang="mermaid" meta="live collapsed" value={content} />
        </React.Suspense>
      )}
    </div>
  )
}
MermaidView.displayName = 'MermaidView'
