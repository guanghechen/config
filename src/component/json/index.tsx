import React from 'react'
import { JsonField } from './Field'

interface IProps {
  readonly json: unknown
}

export const Json: React.FC<IProps> = props => {
  return (
    <div className="select-none">
      <JsonField name={null} value={props.json} depth={0} forceCollapseTick={0} />
    </div>
  )
}
Json.displayName = 'Json'
