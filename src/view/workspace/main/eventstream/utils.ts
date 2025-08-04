export interface IEventStreamEvent {
  id?: string
  event?: string
  data?: string
  retry?: number
}

export const parseEventStream = (content: string): IEventStreamEvent[] => {
  if (!content) return []

  const events: IEventStreamEvent[] = []
  const lines = content.split('\n')
  let currentEvent: IEventStreamEvent = {}

  for (const line of lines) {
    const trimmedLine = line.trim()

    if (trimmedLine === '') {
      if (Object.keys(currentEvent).length > 0) {
        events.push(currentEvent)
        currentEvent = {}
      }
      continue
    }

    if (trimmedLine.startsWith(':')) continue

    const colonIndex = trimmedLine.indexOf(':')
    if (colonIndex === -1) continue

    const field = trimmedLine.slice(0, colonIndex).trim()
    const value = trimmedLine.slice(colonIndex + 1).trim()

    switch (field) {
      case 'id':
        currentEvent.id = value
        break
      case 'event':
        currentEvent.event = value
        break
      case 'data':
        currentEvent.data = currentEvent.data ? `${currentEvent.data}\n${value}` : value
        break
      case 'retry':
        currentEvent.retry = parseInt(value, 10)
        break
    }
  }

  if (Object.keys(currentEvent).length > 0) {
    events.push(currentEvent)
  }

  return events
}

export const parseJsonData = (data: string): { parsed: unknown; isJson: boolean } => {
  try {
    return { parsed: JSON.parse(data), isJson: true }
  } catch {
    return { parsed: data, isJson: false }
  }
}
