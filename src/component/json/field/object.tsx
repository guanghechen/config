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
  readonly forceCollapseTick: number
}

interface IState {
  readonly tick: number
}

export class JsonFieldObject extends React.Component<IProps, IState> {
  public static displayName = 'JsonFieldObject'

  protected entries: Array<[string, unknown]>
  protected collapsed: boolean
  protected forceTick: number

  constructor(props: IProps) {
    super(props)

    const { depth, forceCollapseTick } = props
    const state: IState = { tick: 0 }

    this.state = state
    this.collapsed = forceCollapseTick > 0 ? forceCollapseTick % 2 === 0 : depth > 2
    this.forceTick = forceCollapseTick
    this.entries = Object.entries(props.value)
  }

  public override render(): React.ReactElement {
    const { entries, collapsed, forceTick, onCollapse, onExpand } = this
    const { name, value, depth } = this.props
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
          <div className={classes.container.line} style={indentStyle} onClick={onExpand}>
            <span className="align-middle">
              <ChevronRightIcon className="mr-1 inline-block h-4 w-4 cursor-pointer text-gray-500 hover:text-gray-700" />
            </span>
            <JsonFieldKey name={name} />
            <span className="font-medium text-gray-700">&#123;</span>
            <span className="px-1 text-sm italic text-gray-400">
              {entries.length} {entries.length === 1 ? 'property' : 'properties'}
            </span>
            <span className="font-medium text-gray-700">&#125;</span>
            <JsonFieldCopyButton value={value} />
          </div>
        </div>
      )
    }

    return (
      <div>
        <div className={classes.container.line} style={indentStyle} onClick={onCollapse}>
          <span className="align-middle">
            <ChevronDownIcon className="mr-1 inline-block h-4 w-4 cursor-pointer text-gray-500 hover:text-gray-700" />
          </span>
          <JsonFieldKey name={name} />
          <span className="font-medium text-gray-700">&#123;</span>
          <span className="px-1 text-sm italic text-gray-400">
            {entries.length} {entries.length === 1 ? 'property' : 'properties'}
          </span>
          <span className="font-medium text-gray-700">&nbsp;</span>
          <JsonFieldCopyButton value={value} />
        </div>
        {entries.map(([objKey, objVal]) => (
          <JsonField
            key={objKey}
            name={objKey}
            value={objVal}
            depth={depth + 1}
            forceCollapseTick={forceTick}
          />
        ))}
        <div
          className="flex cursor-pointer items-center rounded transition hover:bg-gray-200 dark:hover:bg-gray-700"
          style={indentStyle}
          onClick={onCollapse}
        >
          <span className="font-medium text-gray-700">&#125;</span>
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps, nextState: IState): boolean {
    const props: IProps = this.props
    const state: IState = this.state

    let changed: boolean = false
    if (props.value !== nextProps.value) {
      changed = true
      this.entries = Object.entries(nextProps.value)
    }

    if (
      props.forceCollapseTick !== nextProps.forceCollapseTick &&
      nextProps.forceCollapseTick > 0
    ) {
      changed = true

      this.collapsed = nextProps.forceCollapseTick % 2 === 0
      this.forceTick += 1
      if (this.forceTick % 2 !== nextProps.forceCollapseTick % 2) this.forceTick += 1
    }

    return (
      changed ||
      state.tick !== nextState.tick ||
      props.name !== nextProps.name ||
      props.depth !== nextProps.depth
    )
  }

  protected onCollapse: React.MouseEventHandler = (evt: React.MouseEvent): void => {
    evt.stopPropagation()

    const state: IState = this.state
    this.collapsed = true

    if (evt.altKey) {
      this.forceTick += 1
      if (this.forceTick % 2 !== 0) this.forceTick += 1
    }

    this.setState({ tick: state.tick + 1 })
  }

  protected onExpand: React.MouseEventHandler = (evt: React.MouseEvent): void => {
    evt.stopPropagation()

    const state: IState = this.state
    this.collapsed = false

    if (evt.altKey) {
      this.forceTick += 1
      if (this.forceTick % 2 === 0) this.forceTick += 1
    }

    this.setState({ tick: state.tick + 1 })
  }
}
