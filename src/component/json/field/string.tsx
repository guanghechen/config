import React from 'react'
import { ChevronDownIcon, ChevronUpIcon } from '../../icon/material'
import { classes } from '../constant'
import { JsonFieldCopyButton } from '../FieldCopyButton'
import { JsonFieldKey } from '../FieldKey'

interface IProps {
  readonly name: string | number | null
  readonly value: string
  readonly depth: number
}

interface IState {
  readonly expanded: boolean
  readonly isOverflowing: boolean
}

export class JsonFieldString extends React.Component<IProps, IState> {
  public static displayName = 'JsonFieldString'
  private textRef = React.createRef<HTMLSpanElement>()

  constructor(props: IProps) {
    super(props)
    this.state = {
      expanded: false,
      isOverflowing: false,
    }
  }

  public override render(): React.ReactElement {
    const { name, value, depth } = this.props
    const { expanded, isOverflowing } = this.state
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }

    return (
      <div className={classes.container.string} style={indentStyle}>
        <JsonFieldKey name={name} />
        <div className="flex flex-col">
          <span
            ref={this.textRef}
            className={`${expanded ? '' : 'line-clamp-6'} overflow-hidden text-emerald-600`}
          >
            "{value}"
          </span>
          {isOverflowing && (
            <button
              onClick={this.toggleExpand}
              className="mt-1 flex items-center gap-1 self-start rounded-full bg-emerald-50/80 px-2 py-0.5 text-xs text-emerald-600 transition-colors hover:bg-emerald-100 hover:text-emerald-700"
              aria-label={expanded ? 'Show less' : 'Show more'}
            >
              {expanded ? (
                <React.Fragment>
                  <ChevronUpIcon className="h-3.5 w-3.5" />
                  <span>Collapse</span>
                </React.Fragment>
              ) : (
                <React.Fragment>
                  <ChevronDownIcon className="h-3.5 w-3.5" />
                  <span>Expand</span>
                </React.Fragment>
              )}
            </button>
          )}
        </div>
        <JsonFieldCopyButton value={value} />
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps, nextState: IState): boolean {
    const props: IProps = this.props
    const state: IState = this.state
    return (
      props.name !== nextProps.name ||
      props.value !== nextProps.value ||
      props.depth !== nextProps.depth ||
      state.expanded !== nextState.expanded ||
      state.isOverflowing !== nextState.isOverflowing
    )
  }

  public override componentDidMount(): void {
    this.checkIfOverflowing()
  }

  public override componentDidUpdate(prevProps: IProps): void {
    if (prevProps.value !== this.props.value) {
      this.checkIfOverflowing()
    }
  }

  protected checkIfOverflowing = (): void => {
    const element = this.textRef.current
    if (element) {
      const isOverflowing = element.scrollHeight > element.clientHeight
      if (isOverflowing !== this.state.isOverflowing) {
        this.setState({ isOverflowing })
      }
    }
  }

  protected toggleExpand = (): void => {
    this.setState(prevState => ({ expanded: !prevState.expanded }))
  }
}
