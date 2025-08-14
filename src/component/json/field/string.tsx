import React from 'react'
import { ChevronDownIcon, ChevronUpIcon, SnippetIcon } from '../../icon/material'
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
  readonly prettier: boolean
}

export class JsonFieldString extends React.Component<IProps, IState> {
  public static displayName = 'JsonFieldString'
  private textRef = React.createRef<HTMLElement | null>()

  constructor(props: IProps) {
    super(props)
    this.state = {
      expanded: false,
      isOverflowing: false,
      prettier: false,
    }
  }

  public override render(): React.ReactElement {
    const { name, value, depth } = this.props
    const { isOverflowing, prettier } = this.state
    const expanded: boolean = prettier || this.state.expanded
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }

    return (
      <div className={classes.container.string} style={indentStyle}>
        <JsonFieldKey name={name} />
        <div className="flex flex-col">
          {prettier ? (
            <pre
              ref={this.textRef as any}
              className={`${expanded ? '' : 'line-clamp-6'} overflow-hidden text-emerald-600 whitespace-pre-wrap`}
            >
              <code>"{value}"</code>
            </pre>
          ) : (
            <code
              ref={this.textRef}
              className={`${expanded ? '' : 'line-clamp-6'} overflow-hidden text-emerald-600`}
            >
              "{value.replace(/\n/g, '\\n')}"
            </code>
          )}
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
        <div className="flex gap-1">
          <button
            onClick={this.togglePrettier}
            className={`invisible rounded p-1 transition-colors group-hover:visible ${
              prettier
                ? 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200'
                : 'text-gray-400 hover:bg-gray-100 hover:text-gray-600'
            }`}
            aria-label={prettier ? 'Disable prettier' : 'Enable prettier'}
            title={prettier ? 'Show escaped characters' : 'Show formatted text'}
          >
            <SnippetIcon className="h-4 w-4" />
          </button>
          <JsonFieldCopyButton value={value} />
        </div>
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
      state.isOverflowing !== nextState.isOverflowing ||
      state.prettier !== nextState.prettier
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

  protected togglePrettier = (): void => {
    this.setState(prevState => ({ prettier: !prevState.prettier }))
  }
}
