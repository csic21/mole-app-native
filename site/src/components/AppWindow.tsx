import type { ReactElement } from 'react'
import type { ToolId } from '../data/site'

// 与原生 App 的深色色板一致(Theme.swift dark),保证模拟绘制就是应用的样子。
const ICONS = {
  clean: 'M3 13h4l2 3h6l2-3h4M5 13l2-8h10l2 8v5a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2z',
  apps: 'M4 15h12a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-5M2 11h12a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v5a2 2 0 0 0 2 2z',
  optimize: 'M3 6h10M17 6h4M3 12h4M11 12h10M3 18h10M17 18h4M15 4v4M9 10v4M15 16v4',
  analyze: 'M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM8 13h8M8 16h5',
  status: 'M2 12h4l3-7 4 14 3-7h6',
  refresh: 'M20 12a8 8 0 1 1-2.3-5.6M20 4v4h-4',
  monitor: 'M3 5h18v11H3zM9 20h6M12 16v4',
  search: 'M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM16 16l5 5',
  chevron: 'M9 6l6 6-6 6',
  chevronDown: 'M6 9l6 6 6-6',
  back: 'M15 6l-6 6 6 6',
  info: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 11v5M12 8h.01',
  folder: 'M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
  finder: 'M3 5h18v14H3zM12 5v14M8 10h.01M16 10h.01',
} as const

export type IconName = keyof typeof ICONS

export function Icon({ name, size = 16 }: { name: IconName; size?: number }) {
  return (
    <svg className="icon" width={size} height={size} viewBox="0 0 24 24" fill="none"
      stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"
      aria-hidden="true">
      <path d={ICONS[name]} />
    </svg>
  )
}

function Check({ on }: { on: boolean }) {
  return (
    <span className={`app-check${on ? ' on' : ''}`} aria-hidden="true">
      {on && <svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="#1b2b22" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M2 6.5l2.7 2.7L10 3.8" /></svg>}
    </span>
  )
}

function Meter({ value }: { value: number }) {
  return <div className="app-meter" aria-hidden="true"><i style={{ width: `${value}%` }} /></div>
}

function Bars({ values }: { values: number[] }) {
  return (
    <div className="app-bars" aria-hidden="true">
      {values.map((v, i) => <i key={i} style={{ height: `${v}%` }} />)}
    </div>
  )
}

const barsA = [34, 42, 38, 52, 44, 36, 48, 40, 56, 43, 39, 46, 52, 38, 44, 41, 49, 45]
const barsB = [28, 36, 44, 38, 52, 46, 58, 42, 36, 48, 54, 40, 46, 52, 38, 44, 50, 42]
const barsC = [22, 30, 26, 38, 32, 28, 40, 34, 30, 42, 36, 32, 38, 28, 34, 40, 30, 36]

function CleanPanel() {
  const children = [
    { name: 'com.example.canvas', path: '~/Library/Caches/com.example.canvas', size: '1.56 GB' },
    { name: 'com.example.browser', path: '~/Library/Caches/com.example.browser', size: '800.0 MB' },
    { name: 'com.example.notes', path: '~/Library/Caches/com.example.notes', size: '300.0 MB' },
  ]
  return (
    <div className="app-panel app-clean">
      <div className="app-stepper">
        <span>扫描</span><i /><span className="current">查看并选择</span><i /><span>移到废纸篓</span>
      </div>
      <div className="app-toolbar">
        <span className="app-back"><Icon name="back" size={13} />扫描概览</span>
        <span className="app-link">全选 8 项</span>
        <span className="app-link">取消选择</span>
      </div>
      <p className="app-note"><Icon name="info" size={13} />只勾选你确认不再需要的内容。展开项目可查看完整路径。</p>
      <div className="app-rows">
        <div className="app-row group open">
          <Check on />
          <div className="app-row-main"><b>用户缓存</b><small>应用缓存，删除后会自动重建</small></div>
          <span className="app-row-size">2.64 GB</span>
          <Icon name="chevronDown" size={13} />
          <span className="app-row-count">3 项</span>
        </div>
        {children.map((c) => (
          <div className="app-row child picked" key={c.name}>
            <Check on />
            <div className="app-row-main"><b>{c.name}</b><small>{c.path}</small></div>
            <span className="app-row-size">{c.size}</span>
            <Icon name="info" size={13} />
          </div>
        ))}
        {[
          { title: '用户日志', note: '诊断与运行日志', size: '150.0 MB', count: '2 项' },
          { title: 'Xcode 构建缓存', note: 'DerivedData，重新构建即可恢复', size: '1.17 GB', count: '1 项' },
          { title: 'Xcode 设备支持', note: '设备符号，重新连接设备会恢复', size: '600.0 MB', count: '1 项' },
        ].map((c) => (
          <div className="app-row group" key={c.title}>
            <Check on={false} />
            <div className="app-row-main"><b>{c.title}</b><small>{c.note}</small></div>
            <span className="app-row-size">{c.size}</span>
            <Icon name="chevron" size={13} />
            <span className="app-row-count">{c.count}</span>
          </div>
        ))}
      </div>
      <div className="app-confirm">
        <div><b>已选 3 项 · 2.64 GB</b><small>移到废纸篓后可恢复；清空前仍占用磁盘空间</small></div>
        <span className="app-primary">移到废纸篓…</span>
      </div>
    </div>
  )
}

function AppsPanel() {
  const apps = [
    { name: 'Canvas', glyph: '✎', meta: '3.4.1 · 2026-10-10', size: '800.0 MB' },
    { name: 'Code Studio', glyph: '{ }', meta: '2.8.0 · 2026-10-10', size: '1.56 GB' },
    { name: 'Example Browser', glyph: '◎', meta: '128.0 · 2026-10-10', size: '700.0 MB' },
    { name: 'Notes', glyph: '▤', meta: '1.6.2 · 2026-10-10', size: '100.0 MB' },
  ]
  return (
    <div className="app-panel">
      <div className="app-toolbar">
        <div className="app-segment"><span className="current">应用清单</span><span>更新</span><span>启动项</span></div>
        <span className="app-meta">4 个应用 · 大小 4/4 已测量</span>
        <span className="app-primary quiet">重新扫描</span>
      </div>
      <div className="app-controls">
        <span className="app-search"><Icon name="search" size={13} />搜索应用名称或 Bundle ID</span>
        <span className="app-select">名称<Icon name="chevronDown" size={12} /></span>
        <span className="app-meta">4 / 4 个应用</span>
      </div>
      <p className="app-note"><Icon name="info" size={13} />展开应用可只读查看关联文件。此处不执行应用卸载。</p>
      <div className="app-rows">
        {apps.map((a) => (
          <div className="app-row app-item" key={a.name}>
            <span className="app-glyph" aria-hidden="true">{a.glyph}</span>
            <div className="app-row-main"><b>{a.name}</b></div>
            <span className="app-row-meta">{a.meta}</span>
            <span className="app-row-size">{a.size}</span>
            <Icon name="chevronDown" size={13} />
          </div>
        ))}
      </div>
    </div>
  )
}

function OptimizePanel() {
  const tasks = [
    { title: 'Quick Look 缩略图', note: '重建缩略图缓存，预览下次自动生成', state: '运行', kind: 'idle' },
    { title: 'DNS 缓存刷新', note: '刷新解析记录（会弹出系统授权）', state: '运行', kind: 'idle' },
    { title: 'Spotlight 索引检查', note: '只读检查索引状态，不做重建', state: '已完成', kind: 'done' },
    { title: '磁盘校验', note: '只读校验宗卷（可能耗时一两分钟）', state: '待运行', kind: 'idle' },
  ]
  return (
    <div className="app-panel">
      <div className="app-toolbar">
        <span className="app-meta">勾选后可一次运行，也可单独运行</span>
        <span className="app-meta">已完成 1 · 失败 0</span>
      </div>
      <p className="app-note"><Icon name="info" size={13} />需要管理员权限的步骤由系统向你询问；每一步都会留下记录。</p>
      <div className="app-rows">
        {tasks.map((t, i) => (
          <div className="app-row task" key={t.title}>
            <Check on={i !== 3} />
            <div className="app-row-main"><b>{t.title}</b><small>{t.note}</small></div>
            <span className={`app-pill ${t.kind}`}>{t.state}</span>
            <span className="app-link">记录</span>
          </div>
        ))}
      </div>
      <div className="app-confirm">
        <div><b>已选 3 项任务</b><small>完成、跳过与失败分别记录，随时可以重新运行</small></div>
        <span className="app-primary">运行所选</span>
      </div>
    </div>
  )
}

function AnalyzePanel() {
  const legend = [
    { name: 'Projects', size: '17.00 GB', share: '54.2%', color: '#9BCBB5' },
    { name: 'Design Library', size: '8.00 GB', share: '25.5%', color: '#8FA8C4' },
    { name: 'Downloads', size: '4.00 GB', share: '12.8%', color: '#EBC08F' },
    { name: 'Screen Recording.mov', size: '1.56 GB', share: '5.0%', color: '#C48F76' },
    { name: '.build', size: '800.0 MB', share: '2.5%', color: '#A98FC4' },
    { name: 'Project notes.pdf', size: '8.0 MB', share: '0.0%', color: '#7FC4B4' },
  ]
  return (
    <div className="app-panel">
      <div className="app-folder">
        <span className="app-folder-icon"><Icon name="folder" size={22} /></span>
        <div className="app-row-main"><b>Workspace</b><small>~/Workspace</small></div>
        <div className="app-folder-size"><b>31.35 GB</b><small>6 项 · 已测分配大小</small></div>
        <span className="app-primary quiet">重新测量</span>
        <span className="app-primary quiet">选择文件夹…</span>
      </div>
      <div className="app-toolbar">
        <span className="app-back"><Icon name="back" size={13} />～ › Workspace</span>
        <span className="app-link"><Icon name="finder" size={13} />访达</span>
      </div>
      <div className="app-distribution">
        <div className="app-toolbar"><b>空间分布</b><span className="app-meta">以当前文件夹全部已测大小为基准</span></div>
        <div className="app-stack" aria-hidden="true">
          {legend.map((l) => <i key={l.name} style={{ width: l.share, background: l.color }} />)}
        </div>
        <div className="app-legend">
          {legend.map((l) => (
            <span key={l.name}><i style={{ background: l.color }} />{l.name}
              <em>{l.size}</em><em>{l.share}</em></span>
          ))}
        </div>
      </div>
      <div className="app-cards">
        {legend.slice(0, 4).map((l) => (
          <div className="app-card" key={l.name}>
            <div className="app-toolbar"><b>{l.name}</b><span className="app-meta">{l.share}</span></div>
            <span className="app-card-size">{l.size}</span>
            <Meter value={parseFloat(l.share)} />
          </div>
        ))}
      </div>
    </div>
  )
}

function StatusPanel() {
  return (
    <div className="app-panel">
      <div className="app-toolbar">
        <div className="app-row-main"><b>Qili Preview Mac</b><small>Apple M3 Pro · 36 GB 内存 · macOS 15.0</small></div>
        <span className="app-meta"><Icon name="refresh" size={13} />采样已暂停</span>
      </div>
      <div className="app-grid">
        <div className="app-card">
          <div className="app-toolbar"><b>运行概况</b><span className="app-meta">占用估算</span></div>
          <h4>负载平稳</h4>
          <p className="app-meta">基于 CPU、内存与磁盘占用<br />不代表硬件健康</p>
          <p className="app-meta">已运行 2 天 4 小时 · 自 10 月 9 日</p>
        </div>
        <div className="app-card">
          <div className="app-toolbar"><b>CPU</b><span className="app-meta">43 ℃</span></div>
          <h4>24 %</h4>
          <Bars values={barsA} />
          <p className="app-meta">12 核 · 每 1.5 秒更新</p>
        </div>
        <div className="app-card">
          <div className="app-toolbar"><b>内存</b><span className="app-meta">占用估算</span></div>
          <h4>56 %</h4>
          <Meter value={56} />
          <p className="app-meta">已用 20.3 GB · 交换 512 MB</p>
        </div>
        <div className="app-card">
          <div className="app-toolbar"><b>磁盘可用</b><span className="app-meta">根卷 /</span></div>
          <h4>388 GB</h4>
          <Meter value={61} />
          <p className="app-meta">612 GB · 61% 已用</p>
        </div>
        <div className="app-card">
          <div className="app-toolbar"><b>网络下载</b><span className="app-meta">全部非回环接口</span></div>
          <h4>2.2 MB/s</h4>
          <Bars values={barsB} />
          <p className="app-meta">上传 307 KB/s · 下载历史</p>
        </div>
        <div className="app-card">
          <div className="app-toolbar"><b>电池</b><span className="app-meta">电池供电</span></div>
          <h4>84 %</h4>
          <Meter value={84} />
          <Bars values={barsC} />
        </div>
      </div>
    </div>
  )
}

const PANELS: Record<ToolId, () => ReactElement> = {
  clean: CleanPanel,
  apps: AppsPanel,
  optimize: OptimizePanel,
  analyze: AnalyzePanel,
  status: StatusPanel,
}

const TITLES: Record<ToolId, [string, string]> = {
  clean: ['空间整理', '看清占用，再决定哪些可以离开。'],
  apps: ['应用管理', '应用、更新与启动项，集中打理。'],
  optimize: ['系统维护', '按需运行维护任务，每一步都有记录。'],
  analyze: ['文件地图', '沿着文件夹找出空间去了哪里。'],
  status: ['运行状态', '观察此刻的负载，让数字说明状态。'],
}

const NAV: { id: ToolId; label: string }[] = [
  { id: 'clean', label: '空间整理' },
  { id: 'apps', label: '应用管理' },
  { id: 'optimize', label: '系统维护' },
  { id: 'analyze', label: '文件地图' },
  { id: 'status', label: '运行状态' },
]

export default function AppWindow({ tool }: { tool: ToolId }) {
  const Panel = PANELS[tool]
  const [title, detail] = TITLES[tool]
  return (
    <div className="app-window" role="img" aria-label={`栖理${title}界面的模拟绘制：${detail}`}>
      <div className="app-titlebar"><i /><i /><i /></div>
      <div className="app-body">
        <nav className="app-sidebar" aria-hidden="true">
          <div className="app-brand">
            <img src={`${import.meta.env.BASE_URL}qili-logo.png`} width={40} height={40} alt="" />
            <span>栖理<small>Qili</small></span>
          </div>
          <p className="app-nav-label">我的 Mac</p>
          {NAV.map((item) => (
            <span key={item.id} className={`app-nav-item${item.id === tool ? ' current' : ''}`}>
              <Icon name={item.id} size={15} />{item.label}
            </span>
          ))}
          <span className="app-nav-foot"><Icon name="refresh" size={15} />检查更新</span>
          <p className="app-version">栖理 v0.6.0</p>
          <p className="app-motto">给文件留位置，给工作留余地。</p>
        </nav>
        <div className="app-main">
          <header className="app-header">
            <div><h3>{title}</h3><p>{detail}</p></div>
            <span className="app-meta"><Icon name="monitor" size={14} />本机工作台</span>
          </header>
          <Panel />
        </div>
      </div>
    </div>
  )
}
