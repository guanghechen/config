import React from 'react'
import { ChevronDownIcon, ChevronRightIcon } from '../../icon/material'
import { classes } from '../constant'
import { JsonField } from '../Field'
import { JsonFieldCopyButton } from '../FieldCopyButton'
import { JsonFieldKey } from '../FieldKey'

interface IProps {
  readonly name: string | number | null
  readonly value: object
  readonly depth: number
}

interface IState {
  readonly collapsed: boolean
}

export class JsonFieldObject extends React.Component<IProps, IState> {
  public static displayName = 'JsonFieldObject'

  public entries: Array<[string, unknown]> = []

  constructor(props: IProps) {
    super(props)

    const state: IState = { collapsed: props.depth > 2 }
    this.state = state
    this.entries = Object.entries(props.value)
  }

  public override render(): React.ReactElement {
    const { entries, onCollapsedToggle } = this
    const { name, value, depth } = this.props
    const { collapsed } = this.state
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }

    if (entries.length === 0) {
      return (
        <div>
          <div className={classes.container.line} style={indentStyle}>
            <JsonFieldKey name={name} />
            <span className="font-medium text-gray-700">&#123;</span>
            <span className="font-medium text-gray-700">&#125;</span>
          </div>
        </div>
      )
    }

    if (collapsed) {
      return (
        <div>
          <div className={classes.container.line} style={indentStyle} onClick={onCollapsedToggle}>
            <span onClick={onCollapsedToggle} className="align-middle">
              <ChevronRightIcon className="mr-1 inline-block h-4 w-4 cursor-pointer text-gray-500 hover:text-gray-700" />
            </span>
            <JsonFieldKey name={name} />
            <span className="font-medium text-gray-700">&#123;</span>
            <span className="italic text-gray-500">
              {entries.length} {entries.length === 1 ? 'property' : 'properties'}
              <span className="ml-1 font-medium text-gray-700">&#125;</span>
            </span>
            <JsonFieldCopyButton value={value} />
          </div>
        </div>
      )
    }

    return (
      <div>
        <div className={classes.container.line} style={indentStyle} onClick={onCollapsedToggle}>
          <span onClick={onCollapsedToggle} className="align-middle">
            <ChevronDownIcon className="mr-1 inline-block h-4 w-4 cursor-pointer text-gray-500 hover:text-gray-700" />
          </span>
          <JsonFieldKey name={name} />
          <span className="font-medium text-gray-700">&#123;</span>
          <JsonFieldCopyButton value={value} />
        </div>
        {entries.map(([objKey, objVal]) => (
          <JsonField key={objKey} name={objKey} value={objVal} depth={depth + 1} />
        ))}
        <div
          className="flex cursor-pointer items-center rounded transition hover:bg-gray-200 dark:hover:bg-gray-700"
          style={indentStyle}
          onClick={onCollapsedToggle}
        >
          <span className="font-medium text-gray-700">&#125;</span>
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps, nextState: IState): boolean {
    const props: IProps = this.props
    const state: IState = this.state

    const changed: boolean =
      state.collapsed !== nextState.collapsed ||
      props.name !== nextProps.name ||
      props.value !== nextProps.value ||
      props.depth !== nextProps.depth

    if (changed) {
      this.entries = Object.entries(nextProps.value)
    }

    return changed
  }

  public onCollapsedToggle: React.MouseEventHandler = (evt: React.MouseEvent): void => {
    evt.stopPropagation()
    const state: IState = this.state
    this.setState({ collapsed: !state.collapsed })
  }
}
