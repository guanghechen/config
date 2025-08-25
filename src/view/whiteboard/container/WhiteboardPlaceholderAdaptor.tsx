import React from 'react'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly filetype: string
}

export const WhiteboardPlaceholderAdaptor: React.FC<IProps> = ({
  content,
  contentError,
  filetype,
}) => {
  if (contentError) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-red-500 dark:text-red-400">
        <div className="text-xl mb-2">⚠️</div>
        <div className="text-lg font-medium mb-1">Error</div>
        <div className="text-sm">{contentError}</div>
      </div>
    )
  }

  if (!content) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-gray-500 dark:text-gray-400">
        <div className="text-xl mb-2">📄</div>
        <div className="text-lg font-medium mb-1">No Content</div>
        <div className="text-sm">Use the Edit button to add {filetype} content</div>
      </div>
    )
  }

  return (
    <div className="flex flex-col items-center justify-center h-full text-gray-500 dark:text-gray-400">
      <div className="text-xl mb-2">🚧</div>
      <div className="text-lg font-medium mb-1">
        {filetype.charAt(0).toUpperCase() + filetype.slice(1)} Viewer
      </div>
      <div className="text-sm">This filetype is not fully supported in whiteboard mode yet</div>
      <div className="mt-4 p-4 bg-gray-100 dark:bg-gray-800 rounded-lg max-w-lg">
        <div className="text-sm font-medium mb-2">Content Preview:</div>
        <pre className="text-xs overflow-auto max-h-48 whitespace-pre-wrap break-words">
          {content}
        </pre>
      </div>
    </div>
  )
}
