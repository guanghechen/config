import type { IGraphEdge, IGraphNode } from '../types'
import type { ILayoutAlgorithm, ILayoutConfig } from './types'

export class HierarchicalLayout implements ILayoutAlgorithm {
  private config: ILayoutConfig

  constructor(config?: Partial<ILayoutConfig>) {
    this.config = {
      nodeSpacing: 150,
      levelSpacing: 200,
      padding: 50,
      ...config,
    }
  }

  calculateLayout(nodes: IGraphNode[], edges: IGraphEdge[]): IGraphNode[] {
    if (nodes.length === 0) return []

    const children = this.buildChildrenMap(edges)
    const parents = this.buildParentsMap(edges)
    const rootNodes = this.findRootNodes(nodes, parents)
    const levels = this.assignLevels(rootNodes, children)

    return this.positionNodes(nodes, levels)
  }

  private buildChildrenMap(edges: IGraphEdge[]): Map<string, string[]> {
    const children = new Map<string, string[]>()

    edges.forEach(edge => {
      if (!children.has(edge.source)) {
        children.set(edge.source, [])
      }
      children.get(edge.source)!.push(edge.target)
    })

    return children
  }

  private buildParentsMap(edges: IGraphEdge[]): Map<string, string[]> {
    const parents = new Map<string, string[]>()

    edges.forEach(edge => {
      if (!parents.has(edge.target)) {
        parents.set(edge.target, [])
      }
      parents.get(edge.target)!.push(edge.source)
    })

    return parents
  }

  private findRootNodes(nodes: IGraphNode[], parents: Map<string, string[]>): IGraphNode[] {
    return nodes.filter(node => {
      const nodeParents = parents.get(node.id)
      return !nodeParents || nodeParents.length === 0
    })
  }

  private assignLevels(
    rootNodes: IGraphNode[],
    children: Map<string, string[]>,
  ): Map<string, number> {
    const levels = new Map<string, number>()
    const queue: Array<{ nodeId: string; level: number }> = []

    rootNodes.forEach(node => {
      levels.set(node.id, 0)
      queue.push({ nodeId: node.id, level: 0 })
    })

    while (queue.length > 0) {
      const { nodeId, level } = queue.shift()!
      const nodeChildren = children.get(nodeId) || []

      nodeChildren.forEach(childId => {
        const currentLevel = levels.get(childId) ?? -1
        const newLevel = level + 1

        if (newLevel > currentLevel) {
          levels.set(childId, newLevel)
          queue.push({ nodeId: childId, level: newLevel })
        }
      })
    }

    return levels
  }

  private positionNodes(nodes: IGraphNode[], levels: Map<string, number>): IGraphNode[] {
    const nodesByLevel = this.groupNodesByLevel(nodes, levels)
    const positionedNodes: IGraphNode[] = []

    nodesByLevel.forEach((levelNodes, level) => {
      const levelWidth = Math.max(0, (levelNodes.length - 1) * this.config.nodeSpacing)
      const startX = -levelWidth / 2

      levelNodes.forEach((node, index) => {
        const x = levelNodes.length === 1 ? 0 : startX + index * this.config.nodeSpacing
        const y = level * this.config.levelSpacing + this.config.padding

        positionedNodes.push({
          ...node,
          position: { x, y },
        })
      })
    })

    return positionedNodes
  }

  private groupNodesByLevel(
    nodes: IGraphNode[],
    levels: Map<string, number>,
  ): Map<number, IGraphNode[]> {
    const nodesByLevel = new Map<number, IGraphNode[]>()

    nodes.forEach(node => {
      const level = levels.get(node.id) ?? 0
      if (!nodesByLevel.has(level)) {
        nodesByLevel.set(level, [])
      }
      nodesByLevel.get(level)!.push(node)
    })

    return nodesByLevel
  }

  updateConfig(newConfig: Partial<ILayoutConfig>): void {
    this.config = { ...this.config, ...newConfig }
  }
}
