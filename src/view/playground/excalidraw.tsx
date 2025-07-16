import { Excalidraw } from '@excalidraw/excalidraw'
import React from 'react'
import '@excalidraw/excalidraw/index.css'

const ExcalidrawPlayground: React.FC = () => {
  return (
    <div style={{ height: '100vh', width: '100vw' }}>
      <Excalidraw />
    </div>
  )
}

export default ExcalidrawPlayground
