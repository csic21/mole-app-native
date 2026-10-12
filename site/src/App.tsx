import { useState } from 'react'
import { DOWNLOAD_URL, LOGO_URL, PROJECT_URL, TOOLS, isToolId, type ToolId } from './data/site'
import { useHashRoute } from './hooks/useHashRoute'

function WorkspacePreview({ active, onSelect }: { active: ToolId; onSelect: (id: ToolId) => void }) {
  const tool = TOOLS.find((item) => item.id === active)!
  return (
    <figure className="workspace">
      <figcaption className="workspace-caption"><span>栖理工作台</span><span>真实界面截图 · 示例数据</span></figcaption>
      <div className="workspace-tabs" role="tablist" aria-label="预览工具">
        {TOOLS.map((item) => (
          <button key={item.id} id={`preview-tab-${item.id}`} type="button" role="tab"
            aria-selected={active === item.id} aria-controls="preview-panel"
            className={active === item.id ? 'selected' : ''}
            onClick={() => onSelect(item.id)}
            onKeyDown={(event) => {
              const keys = ['ArrowDown', 'ArrowUp', 'ArrowLeft', 'ArrowRight', 'Home', 'End']
              if (!keys.includes(event.key)) return
              event.preventDefault()
              const current = TOOLS.findIndex((entry) => entry.id === item.id)
              const forward = event.key === 'ArrowDown' || event.key === 'ArrowRight'
              const index = event.key === 'Home' ? 0 : event.key === 'End' ? TOOLS.length - 1
                : (current + (forward ? 1 : -1) + TOOLS.length) % TOOLS.length
              const next = TOOLS[index].id
              onSelect(next)
              document.getElementById(`preview-tab-${next}`)?.focus()
            }}
            tabIndex={active === item.id ? 0 : -1}>
            <span aria-hidden="true">{item.symbol}</span>{item.label}
          </button>
        ))}
      </div>
      <div className="workspace-shot" id="preview-panel" role="tabpanel"
        aria-labelledby={`preview-tab-${active}`} tabIndex={0}>
        <img src={`${import.meta.env.BASE_URL}screenshots/${active}.png`} width={1220} height={820}
          alt={`栖理「${tool.label}」的真实界面截图`} />
      </div>
    </figure>
  )
}

export default function App() {
  const route = useHashRoute()
  const [selected, setSelected] = useState<ToolId>('clean')
  const active = isToolId(route) ? route : selected
  const tool = TOOLS.find((item) => item.id === active)!
  const selectTool = (id: ToolId) => {
    setSelected(id)
    if (isToolId(route)) window.location.hash = `/${id}`
  }

  return (
    <>
      <a className="skip-link" href="#main">跳到内容</a>
      <header className="site-nav">
        <a className="brand" href="#/"><img src={LOGO_URL} width={44} height={44} alt="" /><span>栖理 <small>Qili</small></span></a>
        <nav aria-label="主导航"><a href="#features">五项工具</a><a href="#approach">工作方式</a><a href={PROJECT_URL} target="_blank" rel="noreferrer">源码</a></nav>
        <a className="button compact" href={DOWNLOAD_URL} target="_blank" rel="noreferrer">下载 Mac 版</a>
      </header>
      <main id="main">
        <section className="hero">
          <div className="hero-copy">
            <p className="product-kind"><span aria-hidden="true" />Mac 空间与维护工作台</p>
            <h1>让 Mac 的空间，<br />回到你手里。</h1>
            <p className="hero-description">整理散落的缓存，找到占用空间的文件，照看日常运行的状态。栖理把这些小事放在一个安静的工作台里。</p>
            <div className="hero-actions"><a className="button" href={DOWNLOAD_URL} target="_blank" rel="noreferrer">下载栖理</a><a className="text-link" href="#features">看看它能做什么</a></div>
            <p className="platform-note">macOS 14 及以上 · 开源开发中</p>
          </div>
          <WorkspacePreview active={active} onSelect={selectTool} />
        </section>
        <section className="features" id="features">
          <div className="section-heading"><h2>各有位置，<br />一起打理。</h2><p>五项工具，围绕你的文件和工作。<br />从查看开始，把决定留给你。</p></div>
          <div className="feature-layout">
            <div className="feature-menu" aria-label="功能详情">
              {TOOLS.map((item) => <button key={item.id} type="button" className={active === item.id ? 'active' : ''} aria-pressed={active === item.id} onClick={() => selectTool(item.id)}><span aria-hidden="true">{item.symbol}</span><span>{item.label}<small>{item.status}</small></span><span className="feature-indicator" aria-hidden="true">+</span></button>)}
            </div>
            <article className="feature-detail" aria-live="polite">
              <p className="detail-name">{tool.label}</p><h3>{tool.title}</h3><p>{tool.description}</p>
              <ul>{tool.points.map((point) => <li key={point}>{point}</li>)}</ul>
              <a className="text-link" href={`#/${tool.id}`}>此功能的分享链接</a>
            </article>
          </div>
        </section>
        <section className="approach" id="approach">
          <div className="section-heading"><h2>整理得清楚，<br />用得踏实。</h2><p>少一些自动决定，<br />多一些看得见的依据。</p></div>
          <div className="principles">
            <article><div className="principle-drawing shelves" aria-hidden="true"><i /><i /><i /></div><h3>先清点</h3><p>查看真实大小和路径，再判断哪些值得处理。浏览文件本身不会触发删除。</p></article>
            <article><div className="principle-drawing checklist" aria-hidden="true"><i /><i /><i /></div><h3>由你选择</h3><p>清理要经过勾选和确认。需要管理员权限的维护任务，由系统向你询问。</p></article>
            <article><div className="principle-drawing return-path" aria-hidden="true"><i /><i /></div><h3>留有退路</h3><p>清理项目移到废纸篓。维护任务逐项记录结果，完成与失败都能看见。</p></article>
          </div>
        </section>
        <section className="download-band"><div><h2>给文件留位置，给工作留余地。</h2><p>在你的 Mac 上，从一次空间清点开始。</p></div><a className="button" href={DOWNLOAD_URL} target="_blank" rel="noreferrer">前往下载</a></section>
      </main>
      <footer><div className="footer-brand"><img src={LOGO_URL} width={36} height={36} alt="" /><span>栖理 Qili</span></div><p>独立开发的 Mac 工具。© 2026 Karl</p><nav aria-label="项目链接"><a href={PROJECT_URL} target="_blank" rel="noreferrer">GitHub</a><a href={`${PROJECT_URL}/blob/main/LICENSE`} target="_blank" rel="noreferrer">MIT 许可证</a><a href={`${PROJECT_URL}/blob/main/docs/PROVENANCE.md`} target="_blank" rel="noreferrer">来源与许可说明</a></nav></footer>
    </>
  )
}
