import React from 'react'
import { JsonView } from '@/view/filetype/json/View'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
}

export const WhiteboardJsonAdaptor: React.FC<IProps> = ({ content, contentError }) => {
  let finalContentError = contentError

  // Validate JSON content if present
  if (content && !contentError) {
    try {
      JSON.parse(content)
    } catch (error) {
      console.error('Failed to parse JSON:', error)
      finalContentError = 'Failed to parse JSON content'
    }
  }

  return <JsonView content={content} contentError={finalContentError} />
}
