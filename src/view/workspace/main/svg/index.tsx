import React from 'react'
import { SvgMain } from './main'
import { SvgTopbar } from './topbar'

export interface SvgContainerProps {
  readonly workspace: string | null
  readonly filepath: string | null
}

export const SvgContainer: React.FC<SvgContainerProps> = props => {
  const { filepath, workspace } = props
  const [scale, setScale] = React.useState<number>(1)
  const [rotation, setRotation] = React.useState<number>(0)
  const [position, setPosition] = React.useState<{ x: number; y: number }>({ x: 0, y: 0 })

  return (
    <div className="w-full p-8">
      <div className="h-[4rem] border-b border-gray-200 dark:border-gray-700">
        <SvgTopbar
          scale={scale}
          setPosition={setPosition}
          setRotation={setRotation}
          setScale={setScale}
        />
      </div>
      <div className="h-[calc(100vh-12rem)] select-none overflow-hidden bg-gray-100 dark:bg-gray-800">
        <SvgMain
          workspace={workspace}
          filepath={filepath}
          position={position}
          rotation={rotation}
          scale={scale}
          setPosition={setPosition}
          setScale={setScale}
        />
      </div>
    </div>
  )
}

SvgContainer.displayName = 'SvgContainer'
export default SvgContainer
