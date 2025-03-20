import React from 'react'
import { ThemeToggle } from './ThemeToggle'

export const TopbarView: React.FC = () => {
  return (
    <div className="relative flex items-center justify-center bg-[#dfdfdf] p-5 dark:bg-[#252525]">
      <div className="absolute right-7 flex items-center">
        <ThemeToggle />
      </div>
    </div>
  )
}
