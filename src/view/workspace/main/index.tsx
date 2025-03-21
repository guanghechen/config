import React from 'react'
import { MarkdownContainer } from './Markdown'

export const WorkspaceMain: React.FC = () => {
  return (
    <div className="flex justify-center py-4">
      <MarkdownContainer />
    </div>
  )
}

WorkspaceMain.displayName = 'WorkspaceMain'
export default WorkspaceMain
