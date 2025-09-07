import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useDrawboardContext } from '../../context'

const strokeColors = [
  '#000000',
  '#e03131',
  '#2f9e44',
  '#1971c2',
  '#f08c00',
  '#7c2d12',
  '#495057',
  '#e64980',
  '#0ca678',
  '#364fc7',
  '#fd7e14',
  '#a61e4d',
]

const backgroundColors = [
  'transparent',
  '#ffffff',
  '#ffe8e8',
  '#e7f5ff',
  '#fff3e0',
  '#f3e5f5',
  '#e8f5e8',
  '#fff8e1',
  '#fce4ec',
  '#e1f5fe',
  '#f9fbe7',
  '#fafafa',
]

const strokeWidths = [1, 2, 4, 8, 12]

export const PropertiesPanel: React.FC = () => {
  const { ui } = useDrawboardContext()
  const strokeColor = useStateValue(ui.strokeColor$)
  const fillColor = useStateValue(ui.fillColor$)
  const strokeWidth = useStateValue(ui.strokeWidth$)
  const roughness = useStateValue(ui.roughness$)
  const opacity = useStateValue(ui.opacity$)

  return (
    <div
      className="flex flex-col gap-4 rounded-lg bg-white p-4 shadow-lg"
      style={{ width: '240px' }}
    >
      <h3 className="text-sm font-semibold text-gray-800">Properties</h3>

      {/* Stroke Color */}
      <div>
        <label className="mb-2 block text-xs font-medium text-gray-600">Stroke Color</label>
        <div className="grid grid-cols-6 gap-2">
          {strokeColors.map(color => (
            <button
              key={color}
              onClick={() => ui.strokeColor$.next(color)}
              className={cn('h-8 w-8 rounded border-2 transition-all', {
                'border-blue-500 ring-2 ring-blue-200': strokeColor === color,
                'border-gray-300': strokeColor !== color,
              })}
              style={{ backgroundColor: color }}
              title={color}
            />
          ))}
        </div>
      </div>

      {/* Background Color */}
      <div>
        <label className="mb-2 block text-xs font-medium text-gray-600">Fill Color</label>
        <div className="grid grid-cols-6 gap-2">
          {backgroundColors.map(color => (
            <button
              key={color}
              onClick={() => ui.fillColor$.next(color)}
              className={cn('h-8 w-8 rounded border-2 transition-all', {
                'border-blue-500 ring-2 ring-blue-200': fillColor === color,
                'border-gray-300': fillColor !== color,
              })}
              style={{
                backgroundColor: color === 'transparent' ? '#ffffff' : color,
                opacity: color === 'transparent' ? 0.5 : 1,
              }}
              title={color}
            >
              {color === 'transparent' && (
                <div className="h-full w-full rounded bg-gradient-to-br from-transparent via-red-500 to-transparent opacity-50" />
              )}
            </button>
          ))}
        </div>
      </div>

      {/* Stroke Width */}
      <div>
        <label className="mb-2 block text-xs font-medium text-gray-600">Stroke Width</label>
        <div className="flex gap-2">
          {strokeWidths.map(width => (
            <button
              key={width}
              onClick={() => ui.strokeWidth$.next(width)}
              className={cn(
                'flex h-8 flex-1 items-center justify-center rounded border transition-all',
                {
                  'border-blue-500 bg-blue-50 text-blue-600': strokeWidth === width,
                  'border-gray-300 text-gray-600': strokeWidth !== width,
                },
              )}
            >
              <div
                className="rounded bg-current"
                style={{
                  width: Math.max(width * 2, 1),
                  height: Math.min(width, 4),
                }}
              />
            </button>
          ))}
        </div>
      </div>

      {/* Roughness */}
      <div>
        <label className="mb-2 block text-xs font-medium text-gray-600">
          Roughness: {roughness}
        </label>
        <input
          type="range"
          min="0"
          max="2"
          step="0.1"
          value={roughness}
          onChange={e => ui.roughness$.next(parseFloat(e.target.value))}
          className="w-full"
        />
        <div className="flex justify-between text-xs text-gray-500">
          <span>Smooth</span>
          <span>Rough</span>
        </div>
      </div>

      {/* Opacity */}
      <div>
        <label className="mb-2 block text-xs font-medium text-gray-600">
          Opacity: {Math.round(opacity * 100)}%
        </label>
        <input
          type="range"
          min="10"
          max="100"
          step="5"
          value={Math.round(opacity * 100)}
          onChange={e => ui.opacity$.next(parseInt(e.target.value) / 100)}
          className="w-full"
        />
        <div className="flex justify-between text-xs text-gray-500">
          <span>10%</span>
          <span>100%</span>
        </div>
      </div>
    </div>
  )
}
