import { useState } from 'react'
import { DOWNLOAD_URL, LOGO_URL, PROJECT_URL, TOOLS, isToolId, type ToolId } from './data/site'
import { useHashRoute } from './hooks/useHashRoute'

const SPACE_SAMPLE = [
  { name: '用户缓存', size: '2.4 GB', share: 70 },
  { name: '开发工具', size: '1.1 GB', share: 36 },
  { name: '用户日志', size: '128 MB', share: 8 },
]

function WorkspacePreview({ active, onSelect }: { active: ToolId; onSelect: (id: ToolId) => void }) {
  const tool = TOOLS.find((item) => item.id === active)!
  return (
    <div className="workspace" aria-label="栖理界面示意">
      <div className="workspace-caption"><span>栖理工作台</span><span>界面示意，数据为示例</span></div>
      <div className="workspace-body">
        <div className="workspace-sidebar">
          <div className="workspace-brand"><img src={LOGO_URL} width={42} height={42} alt="" /><span>栖理<small>Qili</small></span></div>
          <div className="workspace-tabs" role="tablist" aria-label="预览工具" aria-orientation="vertical">
            {TOOLS.map((item) => (
              <button key={item.id} id={`preview-tab-${item.id}`} type="button" role="tab"
                aria-selected={active === item.id} aria-controls="preview-panel"
                className={active === item.id ? 'selected' : ''}
                onClick={() => onSelect(item.id)}
                onKeyDown={(event) => {
                  if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) return
                  event.preventDefault()
                  const current = TOOLS.findIndex((entry) => entry.id === item.id)
                  const index = event.key === 'Home' ? 0 : event.key === 'End' ? TOOLS.length - 1
                    : (current + (event.key === 'ArrowDown' ? 1 : -1) + TOOLS.length) % TOOLS.length
                  const next = TOOLS[index].id
                  onSelect(next)
                  document.getElementById(`preview-tab-${next}`)?.focus()
                }}
                tabIndex={active === item.id ? 0 : -1}>
                <span aria-hidden="true">{item.symbol}</span>{item.label}
              </button>
            ))}
          </div>
          <p className="workspace-motto">给工作留余地。</p>
        </div>
        <div className="workspace-main" id="preview-panel" role="tabpanel" aria-labelledby={`preview-tab-${active}`} tabIndex={0}>
          <div className="workspace-heading"><h3>{tool.label}</h3><span>本机工作台</span></div>
          {active === 'clean' ? (
            <>
              <div className="space-summary"><div><p>可以整理的空间</p><strong>3.6 <span>GB</span></strong><small>分类查看，确认后再处理</small></div><div className="tray-mark" aria-hidden="true"><i /><i /><i /></div></div>
              <div className="space-rows">{SPACE_SAMPLE.map((row) => (
                <div className="space-row" key={row.name}><span>{row.name}</span><div className="space-track" aria-hidden="true"><i style={{ width: `${row.share}%` }} /></div><b>{row.size}</b></div>
              ))}</div>
              <p className="preview-note">确认后的清理项目会移到废纸篓。</p>
            </>
          ) : active === 'status' ? (
            <>
              <div className="metric-grid">{[{ label: 'CPU', value: '12%', bars: [16, 25, 20, 38, 24, 29, 18, 22] }, { label: '内存', value: '48%', bars: [35, 37, 38, 40, 39, 42, 43, 48] }].map((metric) => (
                <div className="metric" key={metric.label}><span>{metric.label}</span><strong>{metric.value}</strong><div className="sample-bars" aria-hidden="true">{metric.bars.map((height, index) => <i key={index} style={{ height: `${height}px` }} />)}</div></div>
              ))}</div>
              <div className="preview-list"><div><span>磁盘可用空间</span><b>186 GB</b></div><div><span>网络下载速率</span><b>1.2 MB/s</b></div><div><span>运行时间</span><b>3 天 6 小时</b></div></div>
            </>
          ) : (
            <>
              <div className="tool-summary"><span className="tool-symbol" aria-hidden="true">{tool.symbol}</span><h4>{tool.title}</h4><p>{tool.status}</p></div>
              <div className="preview-list">
                {(active === 'apps' ? ['应用清单', '更新检查', '用户启动项'] : active === 'optimize' ? ['Quick Look 缩略图', 'DNS 缓存', 'Spotlight 索引', '磁盘校验'] : ['文稿', '下载', '开发项目', '图片']).map((item) => (
                  <div key={item}><span>{item}</span><b>{active === 'optimize' ? '待运行' : active === 'apps' ? '查看' : '打开目录'}</b></div>
                ))}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
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
