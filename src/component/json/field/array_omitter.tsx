import React from 'react'
import { ChevronDownIcon, ChevronRightIcon } from '../../icon/material'
import { classes } from '../constant'
import { JsonField } from '../Field'

interface IProps {
  readonly startIndex: number
  readonly endIndex: number
  readonly items: unknown[]
  readonly depth: number
  readonly forceCollapseTick: number
}

interface IState {
  readonly tick: number
}

export class FieldArrayOmitter extends React.Component<IProps, IState> {
  public static displayName = 'FieldArrayOmitter'

  protected collapsed: boolean
  protected forceTick: number

  constructor(props: IProps) {
    super(props)

    const { depth, forceCollapseTick } = props

    this.state = { tick: 0 }
    this.collapsed = forceCollapseTick > 0 ? forceCollapseTick % 2 === 0 : depth > 2
    this.forceTick = forceCollapseTick
  }

  public override render(): React.ReactElement {
    const { collapsed, onCollapse, onExpand } = this
    const { startIndex, endIndex, depth } = this.props
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }
    const count: number = endIndex - startIndex

    if (collapsed) {
      return (
        <div className={classes.container.line} style={indentStyle} onClick={onExpand}>
          <span className="align-middle">
            <ChevronRightIcon className="mr-1 inline-block h-6 w-4 cursor-pointer text-gray-500 hover:text-gray-700" />
          </span>
          <span className="italic text-gray-500">
            [{startIndex}..{endIndex - 1}] ({count} {count === 1 ? 'item' : 'items'})
          </span>
        </div>
      )
    }

    return (
      <div>
        <div className={classes.container.line} style={indentStyle} onClick={onCollapse}>
          <span className="align-middle">
            <ChevronDownIcon className="mr-1 inline-block h-6 w-4 cursor-pointer text-gray-500 hover:text-gray-700" />
          </span>
          <span className="italic text-gray-500">
            [{startIndex}..{endIndex - 1}] ({count} {count === 1 ? 'item' : 'items'})
          </span>
        </div>
        {this.renderItems()}
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps, nextState: IState): boolean {
    const props: IProps = this.props
    const state: IState = this.state

    if (
      props.forceCollapseTick !== nextProps.forceCollapseTick &&
      nextProps.forceCollapseTick > 0
    ) {
      this.collapsed = nextProps.forceCollapseTick % 2 === 0
      this.forceTick += 1
      if (this.forceTick % 2 !== nextProps.forceCollapseTick % 2) this.forceTick += 1
      return true
    }

    return (
      state.tick !== nextState.tick ||
      props.startIndex !== nextProps.startIndex ||
      props.endIndex !== nextProps.endIndex ||
      props.items !== nextProps.items ||
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

  protected renderItems(): React.ReactNode[] {
    const { startIndex, endIndex, items, depth, forceCollapseTick } = this.props
    const nodes: React.ReactNode[] = []

    for (let i = startIndex; i < endIndex; i++) {
      nodes.push(
        <JsonField
          key={i}
          name={i}
          value={items[i]}
          depth={depth + 1}
          forceCollapseTick={forceCollapseTick}
        />,
      )
    }

    return nodes
  }
}
