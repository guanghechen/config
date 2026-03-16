import { IdFactory } from '@/feature/whiteboard/model'
import type {
  IComputeEvent,
  IComputeEventFrom,
  IComputeEventType,
  IComputePayload,
  IComputePayloadMap,
  IComputePriority,
} from './compute-event'
import { COMPUTE_EVENT_CATALOG } from './compute-event'

const PRIORITY_ORDER: ReadonlyArray<Exclude<IComputePriority, 'realtime'>> = [
  'high',
  'normal',
  'idle',
]

export interface IComputeDrainOptions {
  readonly budgetMs: number
}

export class ComputeEventQueue {
  private readonly realtimeByKey = new Map<string, IComputeEvent>()
  private readonly lanes: Record<
    Exclude<IComputePriority, 'realtime'>,
    Map<string, IComputeEvent>
  > = {
    high: new Map<string, IComputeEvent>(),
    normal: new Map<string, IComputeEvent>(),
    idle: new Map<string, IComputeEvent>(),
  }

  public createEvent<TType extends IComputeEventType>(input: {
    readonly type: TType
    readonly priority: IComputePriority
    readonly payload: IComputePayload<TType>
    readonly from: IComputeEventFrom
  }): IComputeEvent<TType> {
    const spec = COMPUTE_EVENT_CATALOG[input.type]
    const key = spec.key(input.payload, input.from)

    return {
      id: IdFactory.createEventId(),
      type: input.type,
      priority: input.priority,
      key,
      payload: input.payload,
      from: input.from,
      createdAt: Date.now(),
    }
  }

  public enqueue(event: IComputeEvent): void {
    if (event.priority === 'realtime') {
      this.realtimeByKey.set(event.key, event)
      return
    }

    const lane = this.lanes[event.priority]
    const spec = COMPUTE_EVENT_CATALOG[event.type]

    if (spec.coalesce === 'drop-others-and-run-once') {
      lane.clear()
      lane.set(event.key, event)
      return
    }

    if (spec.coalesce === 'merge-set' && lane.has(event.key)) {
      const previous = lane.get(event.key)
      if (!previous) {
        lane.set(event.key, event)
        return
      }

      lane.set(event.key, this.mergeSetEvent(previous, event))
      return
    }

    lane.set(event.key, event)
  }

  public drainRealtime(handler: (event: IComputeEvent) => void): void {
    for (const event of this.realtimeByKey.values()) {
      handler(event)
    }

    this.realtimeByKey.clear()
  }

  public drainPriority(
    handler: (event: IComputeEvent) => void,
    options: IComputeDrainOptions,
  ): void {
    const startAt = performance.now()

    for (const priority of PRIORITY_ORDER) {
      const lane = this.lanes[priority]
      const events = [...lane.values()]
      lane.clear()

      for (const event of events) {
        handler(event)

        if (performance.now() - startAt >= options.budgetMs) {
          return
        }
      }
    }
  }

  private mergeSetEvent(previous: IComputeEvent, next: IComputeEvent): IComputeEvent {
    if (previous.type !== 'REVALIDATE_SCOPE' || next.type !== 'REVALIDATE_SCOPE') {
      return next
    }

    const previousPayload = previous.payload as IComputePayloadMap['REVALIDATE_SCOPE']
    const nextPayload = next.payload as IComputePayloadMap['REVALIDATE_SCOPE']

    return {
      ...next,
      payload: {
        nodeIds: mergeArray(previousPayload.nodeIds, nextPayload.nodeIds),
        edgeIds: mergeArray(previousPayload.edgeIds, nextPayload.edgeIds),
        portIds: mergeArray(previousPayload.portIds, nextPayload.portIds),
        reason: nextPayload.reason,
      },
    }
  }
}

const mergeArray = (
  before: ReadonlyArray<string> | undefined,
  after: ReadonlyArray<string> | undefined,
): ReadonlyArray<string> | undefined => {
  const merged = new Set<string>([...(before ?? []), ...(after ?? [])])
  return merged.size > 0 ? [...merged] : undefined
}
