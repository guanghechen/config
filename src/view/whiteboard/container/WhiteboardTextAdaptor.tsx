import React from 'react'
import { TextView } from '@/view/filetype/text/View'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
}

export const WhiteboardTextAdaptor: React.FC<IProps> = ({ content, contentError }) => {
  return <TextView content={content} contentError={contentError} />
}
