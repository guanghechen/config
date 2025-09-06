import React from 'react'
import { Drawboard } from '@/component/drawboard'
import { DrawboardProvider } from '@/component/drawboard/context'

interface IProps {
  readonly code: string
}

export default function EmbedDrawboard({ code }: IProps): React.ReactElement | null {
  // Parse the drawboard data from the code block
  const drawboardData = React.useMemo(() => {
    try {
      return JSON.parse(code)
    } catch (error) {
      console.error('Failed to parse drawboard data:', error)
      return null
    }
  }, [code])

  if (!drawboardData) {
    return <div className="text-red-500 dark:text-red-400">Failed to parse drawboard data</div>
  }

  return (
    <div className="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
      <DrawboardProvider>
        <Drawboard />
      </DrawboardProvider>
    </div>
  )
}
