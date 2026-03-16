/* eslint-disable no-param-reassign */

import type { ICanvasGraph } from '@/feature/whiteboard/model'
import type {
  ICanvasPoint,
  IPickResult,
  IRenderFrame,
  IWhiteboardRenderer,
} from './IWhiteboardRenderer'

export class WebGLRendererStub implements IWhiteboardRenderer {
  private canvas: HTMLCanvasElement | null = null
  private context: CanvasRenderingContext2D | null = null
  private offscreenCanvas: HTMLCanvasElement | null = null
  private gl: WebGLRenderingContext | WebGL2RenderingContext | null = null
  private glProgram: WebGLProgram | null = null
  private glTexture: WebGLTexture | null = null
  private glPositionBuffer: WebGLBuffer | null = null
  private glTexCoordBuffer: WebGLBuffer | null = null
  private glPositionLocation = -1
  private glTexCoordLocation = -1
  private glSamplerLocation: WebGLUniformLocation | null = null
  private scene: ICanvasGraph | null = null
  private width = 0
  private height = 0
  private dpr = 1

  public attach(canvas: HTMLCanvasElement): void {
    this.canvas = canvas

    const webglContext =
      canvas.getContext('webgl2', {
        antialias: true,
        alpha: true,
      }) ??
      canvas.getContext('webgl', {
        antialias: true,
        alpha: true,
      })

    if (webglContext) {
      this.gl = webglContext
      this.initializeWebGLResources(webglContext)

      this.offscreenCanvas = document.createElement('canvas')
      this.context = this.offscreenCanvas.getContext('2d')
      return
    }

    this.context = canvas.getContext('2d')
  }

  public resize(width: number, height: number, dpr: number): void {
    if (!this.canvas || !this.context) return

    this.width = Math.max(1, width)
    this.height = Math.max(1, height)
    this.dpr = Math.max(1, dpr)

    const physicalWidth = Math.floor(this.width * this.dpr)
    const physicalHeight = Math.floor(this.height * this.dpr)

    this.canvas.width = physicalWidth
    this.canvas.height = physicalHeight
    this.canvas.style.width = `${this.width}px`
    this.canvas.style.height = `${this.height}px`

    if (this.offscreenCanvas) {
      this.offscreenCanvas.width = physicalWidth
      this.offscreenCanvas.height = physicalHeight
    }

    if (this.gl) {
      this.gl.viewport(0, 0, physicalWidth, physicalHeight)
    }

    this.context.setTransform(this.dpr, 0, 0, this.dpr, 0, 0)
  }

  public prepare(scene: ICanvasGraph): void {
    this.scene = scene
  }

  public render(frame: IRenderFrame): void {
    if (!this.context || !this.scene) return

    const context = this.context
    const viewport = this.scene.data.viewport

    context.clearRect(0, 0, this.width, this.height)
    context.fillStyle = '#f8fafc'
    context.fillRect(0, 0, this.width, this.height)

    this.drawGrid(context, viewport)
    this.drawEdges(context, frame.edgeValidationById)
    this.drawDraftEdge(context, frame.draftEdge)
    this.drawNodes(context, viewport, frame.selectedNodeIds, frame.nodeValidationById)
    this.drawSelectionBox(context, frame.selectionBox)

    this.compositeToWebGL()
  }

  public pick(point: ICanvasPoint): IPickResult | null {
    if (!this.scene) return null

    const viewport = this.scene.data.viewport
    const worldX = (point.x - viewport.offsetX) / viewport.zoom
    const worldY = (point.y - viewport.offsetY) / viewport.zoom
    const sortedNodes = Object.values(this.scene.data.nodesById).sort((a, b) => {
      if (a.zIndex !== b.zIndex) return b.zIndex - a.zIndex
      return b.nodeIndex - a.nodeIndex
    })

    for (const node of sortedNodes) {
      if (node.status.visibility === 'hidden') continue

      const portHit = this.pickPort(node.id, point.x, point.y)
      if (portHit) {
        return {
          hitType: 'port',
          hitId: portHit,
        }
      }

      if (
        worldX >= node.dimension.x &&
        worldX <= node.dimension.x + node.dimension.width &&
        worldY >= node.dimension.y &&
        worldY <= node.dimension.y + node.dimension.height
      ) {
        return {
          hitType: 'node',
          hitId: node.id,
        }
      }
    }

    return null
  }

  public dispose(): void {
    if (this.gl) {
      if (this.glPositionBuffer) {
        this.gl.deleteBuffer(this.glPositionBuffer)
      }
      if (this.glTexCoordBuffer) {
        this.gl.deleteBuffer(this.glTexCoordBuffer)
      }
      if (this.glTexture) {
        this.gl.deleteTexture(this.glTexture)
      }
      if (this.glProgram) {
        this.gl.deleteProgram(this.glProgram)
      }
    }

    this.scene = null
    this.context = null
    this.canvas = null
    this.offscreenCanvas = null
    this.gl = null
    this.glProgram = null
    this.glTexture = null
    this.glPositionBuffer = null
    this.glTexCoordBuffer = null
    this.glPositionLocation = -1
    this.glTexCoordLocation = -1
    this.glSamplerLocation = null
  }

  private initializeWebGLResources(gl: WebGLRenderingContext | WebGL2RenderingContext): void {
    const vertexShaderSource = `
      attribute vec2 a_position;
      attribute vec2 a_texCoord;
      varying vec2 v_texCoord;

      void main() {
        gl_Position = vec4(a_position, 0.0, 1.0);
        v_texCoord = a_texCoord;
      }
    `

    const fragmentShaderSource = `
      precision mediump float;
      varying vec2 v_texCoord;
      uniform sampler2D u_texture;

      void main() {
        gl_FragColor = texture2D(u_texture, v_texCoord);
      }
    `

    const vertexShader = this.compileShader(gl, gl.VERTEX_SHADER, vertexShaderSource)
    const fragmentShader = this.compileShader(gl, gl.FRAGMENT_SHADER, fragmentShaderSource)
    if (!vertexShader || !fragmentShader) {
      return
    }

    const program = gl.createProgram()
    if (!program) {
      gl.deleteShader(vertexShader)
      gl.deleteShader(fragmentShader)
      return
    }

    gl.attachShader(program, vertexShader)
    gl.attachShader(program, fragmentShader)
    gl.linkProgram(program)

    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      gl.deleteProgram(program)
      gl.deleteShader(vertexShader)
      gl.deleteShader(fragmentShader)
      return
    }

    gl.deleteShader(vertexShader)
    gl.deleteShader(fragmentShader)

    const texture = gl.createTexture()
    const positionBuffer = gl.createBuffer()
    const texCoordBuffer = gl.createBuffer()
    if (!texture || !positionBuffer || !texCoordBuffer) {
      if (texture) gl.deleteTexture(texture)
      if (positionBuffer) gl.deleteBuffer(positionBuffer)
      if (texCoordBuffer) gl.deleteBuffer(texCoordBuffer)
      gl.deleteProgram(program)
      return
    }

    this.glProgram = program
    this.glTexture = texture
    this.glPositionBuffer = positionBuffer
    this.glTexCoordBuffer = texCoordBuffer
    this.glPositionLocation = gl.getAttribLocation(program, 'a_position')
    this.glTexCoordLocation = gl.getAttribLocation(program, 'a_texCoord')
    this.glSamplerLocation = gl.getUniformLocation(program, 'u_texture')

    gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW)

    gl.bindBuffer(gl.ARRAY_BUFFER, texCoordBuffer)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 1, 1, 1, 0, 0, 1, 0]), gl.STATIC_DRAW)
  }

  private compileShader(
    gl: WebGLRenderingContext | WebGL2RenderingContext,
    type: number,
    source: string,
  ): WebGLShader | null {
    const shader = gl.createShader(type)
    if (!shader) return null

    gl.shaderSource(shader, source)
    gl.compileShader(shader)

    if (gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      return shader
    }

    gl.deleteShader(shader)
    return null
  }

  private compositeToWebGL(): void {
    if (
      !this.gl ||
      !this.offscreenCanvas ||
      !this.glProgram ||
      !this.glTexture ||
      !this.glPositionBuffer ||
      !this.glTexCoordBuffer ||
      this.glPositionLocation < 0 ||
      this.glTexCoordLocation < 0
    ) {
      return
    }

    const gl = this.gl
    gl.useProgram(this.glProgram)

    gl.activeTexture(gl.TEXTURE0)
    gl.bindTexture(gl.TEXTURE_2D, this.glTexture)
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 0)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, this.offscreenCanvas)
    if (this.glSamplerLocation) {
      gl.uniform1i(this.glSamplerLocation, 0)
    }

    gl.bindBuffer(gl.ARRAY_BUFFER, this.glPositionBuffer)
    gl.enableVertexAttribArray(this.glPositionLocation)
    gl.vertexAttribPointer(this.glPositionLocation, 2, gl.FLOAT, false, 0, 0)

    gl.bindBuffer(gl.ARRAY_BUFFER, this.glTexCoordBuffer)
    gl.enableVertexAttribArray(this.glTexCoordLocation)
    gl.vertexAttribPointer(this.glTexCoordLocation, 2, gl.FLOAT, false, 0, 0)

    gl.clearColor(0, 0, 0, 0)
    gl.clear(gl.COLOR_BUFFER_BIT)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
  }

  private drawGrid(
    context: CanvasRenderingContext2D,
    viewport: ICanvasGraph['data']['viewport'],
  ): void {
    if (!viewport.showGrid) return

    const spacing = viewport.gridSize * viewport.zoom
    if (spacing < 8) return

    context.save()
    context.strokeStyle = '#e2e8f0'
    context.lineWidth = 1

    const startX = ((viewport.offsetX % spacing) + spacing) % spacing
    const startY = ((viewport.offsetY % spacing) + spacing) % spacing

    for (let x = startX; x < this.width; x += spacing) {
      context.beginPath()
      context.moveTo(x, 0)
      context.lineTo(x, this.height)
      context.stroke()
    }

    for (let y = startY; y < this.height; y += spacing) {
      context.beginPath()
      context.moveTo(0, y)
      context.lineTo(this.width, y)
      context.stroke()
    }

    context.restore()
  }

  private drawNodes(
    context: CanvasRenderingContext2D,
    viewport: ICanvasGraph['data']['viewport'],
    selectedNodeIds: ReadonlyArray<string>,
    nodeValidationById: Readonly<Record<string, 'ok' | 'warn' | 'error'>>,
  ): void {
    const selected = new Set(selectedNodeIds)
    const nodes = Object.values(this.scene!.data.nodesById).sort((a, b) => {
      if (a.zIndex !== b.zIndex) return a.zIndex - b.zIndex
      return a.nodeIndex - b.nodeIndex
    })

    for (const node of nodes) {
      if (node.status.visibility === 'hidden') continue

      const screenX = node.dimension.x * viewport.zoom + viewport.offsetX
      const screenY = node.dimension.y * viewport.zoom + viewport.offsetY
      const width = node.dimension.width * viewport.zoom
      const height = node.dimension.height * viewport.zoom
      const radius = Math.min(node.style.cornerRadius * viewport.zoom, width * 0.5, height * 0.5)

      context.save()
      context.globalAlpha = node.style.opacity
      if (node.type === 'shape.ellipse') {
        this.drawEllipse(context, screenX, screenY, width, height)
      } else if (node.type === 'shape.diamond') {
        this.drawDiamond(context, screenX, screenY, width, height)
      } else {
        this.drawRoundedRect(context, screenX, screenY, width, height, radius)
      }
      context.fillStyle = node.style.fillColor
      context.fill()

      context.lineWidth = Math.max(1, node.style.strokeWidth * viewport.zoom)
      context.strokeStyle = node.style.strokeColor
      context.stroke()

      context.fillStyle = '#0f172a'
      context.font = `${Math.max(12, 12 * viewport.zoom)}px ui-monospace, SFMono-Regular, Menlo, monospace`

      const displayText = this.getNodeDisplayText(node)
      context.fillText(displayText, screenX + 10, screenY + Math.max(18, 18 * viewport.zoom))

      for (const portId of node.portIds) {
        const port = this.scene!.data.portsById[portId]
        if (!port) continue

        const point = this.getPortCanvasPoint(node.id, port.id)
        if (!point) continue

        context.beginPath()
        context.arc(point.x, point.y, Math.max(4, viewport.zoom * 4), 0, Math.PI * 2)
        context.fillStyle = port.direction === 'input' ? '#0ea5e9' : '#10b981'
        context.fill()
        context.strokeStyle = '#ffffff'
        context.lineWidth = 1.5
        context.stroke()
      }

      if (selected.has(node.id)) {
        context.lineWidth = 2
        context.strokeStyle = '#2563eb'
        this.drawRoundedRect(context, screenX - 3, screenY - 3, width + 6, height + 6, radius + 3)
        context.stroke()

        context.fillStyle = '#2563eb'
        const handleSize = 10
        context.fillRect(
          screenX + width - handleSize * 0.5,
          screenY + height - handleSize * 0.5,
          handleSize,
          handleSize,
        )
      }

      const validationLevel = nodeValidationById[node.id] ?? 'ok'
      if (validationLevel !== 'ok') {
        const badgeX = screenX + width - 8
        const badgeY = screenY + 8

        context.beginPath()
        context.arc(badgeX, badgeY, 7, 0, Math.PI * 2)
        context.fillStyle = validationLevel === 'error' ? '#dc2626' : '#f59e0b'
        context.fill()

        context.fillStyle = '#ffffff'
        context.font = 'bold 10px ui-monospace, SFMono-Regular, Menlo, monospace'
        context.textAlign = 'center'
        context.textBaseline = 'middle'
        context.fillText('!', badgeX, badgeY + 0.5)
      }

      context.restore()
    }
  }

  private drawEdges(
    context: CanvasRenderingContext2D,
    edgeValidationById: Readonly<Record<string, 'ok' | 'warn' | 'error'>>,
  ): void {
    const scene = this.scene
    if (!scene) return

    for (const edgeId of scene.data.edgeOrder) {
      const edge = scene.data.edgesById[edgeId]
      if (!edge) continue

      const fromPoint = this.getPortCanvasPoint(edge.from.nodeId, edge.from.portId)
      const toPoint = this.getPortCanvasPoint(edge.to.nodeId, edge.to.portId)
      if (!fromPoint || !toPoint) continue

      context.save()
      const edgeValidation = edgeValidationById[edge.id] ?? 'ok'
      context.strokeStyle =
        edgeValidation === 'error'
          ? '#dc2626'
          : edgeValidation === 'warn'
            ? '#f59e0b'
            : edge.style.strokeColor
      context.lineWidth = edge.style.strokeWidth

      context.beginPath()
      if (edge.routing === 'straight') {
        context.moveTo(fromPoint.x, fromPoint.y)
        context.lineTo(toPoint.x, toPoint.y)
      } else {
        const cp1x = fromPoint.x + 60
        const cp1y = fromPoint.y
        const cp2x = toPoint.x - 60
        const cp2y = toPoint.y
        context.moveTo(fromPoint.x, fromPoint.y)
        context.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, toPoint.x, toPoint.y)
      }
      context.stroke()

      if (edgeValidation !== 'ok') {
        const midX = (fromPoint.x + toPoint.x) * 0.5
        const midY = (fromPoint.y + toPoint.y) * 0.5

        context.beginPath()
        context.arc(midX, midY, 7, 0, Math.PI * 2)
        context.fillStyle = edgeValidation === 'error' ? '#dc2626' : '#f59e0b'
        context.fill()

        context.fillStyle = '#ffffff'
        context.font = 'bold 10px ui-monospace, SFMono-Regular, Menlo, monospace'
        context.textAlign = 'center'
        context.textBaseline = 'middle'
        context.fillText('!', midX, midY + 0.5)
      }

      context.restore()
    }
  }

  private drawDraftEdge(
    context: CanvasRenderingContext2D,
    draftEdge: IRenderFrame['draftEdge'],
  ): void {
    if (!draftEdge || !this.scene) return

    const fromPoint = this.findPortCanvasPointById(draftEdge.fromPortId)
    if (!fromPoint) return

    context.save()
    context.lineWidth = 2
    context.strokeStyle = draftEdge.valid ? '#16a34a' : '#dc2626'
    context.setLineDash([6, 4])
    context.beginPath()
    context.moveTo(fromPoint.x, fromPoint.y)
    context.lineTo(draftEdge.toX, draftEdge.toY)
    context.stroke()
    context.restore()
  }

  private drawSelectionBox(
    context: CanvasRenderingContext2D,
    selectionBox: IRenderFrame['selectionBox'],
  ): void {
    if (!selectionBox || selectionBox.width <= 0 || selectionBox.height <= 0) return

    context.save()
    context.fillStyle = 'rgba(37, 99, 235, 0.12)'
    context.strokeStyle = 'rgba(37, 99, 235, 0.9)'
    context.lineWidth = 1.5
    context.setLineDash([4, 3])
    context.fillRect(selectionBox.x, selectionBox.y, selectionBox.width, selectionBox.height)
    context.strokeRect(selectionBox.x, selectionBox.y, selectionBox.width, selectionBox.height)
    context.restore()
  }

  private drawRoundedRect(
    context: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
    radius: number,
  ): void {
    context.beginPath()
    context.moveTo(x + radius, y)
    context.lineTo(x + width - radius, y)
    context.quadraticCurveTo(x + width, y, x + width, y + radius)
    context.lineTo(x + width, y + height - radius)
    context.quadraticCurveTo(x + width, y + height, x + width - radius, y + height)
    context.lineTo(x + radius, y + height)
    context.quadraticCurveTo(x, y + height, x, y + height - radius)
    context.lineTo(x, y + radius)
    context.quadraticCurveTo(x, y, x + radius, y)
    context.closePath()
  }

  private drawEllipse(
    context: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
  ): void {
    context.beginPath()
    context.ellipse(x + width * 0.5, y + height * 0.5, width * 0.5, height * 0.5, 0, 0, Math.PI * 2)
    context.closePath()
  }

  private drawDiamond(
    context: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
  ): void {
    context.beginPath()
    context.moveTo(x + width * 0.5, y)
    context.lineTo(x + width, y + height * 0.5)
    context.lineTo(x + width * 0.5, y + height)
    context.lineTo(x, y + height * 0.5)
    context.closePath()
  }

  private getNodeDisplayText(node: ICanvasGraph['data']['nodesById'][string]): string {
    if (node.type === 'node.markdown') {
      const markdown = String(node.payload.markdown ?? '')
      return markdown.split('\n').find(line => line.trim().length > 0) ?? 'Markdown'
    }

    if (node.type === 'node.text') {
      const text = String(node.payload.text ?? 'Text')
      return text.length > 24 ? `${text.slice(0, 24)}...` : text
    }

    if (node.type === 'node.image') {
      const src = String(node.payload.src ?? 'image://pending')
      const filename = src.split('/').filter(Boolean).pop() ?? src
      return `Image: ${filename}`
    }

    return node.type
  }

  private pickPort(nodeId: string, canvasX: number, canvasY: number): string | null {
    const node = this.scene!.data.nodesById[nodeId]
    if (!node) return null

    const radius = Math.max(6, this.scene!.data.viewport.zoom * 5)
    for (const portId of node.portIds) {
      const point = this.getPortCanvasPoint(node.id, portId)
      if (!point) continue

      const dx = canvasX - point.x
      const dy = canvasY - point.y
      if (dx * dx + dy * dy <= radius * radius) {
        return portId
      }
    }

    return null
  }

  private getPortCanvasPoint(nodeId: string, portId: string): { x: number; y: number } | null {
    const node = this.scene!.data.nodesById[nodeId]
    const port = this.scene!.data.portsById[portId]
    if (!node || !port) return null

    const viewport = this.scene!.data.viewport
    const ratio = port.offsetRatio ?? 0.5
    const width = node.dimension.width
    const height = node.dimension.height

    let worldX = node.dimension.x + width * 0.5
    let worldY = node.dimension.y + height * 0.5

    if (port.placement === 'left') {
      worldX = node.dimension.x
      worldY = node.dimension.y + height * ratio
    } else if (port.placement === 'right') {
      worldX = node.dimension.x + width
      worldY = node.dimension.y + height * ratio
    } else if (port.placement === 'top') {
      worldX = node.dimension.x + width * ratio
      worldY = node.dimension.y
    } else if (port.placement === 'bottom') {
      worldX = node.dimension.x + width * ratio
      worldY = node.dimension.y + height
    } else if (port.placement === 'custom' && port.anchor) {
      worldX = node.dimension.x + width * port.anchor.xRatio
      worldY = node.dimension.y + height * port.anchor.yRatio
    }

    return {
      x: worldX * viewport.zoom + viewport.offsetX,
      y: worldY * viewport.zoom + viewport.offsetY,
    }
  }

  private findPortCanvasPointById(portId: string): { x: number; y: number } | null {
    if (!this.scene) return null

    const port = this.scene.data.portsById[portId]
    if (!port) return null

    return this.getPortCanvasPoint(port.nodeId, port.id)
  }
}
