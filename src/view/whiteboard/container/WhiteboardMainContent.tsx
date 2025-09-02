import React from 'react'
import { ExcalidrawView } from '@/view/filetype/excalidraw/View'
import { HtmlView } from '@/view/filetype/html/View'
import { JsonView } from '@/view/filetype/json/View'
import { SvgView } from '@/view/filetype/svg/View'
import { TextView } from '@/view/filetype/text/View'
import type { IWhiteboardContentData } from '../context/types'
import { WhiteboardMarkdownAdaptor } from './WhiteboardMarkdownAdaptor'

interface IWhiteboardMainContentProps {
  readonly filetype: string
  readonly content: string | null
  readonly contentData: IWhiteboardContentData
  readonly storageKeyScope: string
}

export const WhiteboardMainContent: React.FC<IWhiteboardMainContentProps> = ({
  filetype,
  content,
  contentData,
  storageKeyScope,
}) => {
  // If no content is available, show placeholder
  if (!content && !contentData.contentError) {
    return (
      <div
        className="vl-main flex flex-col items-center justify-center text-gray-500 dark:text-gray-400"
        style={{ height: 'calc(100vh - 3rem)' }}
      >
        <div className="text-xl mb-2">🎨</div>
        <div className="text-lg font-medium mb-1">Welcome to Whiteboard</div>
        <div className="text-sm">Use the Edit button to paste content or select a file</div>
      </div>
    )
  }

  // If there's an error, show it
  if (contentData.contentError) {
    return (
      <div
        className="vl-main flex flex-col items-center justify-center text-red-500 dark:text-red-400"
        style={{ height: 'calc(100vh - 3rem)' }}
      >
        <div className="text-xl mb-2">⚠️</div>
        <div className="text-lg font-medium mb-1">Error</div>
        <div className="text-sm">{contentData.contentError}</div>
      </div>
    )
  }

  // For JSON, add validation error if content exists but isn't valid JSON
  let finalContentError = contentData.contentError
  if (filetype === 'json' && content && !contentData.contentError) {
    try {
      JSON.parse(content)
    } catch (error) {
      console.error('Failed to parse JSON:', error)
      finalContentError = 'Failed to parse JSON content'
    }
  }

  // Render appropriate filetype view based on filetype
  switch (filetype) {
    case 'excalidraw':
      return (
        <ExcalidrawView
          content={content}
          contentError={finalContentError}
          storageKeyScope={storageKeyScope}
        />
      )
    case 'html':
      return (
        <HtmlView
          content={content}
          contentError={finalContentError}
          storageKeyScope={storageKeyScope}
        />
      )
    case 'json':
      return (
        <JsonView
          content={content}
          contentError={finalContentError}
          storageKeyScope={storageKeyScope}
        />
      )
    case 'markdown':
      return (
        <WhiteboardMarkdownAdaptor
          content={content}
          contentError={finalContentError}
          storageKeyScope={storageKeyScope}
        />
      )
    case 'svg':
      return (
        <SvgView
          content={content}
          contentError={finalContentError}
          storageKeyScope={storageKeyScope}
        />
      )
    case 'text':
      return (
        <TextView
          content={content}
          contentError={finalContentError}
          storageKeyScope={storageKeyScope}
        />
      )
    case 'image':
    default:
      return (
        <div
          className="flex flex-col items-center justify-center text-gray-500 dark:text-gray-400"
          style={{ height: 'calc(100vh - 3rem)' }}
        >
          <div className="text-xl mb-2">📄</div>
          <div className="text-lg font-medium mb-1">
            {filetype.charAt(0).toUpperCase() + filetype.slice(1)} Preview
          </div>
          <div className="text-sm">
            Filetype "{filetype}" is not yet fully supported in whiteboard mode
          </div>
          {content && (
            <div className="mt-4 p-4 bg-gray-100 dark:bg-gray-800 rounded-lg max-w-md text-xs">
              <div className="font-medium mb-2">Content Preview:</div>
              <div className="text-gray-600 dark:text-gray-300 whitespace-pre-wrap">
                {content.substring(0, 200)}
                {content.length > 200 && '...'}
              </div>
            </div>
          )}
        </div>
      )
  }
}
