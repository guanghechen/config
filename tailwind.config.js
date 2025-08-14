/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        mono: ['Maple Mono NF CN', 'Roboto Mono', 'monospace', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
