import { lazy, Suspense, useEffect, useState } from 'react'
import { Nav } from './components/Nav'
import { Hero } from './components/Hero'
import { FeatureViewer } from './components/FeatureViewer'
import { ToolPage } from './components/ToolPage'
import { Craft } from './components/Craft'
import { Footer } from './components/Footer'
import { ALL_BODIES } from './data/site'
import { useHashRoute } from './hooks/useHashRoute'

// Three.js 单独成 chunk:首屏排版先出现,3D 区块随后加载,避免首屏被大包阻塞。
const SolarSystem = lazy(() =>
  import('./components/solar/SolarSystem').then((module) => ({ default: module.SolarSystem })),
)

export default function App() {
  const [selected, setSelected] = useState('clean')
  const route = useHashRoute()
  const isTool = ALL_BODIES.some((body) => body.id === route)

  useEffect(() => {
    if (isTool) {
      window.scrollTo({ top: 0 })
      return
    }
    // 首页锚点(功能/太阳系/设计/关于):#/ 记法之外的纯锚点交给浏览器滚到位。
    const anchor = window.location.hash.replace(/^#/, '')
    if (!anchor || anchor.startsWith('/') || anchor.startsWith('feature-')) return
    const element = document.getElementById(anchor)
    if (element) requestAnimationFrame(() => element.scrollIntoView({ behavior: 'smooth' }))
  }, [route, isTool])

  return (
    <div className="page">
      <Nav />
      <main>
        <div className="route-view" key={isTool ? `tool-${route}` : 'home'}>
          {isTool ? (
            <ToolPage id={route} />
          ) : (
            <>
              <Hero />
              <FeatureViewer />
              <Suspense fallback={<div className="cosmos-hold" aria-hidden="true" />}>
                <SolarSystem selected={selected} onSelect={setSelected} />
              </Suspense>
              <Craft />
            </>
          )}
        </div>
      </main>
      <Footer />
    </div>
  )
}
