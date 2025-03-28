import React from 'react'
import { Link } from 'react-router-dom'

export const NotFoundView: React.FC = () => {
  return (
    <div className="relative box-border flex size-full items-center justify-center overflow-auto bg-gray-50 font-['Maple_Mono_NF_CN','Roboto_Mono',monospace,sans-serif] text-gray-800 shadow-md transition-colors duration-300 ease-in-out dark:bg-gray-900 dark:text-gray-200">
      <div className="flex flex-col items-center justify-center p-6 text-center">
        <h1 className="mb-4 text-9xl font-bold text-gray-300 dark:text-gray-700">404</h1>
        <div className="mb-8">
          <h2 className="mb-2 text-2xl font-medium">Page Not Found</h2>
          <p className="text-gray-600 dark:text-gray-400">
            The page you are looking for doesn't exist or has been moved.
          </p>
        </div>
        <div className="flex space-x-4">
          <Link
            to="/"
            className="flex items-center rounded-md bg-blue-600 px-5 py-2 text-white transition-colors duration-200 hover:bg-blue-700"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="mr-2"
            >
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
              <polyline points="9 22 9 12 15 12 15 22" />
            </svg>
            Return Home
          </Link>
          <button
            onClick={() => window.history.back()}
            className="flex items-center rounded-md border border-gray-300 px-5 py-2 text-gray-700 transition-colors duration-200 hover:bg-gray-100 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-800"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="mr-2"
            >
              <line x1="19" y1="12" x2="5" y2="12" />
              <polyline points="12 19 5 12 12 5" />
            </svg>
            Go Back
          </button>
        </div>
      </div>
    </div>
  )
}

NotFoundView.displayName = 'NotFoundView'
export default NotFoundView
