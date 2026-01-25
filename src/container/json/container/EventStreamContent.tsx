import React from 'react'
import { ChevronDownIcon, ChevronRightIcon } from '@/common/component/icon/material'
import { Json } from '../'

interface ISSEEvent {
  readonly raw: string
  readonly type: 'data' | 'done' | 'comment' | 'other'
  readonly data: string | null
  readonly parsed: unknown | null
}

interface IProps {
  readonly value: unknown[]
  readonly depth: number
}

interface IState {
  readonly showRawEvents: boolean
}

export class EventStreamContent extends React.Component<IProps, IState> {
  public static displayName = 'EventStreamContent'

  constructor(props: IProps) {
    super(props)
    this.state = {
      showRawEvents: false,
    }
  }

  public override render(): React.ReactElement {
    const { depth } = this.props
    const { showRawEvents } = this.state
    const events = this.parseSSEEvents()
    const mergedContent = this.extractMergedContent(events)
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }

    return (
      <div className="flex flex-col gap-2 py-2">
        {mergedContent && (
          <div style={indentStyle}>
            <div className="text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">
              Merged Content
            </div>
            <div className="border border-emerald-500 dark:border-emerald-400 rounded p-3 bg-gray-50 dark:bg-gray-800">
              <pre className="text-sm text-gray-800 dark:text-gray-200 whitespace-pre-wrap break-words">
                {mergedContent}
              </pre>
            </div>
          </div>
        )}

        <div style={indentStyle}>
          <button
            className="flex items-center gap-1 text-xs font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 transition-colors"
            onClick={this.toggleRawEvents}
          >
            {showRawEvents ? (
              <ChevronDownIcon className="h-4 w-4" />
            ) : (
              <ChevronRightIcon className="h-4 w-4" />
            )}
            Raw Events ({events.length})
          </button>

          {showRawEvents && (
            <div className="mt-2 flex flex-col gap-1">
              {events.map((event, index) => (
                <div
                  key={index}
                  className="border border-gray-300 dark:border-gray-600 rounded p-2 bg-gray-50 dark:bg-gray-800"
                >
                  <div className="flex items-center gap-2 mb-1">
                    <span
                      className={`text-xs px-1.5 py-0.5 rounded ${this.getEventTypeBadgeClass(event.type)}`}
                    >
                      {event.type}
                    </span>
                    <span className="text-xs text-gray-400 dark:text-gray-500">#{index}</span>
                  </div>
                  {event.parsed ? (
                    <Json json={event.parsed} />
                  ) : (
                    <code className="text-xs text-gray-600 dark:text-gray-400 break-all">
                      {event.data || event.raw}
                    </code>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps, nextState: IState): boolean {
    const props: IProps = this.props
    const state: IState = this.state
    return (
      props.value !== nextProps.value ||
      props.depth !== nextProps.depth ||
      state.showRawEvents !== nextState.showRawEvents
    )
  }

  protected toggleRawEvents = (): void => {
    this.setState(prevState => ({ showRawEvents: !prevState.showRawEvents }))
  }

  protected getEventTypeBadgeClass(type: ISSEEvent['type']): string {
    switch (type) {
      case 'data':
        return 'bg-blue-100 dark:bg-blue-900/40 text-blue-700 dark:text-blue-300'
      case 'done':
        return 'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-300'
      case 'comment':
        return 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400'
      default:
        return 'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-300'
    }
  }

  protected parseSSEEvents(): ISSEEvent[] {
    const { value } = this.props
    const events: ISSEEvent[] = []

    for (const item of value) {
      if (typeof item !== 'string') continue

      const trimmed = item.trim()

      if (trimmed.startsWith('data:')) {
        const dataContent = trimmed.slice(5).trim()

        if (dataContent === '[DONE]') {
          events.push({
            raw: item,
            type: 'done',
            data: '[DONE]',
            parsed: null,
          })
        } else {
          let parsed: unknown | null = null
          try {
            parsed = JSON.parse(dataContent)
          } catch {
            // Not valid JSON
          }
          events.push({
            raw: item,
            type: 'data',
            data: dataContent,
            parsed,
          })
        }
      } else if (trimmed.startsWith(':')) {
        events.push({
          raw: item,
          type: 'comment',
          data: trimmed.slice(1).trim(),
          parsed: null,
        })
      } else {
        events.push({
          raw: item,
          type: 'other',
          data: trimmed,
          parsed: null,
        })
      }
    }

    return events
  }

  protected extractMergedContent(events: ISSEEvent[]): string | null {
    const contentParts: string[] = []

    for (const event of events) {
      if (event.type !== 'data' || !event.parsed) continue

      const content = this.extractDeltaContent(event.parsed)
      if (content) {
        contentParts.push(content)
      }
    }

    return contentParts.length > 0 ? contentParts.join('') : null
  }

  protected extractDeltaContent(obj: unknown): string | null {
    if (typeof obj !== 'object' || obj === null) return null

    const record = obj as Record<string, unknown>

    // OpenAI streaming format: choices[0].delta.content
    if (Array.isArray(record.choices) && record.choices.length > 0) {
      const choice = record.choices[0] as Record<string, unknown>
      if (choice && typeof choice === 'object') {
        const delta = choice.delta as Record<string, unknown>
        if (delta && typeof delta === 'object' && typeof delta.content === 'string') {
          return delta.content
        }
      }
    }

    // Anthropic streaming format: delta.text
    if (record.delta && typeof record.delta === 'object') {
      const delta = record.delta as Record<string, unknown>
      if (typeof delta.text === 'string') {
        return delta.text
      }
    }

    // Generic content field
    if (typeof record.content === 'string') {
      return record.content
    }

    // Generic text field
    if (typeof record.text === 'string') {
      return record.text
    }

    return null
  }
}

export function isSSEEventStream(value: unknown[]): boolean {
  if (value.length === 0) return false

  let sseCount = 0
  const checkCount = Math.min(value.length, 5)

  for (let i = 0; i < checkCount; i += 1) {
    const item = value[i]
    if (typeof item === 'string' && item.trim().startsWith('data:')) {
      sseCount += 1
    }
  }

  return sseCount >= Math.ceil(checkCount / 2)
}
