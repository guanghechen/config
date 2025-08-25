import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { WhiteboardHtmlAdaptor } from '../container/WhiteboardHtmlAdaptor'
import { WhiteboardJsonAdaptor } from '../container/WhiteboardJsonAdaptor'
import { WhiteboardMarkdownAdaptor } from '../container/WhiteboardMarkdownAdaptor'
import { WhiteboardPlaceholderAdaptor } from '../container/WhiteboardPlaceholderAdaptor'
import { WhiteboardSvgAdaptor } from '../container/WhiteboardSvgAdaptor'
import { WhiteboardTextAdaptor } from '../container/WhiteboardTextAdaptor'
import { useWhiteboardViewmodel } from '../context'

export const Main: React.FC = () => {
  const viewmodel = useWhiteboardViewmodel()
  const filetype = useStateValue(viewmodel.filetype$)
  const content = useStateValue(viewmodel.content$)
  const contentData = useStateValue(viewmodel.contentData$)

  const renderContent = (): React.ReactElement => {
    // If no content is available, show placeholder
    if (!content && !contentData.contentError) {
      return (
        <div className="flex flex-col items-center justify-center h-full text-gray-500 dark:text-gray-400">
          <div className="text-xl mb-2">🎨</div>
          <div className="text-lg font-medium mb-1">Welcome to Whiteboard</div>
          <div className="text-sm">Use the Edit button to paste content or select a file</div>
        </div>
      )
    }

    // If there's an error, show it
    if (contentData.contentError) {
      return (
        <div className="flex flex-col items-center justify-center h-full text-red-500 dark:text-red-400">
          <div className="text-xl mb-2">⚠️</div>
          <div className="text-lg font-medium mb-1">Error</div>
          <div className="text-sm">{contentData.contentError}</div>
        </div>
      )
    }

    // Render appropriate adaptor based on filetype
    switch (filetype) {
      case 'html':
        return <WhiteboardHtmlAdaptor content={content} contentError={contentData.contentError} />
      case 'json':
        return <WhiteboardJsonAdaptor content={content} contentError={contentData.contentError} />
      case 'markdown':
        return (
          <WhiteboardMarkdownAdaptor content={content} contentError={contentData.contentError} />
        )
      case 'svg':
        return <WhiteboardSvgAdaptor content={content} contentError={contentData.contentError} />
      case 'text':
        return <WhiteboardTextAdaptor content={content} contentError={contentData.contentError} />
      case 'excalidraw':
      case 'pdf':
      case 'image':
      default:
        return (
          <WhiteboardPlaceholderAdaptor
            content={content}
            contentError={contentData.contentError}
            filetype={filetype}
          />
        )
    }
  }

  return <div className="flex-1 overflow-hidden">{renderContent()}</div>
}
