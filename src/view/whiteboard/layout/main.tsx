import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { WhiteboardMainContent } from '../container/WhiteboardMainContent'
import { useWhiteboardViewmodel } from '../context'

const storageKeyScope = '#/view/whiteboard'

export const Main: React.FC = () => {
  const viewmodel = useWhiteboardViewmodel()
  const filetype = useStateValue(viewmodel.filetype$)
  const content = useStateValue(viewmodel.content$)
  const contentData = useStateValue(viewmodel.contentData$)
  const fsHandle = useStateValue(viewmodel.fsHandle$)

  const onSaveFile = React.useCallback(
    (newContent: string) => {
      // Update the viewmodel content
      viewmodel.updateContent(newContent)

      // If we have a valid file system handle, trigger an automatic save
      if (fsHandle?.handle) {
        viewmodel.saveToFile().catch(error => {
          console.error('Failed to auto-save to file:', error)
        })
      }
    },
    [viewmodel, fsHandle],
  )

  return (
    <WhiteboardMainContent
      filetype={filetype}
      content={content}
      contentData={contentData}
      storageKeyScope={storageKeyScope}
      onSaveFile={onSaveFile}
    />
  )
}
