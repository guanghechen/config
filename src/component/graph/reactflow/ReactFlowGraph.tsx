import {
  Background,
  Controls,
  MiniMap,
  type Node,
  type NodeTypes,
  ReactFlow,
  useEdgesState,
  useNodesState,
} from '@xyflow/react'
import React from 'react'
import '@xyflow/react/dist/style.css'
import type { ITextTransformedNode } from '@/shared/types'
import { CustomNode } from './component/CustomNode'
import { NodeDetailsPanel } from './component/NodeDetailsPanel'
import { ReactFlowToolbar } from './component/ReactFlowToolbar'
import { type IReactFlowNodeData, transformNodesToReactFlow } from './util/adaptor'
import { getLayoutedElements } from './util/layout'

interface IProps {
  readonly data: ITextTransformedNode[]
  readonly theme?: 'light' | 'dark'
}

const nodeTypes: NodeTypes = {
  custom: CustomNode,
}

export const ReactFlowGraph: React.FC<IProps> = props => {
  const { data, theme = 'light' } = props

  const [selectedNode, setSelectedNode] = React.useState<Node<IReactFlowNodeData> | null>(null)

  const initialData = React.useMemo(() => {
    const { nodes, edges } = transformNodesToReactFlow(data)
    return getLayoutedElements(nodes, edges)
  }, [data])

  const [nodes, setNodes, onNodesChange] = useNodesState(initialData.nodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialData.edges)

  // Update nodes with theme
  const themedNodes = React.useMemo(() => {
    return nodes.map(node => ({
      ...node,
      data: {
        ...node.data,
        theme,
      },
    }))
  }, [nodes, theme])

  const handleNodeClick = React.useCallback(
    (_event: React.MouseEvent, node: Node<IReactFlowNodeData>) => {
      setSelectedNode(node)
    },
    [],
  )

  const handlePaneClick = React.useCallback(() => {
    setSelectedNode(null)
  }, [])

  const handleReLayout = React.useCallback(() => {
    const { nodes: layoutedNodes, edges: layoutedEdges } = getLayoutedElements(nodes, edges)
    setNodes(layoutedNodes)
    setEdges(layoutedEdges)
  }, [nodes, edges, setNodes, setEdges])

  const handleCloseDetails = React.useCallback(() => {
    setSelectedNode(null)
  }, [])

  return (
    <div className="relative w-full h-full flex">
      <div className="flex-1 relative">
        <ReactFlow
          nodes={themedNodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onNodeClick={handleNodeClick}
          onPaneClick={handlePaneClick}
          nodeTypes={nodeTypes}
          fitView={true}
          attributionPosition="bottom-left"
          className={theme === 'dark' ? 'dark' : ''}
          style={{ width: '100%', height: '100%' }}
        >
          <Controls />
          <MiniMap
            nodeColor={theme === 'dark' ? '#374151' : '#f9fafb'}
            nodeStrokeColor={theme === 'dark' ? '#6b7280' : '#d1d5db'}
            className={theme === 'dark' ? 'bg-gray-800' : 'bg-gray-100'}
          />
          <Background
            variant="dots"
            gap={20}
            size={1}
            color={theme === 'dark' ? '#374151' : '#e5e7eb'}
          />
          <ReactFlowToolbar theme={theme} onReLayout={handleReLayout} />
        </ReactFlow>
      </div>

      {selectedNode && (
        <NodeDetailsPanel node={selectedNode} theme={theme} onClose={handleCloseDetails} />
      )}
    </div>
  )
}

ReactFlowGraph.displayName = 'ReactFlowGraph'
