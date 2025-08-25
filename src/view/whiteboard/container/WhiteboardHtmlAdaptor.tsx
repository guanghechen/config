import React from 'react'
import { HtmlView } from '@/view/filetype/html/View'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
}

export const WhiteboardHtmlAdaptor: React.FC<IProps> = ({ content, contentError }) => {
  return <HtmlView content={content} contentError={contentError} />
}
