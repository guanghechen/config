import { IdFactory } from '@/feature/whiteboard/model'
import type {
  ICanvasEdgeData,
  ICanvasEdgeRouting,
  IWhiteboardDocumentData,
} from '@/feature/whiteboard/model'
import type { ICommand } from '../types'

export interface IEdgeValidationIssue {
  readonly code: string
  readonly severity: 'error' | 'warn'
  readonly message: string
}

export interface IEdgeValidationResult {
  readonly issues: ReadonlyArray<IEdgeValidationIssue>
  readonly canCreate: boolean
}

export interface ICreateEdgeInput {
  readonly fromPortId: string
  readonly toPortId: string
  readonly routing?: ICanvasEdgeRouting
}

export interface IEdgeValidationOptions {
  readonly ignoreEdgeId?: string
}

const hasTypeIntersection = (
  emits: ReadonlyArray<string>,
  accepts: ReadonlyArray<string>,
): boolean => {
  if (emits.length === 0 || accepts.length === 0) return false
  const acceptSet = new Set(accepts)
  return emits.some(type => acceptSet.has(type))
}

const countConnections = (
  data: IWhiteboardDocumentData,
  portId: string,
  options: IEdgeValidationOptions,
): number => {
  let count = 0
  for (const edge of Object.values(data.graph.edgesById)) {
    if (options.ignoreEdgeId && edge.id === options.ignoreEdgeId) {
      continue
    }

    if (edge.from.portId === portId || edge.to.portId === portId) {
      count += 1
    }
  }
  return count
}

export const validateEdgeConnection = (
  data: IWhiteboardDocumentData,
  fromPortId: string,
  toPortId: string,
  options: IEdgeValidationOptions = {},
): IEdgeValidationResult => {
  const issues: IEdgeValidationIssue[] = []

  const fromPort = data.graph.portsById[fromPortId]
  const toPort = data.graph.portsById[toPortId]

  if (!fromPort || !toPort) {
    return {
      issues: [
        {
          code: 'CONNECT_PORT_NOT_FOUND',
          severity: 'error',
          message: 'Source or target port was not found',
        },
      ],
      canCreate: false,
    }
  }

  if (fromPortId === toPortId) {
    issues.push({
      code: 'CONNECT_SELF_LOOP_NOT_ALLOWED',
      severity: 'error',
      message: 'Cannot connect one port to itself',
    })
  }

  if (fromPort.nodeId === toPort.nodeId) {
    issues.push({
      code: 'CONNECT_SELF_NODE_NOT_ALLOWED',
      severity: 'error',
      message: 'Cannot connect ports on the same node',
    })
  }

  if (fromPort.direction === 'input') {
    issues.push({
      code: 'CONNECT_DIRECTION_NOT_ALLOWED',
      severity: 'error',
      message: 'Source port must emit output',
    })
  }

  if (toPort.direction === 'output') {
    issues.push({
      code: 'CONNECT_DIRECTION_NOT_ALLOWED',
      severity: 'error',
      message: 'Target port must accept input',
    })
  }

  if (!hasTypeIntersection(fromPort.emits, toPort.accepts)) {
    issues.push({
      code: 'CONNECT_TYPE_NOT_COMPATIBLE',
      severity: 'error',
      message: 'No compatible type intersection between emits and accepts',
    })
  }

  if (typeof toPort.maxConnections === 'number') {
    const current = countConnections(data, toPort.id, options)
    if (current >= toPort.maxConnections) {
      issues.push({
        code: 'CONNECT_TARGET_PORT_FULL',
        severity: 'error',
        message: 'Target port connection capacity is full',
      })
    }
  }

  if (typeof fromPort.maxConnections === 'number') {
    const current = countConnections(data, fromPort.id, options)
    if (current >= fromPort.maxConnections) {
      issues.push({
        code: 'CONNECT_SOURCE_PORT_FULL',
        severity: 'error',
        message: 'Source port connection capacity is full',
      })
    }
  }

  const duplicated = Object.values(data.graph.edgesById).some(edge => {
    if (options.ignoreEdgeId && edge.id === options.ignoreEdgeId) {
      return false
    }

    return edge.from.portId === fromPortId && edge.to.portId === toPortId
  })

  if (duplicated) {
    issues.push({
      code: 'CONNECT_DUPLICATED_EDGE',
      severity: 'warn',
      message: 'Duplicated edge already exists',
    })
  }

  const canCreate = issues.every(issue => issue.severity !== 'error')
  return { issues, canCreate }
}

export const createCreateEdgeCommand = (input: ICreateEdgeInput): ICommand => {
  return {
    type: 'CREATE_EDGE',
    label: 'Create edge',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      const result = validateEdgeConnection(data, input.fromPortId, input.toPortId)
      if (!result.canCreate) return data

      const fromPort = data.graph.portsById[input.fromPortId]
      const toPort = data.graph.portsById[input.toPortId]
      if (!fromPort || !toPort) return data

      const edgeId = IdFactory.createEdgeId()
      const now = Date.now()
      const edge: ICanvasEdgeData = {
        id: edgeId,
        from: {
          nodeId: fromPort.nodeId,
          portId: fromPort.id,
        },
        to: {
          nodeId: toPort.nodeId,
          portId: toPort.id,
        },
        routing: input.routing ?? 'bezier',
        style: {
          strokeColor: '#334155',
          strokeWidth: 2,
          strokeStyle: 'solid',
          startMarker: 'none',
          endMarker: 'arrow',
        },
        createdAt: now,
        updatedAt: now,
      }

      return {
        ...data,
        graph: {
          ...data.graph,
          edgesById: {
            ...data.graph.edgesById,
            [edge.id]: edge,
          },
          edgeOrder: [...data.graph.edgeOrder, edge.id],
        },
      }
    },
  }
}
