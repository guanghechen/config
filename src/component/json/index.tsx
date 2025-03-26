import React from 'react'
import { JsonField } from './Field'

interface IProps {
  readonly json: unknown
  readonly initialCollapsed?: 'collapsed' | 'expanded' | undefined
}

export const Json: React.FC<IProps> = props => {
  const { json, initialCollapsed } = props
  const [forceCollapseTick, setForceCollapseTick] = React.useState<number>(0)

  React.useEffect(() => {
    if (initialCollapsed !== 'collapsed' && initialCollapsed !== 'expanded') return
    const collapsed: boolean = initialCollapsed === 'collapsed'
    setForceCollapseTick((tick: number): number => {
      let nextTick: number = tick + 1
      if (nextTick % 2 === 0) nextTick += collapsed ? 0 : 1
      else nextTick += collapsed ? 1 : 0
      return nextTick
    })
  }, [initialCollapsed])

  return (
    <div className="select-none">
      <JsonField name={null} value={json} depth={0} forceCollapseTick={forceCollapseTick} />
    </div>
  )
}
Json.displayName = 'Json'
