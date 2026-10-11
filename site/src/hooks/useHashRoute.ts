import { useEffect, useState } from 'react'

// 极简 hash 路由:#/ 首页,#/clean、#/optimize… 每个工具一页。
// 不用 history API,静态托管(含 GitHub Pages)无需任何服务端配置。
export function parseRoute(hash: string): string {
  const match = hash.match(/^#\/([a-z-]*)/)
  return match?.[1] ?? ''
}

export function useHashRoute(): string {
  const [route, setRoute] = useState(() => parseRoute(window.location.hash))
  useEffect(() => {
    const onChange = () => setRoute(parseRoute(window.location.hash))
    window.addEventListener('hashchange', onChange)
    return () => window.removeEventListener('hashchange', onChange)
  }, [])
  return route
}
