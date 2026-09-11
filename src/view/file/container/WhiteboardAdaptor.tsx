import React from 'react'
import { WhiteboardBoard } from '@/view/whiteboard/View'

export const WhiteboardAdaptor: React.FC<{ filepath: string }> = ({ filepath }) => (
  <WhiteboardBoard key={filepath} filepath={filepath} />
)
