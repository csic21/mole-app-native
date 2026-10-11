// 每个标签的"软件页面"还原:按官方各页版式重画,demo 文案与路径均为示意。
import type { ReactElement } from 'react'
import type { MockKind } from '../../data/site'

function Check({ on = true }: { on?: boolean }) {
  return <span className={`mk-check ${on ? 'is-on' : ''}`} aria-hidden="true" />
}

function AppIcon({ label, tone }: { label: string; tone: string }) {
  return (
    <span className="mk-appicon" style={{ background: tone }}>
      {label}
    </span>
  )
}

/* ------------------------------------------------- 清理:地球 + 总量 + 查看结果 */

function CleanPage() {
  return (
    <div className="mk-stage">
      <div className="mk-earth" aria-hidden="true" />
      <p className="mk-total">共 154.19 GB</p>
      <p className="mk-submeta">136 项 9 类 · 重新扫描</p>
      <span className="mk-pill">查看结果</span>
    </div>
  )
}

/* ------------------------------------------------- 优化:星体 + 诗句 + 优化 Mac */

function OptimizePage() {
  return (
    <div className="mk-stage">
      <div className="mk-moon" aria-hidden="true" />
      <p className="mk-verse">循理而行,分毫不乱</p>
      <span className="mk-pill">优化 Mac</span>
    </div>
  )
}

/* ------------------------------------------------- AI:分节清单 */

function AiPage() {
  const sessions = [
    { name: 'Codex 旧会话', badge: '已选 6/6', desc: '6 个会话超过 90 天未打开,主要来自 pake、kaku', extra: '90 天之前 ⌄', size: '5.24 GB' },
    { name: '已完成的 worktree', badge: '已选 1/1', desc: '中 1 个,改动均已合并到主分支', extra: '', size: '37.8 MB' },
    { name: '项目已删除的会话', badge: '已选 7/7', desc: '7 个会话,对应的项目文件夹已不存在', extra: '', size: '36.2 MB' },
  ]
  const idle = [
    { name: '闲置工具 A', desc: '70 天未使用,将连同会话和设置一并卸载', size: '244.3 MB' },
    { name: '闲置工具 B', desc: '70 天未使用,将连同会话和设置一并卸载', size: '188.7 MB' },
    { name: '闲置工具 C', desc: '70 天未使用,将连同会话和设置一并卸载', size: '104.9 MB' },
    { name: '另外 6 个长期未使用的工具', desc: 'Hermes Acent、Amo、Owen Code、GitHub Copilot CLI、Pi,连同各自的会话和设置', size: '393.2 MB' },
  ]
  return (
    <div className="mk-page">
      <div className="mk-head-row">
        <div>
          <h3 className="mk-title">AI 清理与维护</h3>
          <p className="mk-subtitle">Codex、Grok 等 14 个工具,共 35.58 GB</p>
        </div>
        <span className="mk-close" aria-hidden="true">
          ✕
        </span>
      </div>

      <p className="mk-section-title">
        缓存与旧版本 <span>28.06 GB</span>
        <em>删除后会自动重建</em>
      </p>
      <div className="mk-card">
        <div className="mk-row is-leaf">
          <Check />
          <div className="mk-stack">
            <span className="mk-name">
              缓存和临时文件 <u className="mk-badge">已选 5/5</u>
            </span>
            <span className="mk-desc">Claude、Codex、Cursor、Grok、Clang Module Cache 的缓存,需要时自动重建</span>
          </div>
          <span className="mk-size">28.06 GB ⌄</span>
        </div>
      </div>

      <p className="mk-section-title">
        会话与工作区 <span>6.32 GB</span>
        <em>删除后无法继续这些会话,需要逐项确认</em>
      </p>
      {sessions.map((row) => (
        <div className="mk-row is-leaf" key={row.name}>
          <Check />
          <div className="mk-stack">
            <span className="mk-name">
              {row.name} <u className="mk-badge">{row.badge}</u>
            </span>
            <span className="mk-desc">{row.desc}</span>
          </div>
          {row.extra ? <span className="mk-mini-chip">{row.extra}</span> : null}
          <span className="mk-size">{row.size} ⌄</span>
        </div>
      ))}

      <p className="mk-section-title">
        闲置工具与维护 <span>1.04 GB</span>
        <em>卸载时将一并删除其设置和登录信息</em>
      </p>
      {idle.map((row) => (
        <div className="mk-row is-leaf" key={row.name}>
          <Check on={false} />
          <div className="mk-stack">
            <span className="mk-name">{row.name}</span>
            <span className="mk-desc">{row.desc}</span>
          </div>
          <span className="mk-size">{row.size} ⌄</span>
        </div>
      ))}

      <div className="mk-foot">
        <span className="mk-foot-meta">已选 10 项</span>
        <span className="mk-pill">清理 · 34.41 GB</span>
      </div>
    </div>
  )
}

/* ------------------------------------------------- 软件:应用与残留 */

function AppsPage() {
  const installed = [
    { mark: 'S', tone: '#5b7bb3', name: 'Slack', meta: '4.42.0 · 421.8MB · 8 小时前 活跃' },
    { mark: 'F', tone: '#8a5bc0', name: 'Figma', meta: '124.6 · 336.2MB · 昨天 活跃' },
    { mark: 'V', tone: '#2f79c9', name: 'Visual Studio Code', meta: '1.139.1 · 913.4MB · 2 天前 活跃' },
  ]
  const leftovers = [
    { kind: 'App', path: '/Applications/Visual Studio Code.app', size: '913.4MB' },
    { kind: '临时缓存', path: '~/Library/Application Support/Code', size: '3.1MB' },
    { kind: 'HTTP 存储', path: '~/Library/HTTPStorages/com.microsoft.VSCode', size: '696KB' },
    { kind: '最近使用记录', path: '~/Library/Application Support/.../com.microsoft.vscode.sfl4', size: '9KB' },
    { kind: 'Electron 缓存', path: '~/Library/Application Support/Code/Cache', size: '0KB' },
  ]
  return (
    <div className="mk-page">
      <div className="mk-subnav">
        <span className="mk-tab is-active">卸载</span>
        <span className="mk-tab">更新</span>
        <span className="mk-tab">启动项</span>
        <span className="mk-subnav-meta">名称 · App 大小 · 最近使用 · 安装日期 ↓</span>
      </div>
      <p className="mk-caption">已安装 App 33 个 · 18.31GB</p>

      {installed.map((app) => (
        <div className="mk-row" key={app.name}>
          <AppIcon label={app.mark} tone={app.tone} />
          <span className="mk-name">{app.name}</span>
          <span className="mk-meta">{app.meta}</span>
          <span className="mk-size">移除</span>
          <Check on={false} />
        </div>
      ))}

      <div className="mk-expand">
        <div className="mk-row is-selected">
          <AppIcon label="V" tone="#2f79c9" />
          <span className="mk-name">Visual Studio Code</span>
          <span className="mk-meta">1.139.1 · 913.4MB · 2 天前 活跃</span>
          <span className="mk-state">移除 917.2MB · 另有 1.25GB 需确认</span>
          <Check />
        </div>
        <p className="mk-expand-head">清除</p>
        {leftovers.map((item) => (
          <div className="mk-row is-leaf" key={item.path}>
            <Check />
            <span className="mk-kind">{item.kind}</span>
            <span className="mk-path">{item.path}</span>
            <span className="mk-size">{item.size}</span>
          </div>
        ))}
      </div>

      <div className="mk-foot">
        <span className="mk-foot-meta">3 个 App · 3.61GB — 一并移除数据 · 取消选择</span>
        <span className="mk-pill">移除 3 项</span>
      </div>
    </div>
  )
}

/* ------------------------------------------------- 分析:侧栏 + 方块图 */

function AnalyzePage() {
  const dirs = [
    { name: 'Library', size: '130.9 GB' },
    { name: 'Parallels', size: '68.66 GB' },
    { name: 'www', size: '57.5 GB' },
    { name: '.tart', size: '54.74 GB' },
    { name: 'Downloads', size: '39.2 GB' },
    { name: '.codex', size: '26.32 GB' },
    { name: '.config', size: '23.11 GB' },
    { name: 'Documents', size: '10.39 GB' },
  ]
  const tiles = [
    { name: 'Library', size: '130.9 GB', span: 2, tone: '#5b4a42' },
    { name: 'www', size: '57.5 GB', span: 1, tone: '#8a4a34' },
    { name: '.tart', size: '54.74 GB', span: 1, tone: '#6b5a68' },
    { name: 'Parallels', size: '68.66 GB', span: 1, tone: '#8a6a3c' },
    { name: 'Downloads', size: '39.2 GB', span: 1, tone: '#6e5433' },
    { name: '.config', size: '23.11 GB', span: 1, tone: '#6b5a68' },
    { name: '.codex', size: '26.32 GB', span: 1, tone: '#5a5566' },
    { name: '136 项', size: '37.4 GB', span: 1, tone: '#5a5348' },
  ]
  return (
    <div className="mk-analyze">
      <aside className="mk-side">
        <div className="mk-jupiter" aria-hidden="true" />
        <p className="mk-side-total">147 项 · 438.45 GB</p>
        <p className="mk-side-label">当前目录</p>
        <div className="mk-side-list">
          {dirs.map((dir) => (
            <div className="mk-side-row" key={dir.name}>
              <span className="mk-name">{dir.name}</span>
              <span className="mk-size">{dir.size}</span>
              <span className="mk-chevron">›</span>
            </div>
          ))}
        </div>
        <p className="mk-side-note">右键可打开或移到废纸篓</p>
      </aside>
      <div className="mk-map-wrap">
        <div className="mk-map-head">
          <span className="mk-crumb">整个硬盘 › 用户</span>
          <span className="mk-map-legend">文件 438.45 GB · 已用 702 / 994 GB</span>
        </div>
        <div className="mk-treemap">
          {tiles.map((tile) => (
            <span
              key={tile.name}
              className={`mk-tile ${tile.span > 1 ? 'is-tall' : ''}`}
              style={{ background: tile.tone }}
            >
              <b>▸ {tile.name}</b>
              <i>{tile.size}</i>
            </span>
          ))}
        </div>
      </div>
    </div>
  )
}

/* ------------------------------------------------- 状态:指标卡 + 进程表 */

function StatusPage() {
  const procs = [
    { app: 'Parallels Desktop', mem: '14.3 GB', memPct: 88, cpu: '32.0', pid: '15980' },
    { app: 'Claude', mem: '4.2 GB', memPct: 32, cpu: '55.0', pid: '22350' },
    { app: 'ChatGPT', mem: '2.1 GB', memPct: 16, cpu: '7.7', pid: '74821' },
    { app: 'Cursor', mem: '2.0 GB', memPct: 15, cpu: '44.7', pid: '74509' },
    { app: '微信', mem: '1.2 GB', memPct: 9, cpu: '1.8', pid: '49392' },
  ]
  return (
    <div className="mk-status">
      <div className="mk-cards">
        <div className="mk-scard is-health">
          <div className="mk-scard-head">
            <span>✳ 健康度</span>
            <em>M4 Pro · 32GB · macOS 26</em>
          </div>
          <p className="mk-big is-warm">100 很好</p>
          <p className="mk-desc">各项指标正常</p>
          <p className="mk-desc is-dim">已运行 13 小时 · 自 9 月 27 日</p>
        </div>
        <div className="mk-scard">
          <div className="mk-scard-head">
            <span>▤ CPU</span>
            <em>46°C</em>
          </div>
          <p className="mk-big">12 %</p>
          <div className="mk-spark" aria-hidden="true" />
          <p className="mk-desc is-dim">低负载 · 负载 2.9 / 18 核</p>
        </div>
        <div className="mk-scard">
          <div className="mk-scard-head">
            <span>▤ GPU</span>
            <em>44°C</em>
          </div>
          <p className="mk-big">11 %</p>
          <div className="mk-spark is-line" aria-hidden="true" />
          <p className="mk-desc is-dim">低负载 · 20 GPU 核</p>
        </div>
        <div className="mk-scard">
          <div className="mk-scard-head">
            <span>▤ 内存</span>
            <em>压力 29%</em>
          </div>
          <p className="mk-big">70 %</p>
          <div className="mk-track">
            <span className="mk-fill" style={{ width: '70%' }} />
          </div>
          <p className="mk-desc is-dim">33.83 GB · 交换空间 4.3 MB</p>
        </div>
        <div className="mk-scard">
          <div className="mk-scard-head">
            <span>▮ 电池</span>
            <em>健康 100%</em>
          </div>
          <p className="mk-big is-warm">
            80 % <i>电源供电 · ×60W</i>
          </p>
          <p className="mk-desc is-dim">52 次循环</p>
        </div>
        <div className="mk-scard">
          <div className="mk-scard-head">
            <span>◔ 磁盘</span>
            <em>995 GB</em>
          </div>
          <p className="mk-big">292 GB</p>
          <div className="mk-track">
            <span className="mk-fill is-warm-fill" style={{ width: '71%' }} />
          </div>
          <p className="mk-desc is-dim">已用 703 GB · 71%</p>
        </div>
        <div className="mk-scard">
          <div className="mk-scard-head">
            <span>▷ 网络</span>
            <em>Wi-Fi</em>
          </div>
          <p className="mk-big">3 KB/s</p>
          <div className="mk-spark is-line" aria-hidden="true" />
          <p className="mk-desc is-dim">↑ 91 KB/s · Wi-Fi</p>
        </div>
        <div className="mk-scard">
          <div className="mk-scard-head">
            <span>❋ 风扇</span>
            <em>负载 0%</em>
          </div>
          <p className="mk-big">0 RPM</p>
          <div className="mk-seg">
            <span className="is-on">自动</span>
            <span>增强</span>
            <span>极冷</span>
          </div>
          <p className="mk-desc is-dim">由 macOS 调节</p>
        </div>
      </div>

      <div className="mk-table">
        <div className="mk-table-head">
          <span>名称（150）</span>
          <span>内存</span>
          <span>% CPU</span>
          <span>PID</span>
        </div>
        {procs.map((proc) => (
          <div className="mk-table-row" key={proc.app}>
            <span className="mk-name">{proc.app}</span>
            <span className="mk-mm">
              <span className="mk-size is-inline">{proc.mem}</span>
              <span className="mk-track is-mini">
                <span className="mk-fill is-neutral" style={{ width: `${proc.memPct}%` }} />
              </span>
            </span>
            <span className="mk-size">{proc.cpu}</span>
            <span className="mk-size is-dim">{proc.pid}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

const PAGES: Record<MockKind, () => ReactElement> = {
  clean: CleanPage,
  ai: AiPage,
  apps: AppsPage,
  optimize: OptimizePage,
  analyze: AnalyzePage,
  status: StatusPage,
}

export function MockPage({ kind }: { kind: MockKind }) {
  const Page = PAGES[kind]
  return <Page />
}
