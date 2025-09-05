import React from 'react'
import { Drawboard } from '@/component/drawboard'
import type { DrawboardElement } from '@/component/drawboard'

export const DrawboardTestPage: React.FC = () => {
  const handleSave = (elements: DrawboardElement[]): void => {
    console.log('Saving elements:', elements)
    // Save to localStorage for persistence
    localStorage.setItem('drawboard-elements', JSON.stringify(elements))
  }

  return (
    <div className="h-screen w-screen">
      <div className="flex h-full flex-col">
        <header className="bg-gray-800 px-4 py-2 text-white">
          <h1 className="text-lg font-semibold">Drawboard Drawing Tool</h1>
        </header>

        <main className="flex-1">
          <Drawboard className="h-full w-full" onSave={handleSave} />
        </main>
      </div>
    </div>
  )
}
