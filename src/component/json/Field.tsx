import React from 'react'
import { JsonFieldArray } from './field/array'
import { JsonFieldBigint } from './field/bigint'
import { JsonFieldBoolean } from './field/boolean'
import { JsonFieldFunction } from './field/function'
import { JsonFieldNull } from './field/null'
import { JsonFieldNumber } from './field/number'
import { JsonFieldObject } from './field/object'
import { JsonFieldString } from './field/string'
import { JsonFieldSymbol } from './field/symbol'
import { JsonFieldUndefined } from './field/undefined'
import { JsonFieldUnknown } from './field/unknown'

interface IProps {
  readonly name: string | number | null
  readonly value: unknown
  readonly depth: number
}

export class JsonField extends React.Component<IProps> {
  public static displayName = 'JsonField'

  public override render(): React.ReactElement {
    const { name, value, depth } = this.props

    if (value === undefined) return <JsonFieldUndefined name={name} depth={depth} />
    if (value === null) return <JsonFieldNull name={name} depth={depth} />

    switch (typeof value) {
      case 'bigint':
        return <JsonFieldBigint name={name} value={value} depth={depth} />
      case 'boolean':
        return <JsonFieldBoolean name={name} value={value} depth={depth} />
      case 'function': {
        return <JsonFieldFunction name={name} value={value} depth={depth} />
      }
      case 'number':
        return <JsonFieldNumber name={name} value={value} depth={depth} />
      case 'object':
        return Array.isArray(value) ? (
          <JsonFieldArray name={name} value={value} depth={depth} />
        ) : (
          <JsonFieldObject name={name} value={value} depth={depth} />
        )
      case 'string':
        return <JsonFieldString name={name} value={value} depth={depth} />
      case 'symbol':
        return <JsonFieldSymbol name={name} value={value} depth={depth} />
      default:
        return <JsonFieldUnknown name={name} value={value} depth={depth} />
    }
  }

  public override shouldComponentUpdate(nextProps: IProps): boolean {
    const props: IProps = this.props
    return (
      props.name !== nextProps.name ||
      props.value !== nextProps.value ||
      props.depth !== nextProps.depth
    )
  }
}
