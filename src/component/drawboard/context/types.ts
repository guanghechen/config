import type {
  ILayer,
  ILayerConfig,
  ILayerManagerOptions,
  ILayerUpdateOptions,
} from './viewmodel/layers'

export enum ToolMode {
  SELECT = 1,
  LASSO = 2,
  LINE = 4,
  RECTANGLE = 8,
  DIAMOND = 16,
  CIRCLE = 32,
  ARROW = 64,
  FREEDRAW = 128,
  TEXT = 256,
  IMAGE = 512,
  ERASER = 1024,
  FRAME = 2048,
  LASER = 4096,
  PAN = 8192,
}

// Re-export layer types for convenience
export type { ILayer, ILayerConfig, ILayerManagerOptions, ILayerUpdateOptions }
