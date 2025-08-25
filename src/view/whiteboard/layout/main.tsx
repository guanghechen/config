import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { WhiteboardMainContent } from '../container/WhiteboardMainContent'
import { useWhiteboardViewmodel } from '../context'

export const Main: React.FC = () => {
  const viewmodel = useWhiteboardViewmodel()
  const filetype = useStateValue(viewmodel.filetype$)
  const content = useStateValue(viewmodel.content$)
  const contentData = useStateValue(viewmodel.contentData$)

  return <WhiteboardMainContent filetype={filetype} content={content} contentData={contentData} />
}
