import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// 本地开发从根路径服务;CI 构建 GitHub Pages 时用 PAGES_BASE 注入子路径。
export default defineConfig({
  base: process.env.PAGES_BASE ?? '/',
  plugins: [react()],
})
