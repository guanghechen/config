import React from 'react'
import { SvgView } from '@/view/filetype/svg/View'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
}

export const WhiteboardSvgAdaptor: React.FC<IProps> = ({ content, contentError }) => {
  return <SvgView content={content} contentError={contentError} />
}
