import type { IState } from '@guanghechen/react-viewmodel'
import { Computed, State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IDrawboardElement } from '../../types/elements'

export interface ILayer {
  readonly id: string
  readonly name: string
  readonly visible: boolean
  readonly opacity: number
  readonly zIndex: number
  readonly elements: IDrawboardElement[]
}

export interface ILayerConfig {
  readonly baseZIndex: number
  readonly increment: number
  readonly defaultLayerName: string
}

export const DEFAULT_LAYER_CONFIG: ILayerConfig = {
  baseZIndex: 10,
  increment: 1,
  defaultLayerName: 'layer1',
} as const

export type ILayerUpdateOptions = Partial<Omit<ILayer, 'id'>>

export interface ILayerManagerOptions {
  readonly config?: Partial<ILayerConfig>
  readonly initialLayers?: ILayer[]
  readonly initialActiveLayerId?: string
}

export interface ILayerManagerData {
  readonly layers: ILayer[]
  readonly activeLayerId: string
}

interface IProps {
  readonly config?: Partial<ILayerConfig>
  readonly initialLayers?: ILayer[]
  readonly initialActiveLayerId?: string
}

const createDefaultLayer = (config: ILayerConfig): ILayer => ({
  id: config.defaultLayerName,
  name: 'Layer 1',
  visible: true,
  opacity: 1,
  zIndex: config.baseZIndex,
  elements: [],
})

export class LayersViewModel extends ViewModel {
  public readonly baseZIndex$: IState<number>
  public readonly increment$: IState<number>
  public readonly defaultLayerName$: IState<string>
  public readonly layers$: IState<ILayer[]>
  public readonly activeLayerId$: IState<string>
  public readonly activeLayer$: Computed<ILayer | null>
  public readonly activeLayerElements$: Computed<IDrawboardElement[]>
  public readonly allElements$: Computed<IDrawboardElement[]>

  public static fromData(
    data: Partial<ILayerManagerData> | undefined,
    options?: ILayerManagerOptions,
  ): LayersViewModel {
    const { layers, activeLayerId }: ILayerManagerData = this.normalize(data, options)
    return new LayersViewModel({
      config: options?.config,
      initialLayers: layers,
      initialActiveLayerId: activeLayerId,
    })
  }

  public static normalize(
    data: Partial<ILayerManagerData> | undefined,
    options?: ILayerManagerOptions,
  ): ILayerManagerData {
    const config = { ...DEFAULT_LAYER_CONFIG, ...options?.config }
    const defaultLayer = createDefaultLayer(config)

    const layers = data?.layers && data.layers.length > 0 ? data.layers : [defaultLayer]
    const activeLayerId = data?.activeLayerId || layers[0]?.id || config.defaultLayerName

    return { layers, activeLayerId }
  }

  constructor(props: IProps = {}) {
    super()

    const { config, initialLayers, initialActiveLayerId } = props
    const finalConfig = { ...DEFAULT_LAYER_CONFIG, ...config }

    this.baseZIndex$ = new State<number>(finalConfig.baseZIndex)
    this.increment$ = new State<number>(finalConfig.increment)
    this.defaultLayerName$ = new State<string>(finalConfig.defaultLayerName)

    const defaultData = LayersViewModel.normalize(
      {
        layers: initialLayers,
        activeLayerId: initialActiveLayerId,
      },
      { config: finalConfig },
    )

    this.layers$ = new State<ILayer[]>(defaultData.layers)
    this.activeLayerId$ = new State<string>(defaultData.activeLayerId)

    this.activeLayer$ = Computed.fromObservables(
      [this.layers$, this.activeLayerId$],
      (values: any[]): ILayer | null => {
        const [layers, activeLayerId] = values as [ILayer[], string]
        return layers.find(layer => layer.id === activeLayerId) || null
      },
    )

    this.activeLayerElements$ = Computed.fromObservables(
      [this.activeLayer$],
      (values: any[]): IDrawboardElement[] => {
        const [activeLayer] = values as [ILayer | null]
        return activeLayer?.elements || []
      },
    )

    this.allElements$ = Computed.fromObservables(
      [this.layers$],
      (values: any[]): IDrawboardElement[] => {
        const [layers] = values as [ILayer[]]
        return layers
          .filter(layer => layer.visible)
          .sort((a, b) => a.zIndex - b.zIndex)
          .flatMap(layer => layer.elements)
      },
    )
  }

  public dump = (): ILayerManagerData => {
    const layers = this.layers$.getSnapshot()
    const activeLayerId = this.activeLayerId$.getSnapshot()
    return { layers, activeLayerId }
  }

  public load = (data: Partial<ILayerManagerData> | undefined): void => {
    const currentConfig = this.getConfig()
    const { layers, activeLayerId }: ILayerManagerData = LayersViewModel.normalize(data, {
      config: currentConfig,
    })
    this.layers$.next(layers)
    this.activeLayerId$.next(activeLayerId)
  }

  public setActiveLayer = (layerId: string): void => {
    const layers = this.layers$.getSnapshot()
    if (layers.some(layer => layer.id === layerId)) {
      this.activeLayerId$.next(layerId)
    }
  }

  public getActiveLayer = (): ILayer | null => {
    const layers = this.layers$.getSnapshot()
    const activeLayerId = this.activeLayerId$.getSnapshot()
    return layers.find(layer => layer.id === activeLayerId) || null
  }

  public getConfig = (): ILayerConfig => {
    return {
      baseZIndex: this.baseZIndex$.getSnapshot(),
      increment: this.increment$.getSnapshot(),
      defaultLayerName: this.defaultLayerName$.getSnapshot(),
    }
  }

  public addLayer = (name?: string, elements: IDrawboardElement[] = []): ILayer => {
    const layers = this.layers$.getSnapshot()
    const baseZIndex = this.baseZIndex$.getSnapshot()
    const increment = this.increment$.getSnapshot()
    const timestamp = Date.now()
    const newLayerId = `layer${timestamp}`

    const newLayer: ILayer = {
      id: newLayerId,
      name: name || `Layer ${layers.length + 1}`,
      visible: true,
      opacity: 1,
      zIndex: baseZIndex + layers.length * increment,
      elements,
    }

    this.layers$.next([...layers, newLayer])
    this.activeLayerId$.next(newLayerId)

    return newLayer
  }

  public deleteLayer = (layerId: string): boolean => {
    const layers = this.layers$.getSnapshot()
    const activeLayerId = this.activeLayerId$.getSnapshot()
    const defaultLayerName = this.defaultLayerName$.getSnapshot()

    if (layers.length <= 1) return false

    const layerIndex = layers.findIndex(layer => layer.id === layerId)
    if (layerIndex === -1) return false

    const updatedLayers = layers.filter(layer => layer.id !== layerId)

    let newActiveLayerId = activeLayerId
    if (activeLayerId === layerId) {
      const targetIndex = Math.min(layerIndex, updatedLayers.length - 1)
      newActiveLayerId = updatedLayers[targetIndex]?.id || defaultLayerName
    }

    this.layers$.next(updatedLayers)
    this.activeLayerId$.next(newActiveLayerId)

    return true
  }

  public updateLayer = (layerId: string, updates: ILayerUpdateOptions): boolean => {
    const layers = this.layers$.getSnapshot()
    const layerIndex = layers.findIndex(layer => layer.id === layerId)

    if (layerIndex === -1) return false

    const updatedLayers = layers.map(layer =>
      layer.id === layerId ? { ...layer, ...updates } : layer,
    )

    this.layers$.next(updatedLayers)
    return true
  }

  public updateLayerElements = (layerId: string, elements: IDrawboardElement[]): boolean => {
    return this.updateLayer(layerId, { elements })
  }

  public setActiveLayerElements = (elements: IDrawboardElement[]): void => {
    const activeLayerId = this.activeLayerId$.getSnapshot()
    this.updateLayerElements(activeLayerId, elements)
  }

  public addElementsToActiveLayer = (elements: IDrawboardElement[]): void => {
    const activeLayer = this.getActiveLayer()
    if (activeLayer) {
      const newElements = [...activeLayer.elements, ...elements]
      this.updateLayerElements(activeLayer.id, newElements)
    }
  }

  public removeElementsFromActiveLayer = (elementIds: string[]): void => {
    const activeLayer = this.getActiveLayer()
    if (activeLayer) {
      const newElements = activeLayer.elements.filter(el => !elementIds.includes(el.id))
      this.updateLayerElements(activeLayer.id, newElements)
    }
  }

  public reorderLayers = (fromIndex: number, toIndex: number): boolean => {
    const layers = this.layers$.getSnapshot()
    const baseZIndex = this.baseZIndex$.getSnapshot()
    const increment = this.increment$.getSnapshot()

    if (fromIndex < 0 || fromIndex >= layers.length || toIndex < 0 || toIndex >= layers.length) {
      return false
    }

    const newLayers = [...layers]
    const [movedLayer] = newLayers.splice(fromIndex, 1)
    newLayers.splice(toIndex, 0, movedLayer)

    const updatedLayers = newLayers.map((layer, index) => ({
      ...layer,
      zIndex: baseZIndex + index * increment,
    }))

    this.layers$.next(updatedLayers)
    return true
  }

  public duplicateLayer = (layerId: string, namePrefix?: string): ILayer | null => {
    const layers = this.layers$.getSnapshot()
    const baseZIndex = this.baseZIndex$.getSnapshot()
    const increment = this.increment$.getSnapshot()
    const layerToDuplicate = layers.find(layer => layer.id === layerId)

    if (!layerToDuplicate) return null

    const timestamp = Date.now()
    const newLayerId = `layer${timestamp}`
    const duplicatedLayer: ILayer = {
      ...layerToDuplicate,
      id: newLayerId,
      name: `${namePrefix || layerToDuplicate.name} Copy`,
      zIndex: baseZIndex + layers.length * increment,
      elements: structuredClone(layerToDuplicate.elements),
    }

    this.layers$.next([...layers, duplicatedLayer])
    this.activeLayerId$.next(newLayerId)

    return duplicatedLayer
  }

  public setLayerVisibility = (layerId: string, visible: boolean): boolean => {
    return this.updateLayer(layerId, { visible })
  }

  public setLayerOpacity = (layerId: string, opacity: number): boolean => {
    const clampedOpacity = Math.max(0, Math.min(1, opacity))
    return this.updateLayer(layerId, { opacity: clampedOpacity })
  }

  public setLayerName = (layerId: string, name: string): boolean => {
    return this.updateLayer(layerId, { name })
  }

  public getLayerById = (layerId: string): ILayer | null => {
    const layers = this.layers$.getSnapshot()
    return layers.find(layer => layer.id === layerId) || null
  }

  public getLayerIndex = (layerId: string): number => {
    const layers = this.layers$.getSnapshot()
    return layers.findIndex(layer => layer.id === layerId)
  }

  public getVisibleLayers = (): ILayer[] => {
    const layers = this.layers$.getSnapshot()
    return layers.filter(layer => layer.visible)
  }

  public getLayersByZIndex = (): ILayer[] => {
    const layers = this.layers$.getSnapshot()
    return [...layers].sort((a, b) => a.zIndex - b.zIndex)
  }
}
