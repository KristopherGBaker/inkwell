module.exports = {
  darkMode: "class",
  content: [
    "./Sources/**/*.swift",
    "./themes/default/templates/**/*.html"
  ],
  theme: {
    extend: {
      fontFamily: {
        display: ["Fraunces", "serif"],
        sans: ["Manrope", "sans-serif"],
        mono: ["JetBrains Mono", "monospace"]
      }
    }
  },
  plugins: []
}
