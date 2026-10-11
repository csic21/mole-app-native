// 站点内容数据。文案为本仓库原创占位,未复制 mole.fit 的受版权文案。
export type TextureKind = 'earth' | 'moon' | 'mars' | 'mercury' | 'jupiter'

export type BodyDef = {
  id: string
  name: string
  role: string
  title: string
  blurb: string
  bullets: [string, string, string]
  poem: string
  verse: string
  ctaLabel: string
  ctaHref: string
  color: string
  ringColor: string
  size: number
  orbit: number
  phase: number
  orbitSpeed: number
  spin: number
  texture?: TextureKind
}

// 五颗行星,各自对应一件工具;太阳居中,对应状态。
export const PLANETS: BodyDef[] = [
  {
    id: 'clean',
    name: '地球',
    role: '清理',
    title: '先看后删,再动手',
    blurb: '缓存、日志与快照都在本机清点,动手之前先给你一份清单。',
    bullets: ['系统数据单独成组,排在最前', '每一项都可以勾选、跳过或保护', '扫描与清理全程在本机完成'],
    poem: '风过留痕,缓存归尘',
    verse: '尘落无声,天地自宽',
    ctaLabel: '清理 Mac',
    ctaHref: 'https://mole.fit/zh/mac-cleaner',
    color: '#4f7fa8',
    ringColor: '#7fa6c9',
    size: 0.5,
    orbit: 2.7,
    phase: 0.85,
    orbitSpeed: 0.1,
    spin: 0.35,
    texture: 'earth',
  },
  {
    id: 'ai',
    name: '月亮',
    role: 'AI',
    title: 'AI 工具的旧数据有了归宿',
    blurb: '旧会话、旧版本、闲置的命令行工具,确认之后再离开。',
    bullets: ['Claude Code、Codex、Cursor 的缓存与旧版本', '闲置会话与 worktree 逐条确认', '持久保留的目录可以先收进保护清单'],
    poem: '旧事归档,轻装上路',
    verse: '旧事归月,轻装前行',
    ctaLabel: '整理 AI 数据',
    ctaHref: 'https://mole.fit/zh/mac-cleaner#ai-data',
    color: '#b6b0a2',
    ringColor: '#cfc9ba',
    size: 0.34,
    orbit: 3.5,
    phase: 5.2,
    orbitSpeed: 0.16,
    spin: 0.3,
    texture: 'moon',
  },
  {
    id: 'apps',
    name: '火星',
    role: '软件',
    title: '卸载,连同残留一起',
    blurb: '应用与它的偏好、缓存、登录项一起检查,不确定的默认不动。',
    bullets: ['卸载时一并检查相关残留', '更新来源覆盖商店与常用渠道', '登录项与后台项在同一页管理'],
    poem: '来去干净,不留残影',
    verse: '来如清风,去无痕迹',
    ctaLabel: '卸载软件',
    ctaHref: 'https://mole.fit/zh/mac-app-uninstaller',
    color: '#b65c3e',
    ringColor: '#d98a63',
    size: 0.42,
    orbit: 4.35,
    phase: 3.85,
    orbitSpeed: 0.075,
    spin: 0.3,
    texture: 'mars',
  },
  {
    id: 'optimize',
    name: '水星',
    role: '优化',
    title: '维护,但每一件都有理由',
    blurb: '缓存、元数据与常见服务按需维护,跳过也要写清原因。',
    bullets: ['维护缓存、元数据与常见系统服务', '需要管理员权限的任务集中处理', '有风险的任务自动跳过并说明'],
    poem: '循其自然,顺手即可',
    verse: '循理而行,分毫不乱',
    ctaLabel: '优化 Mac',
    ctaHref: 'https://mole.fit/zh/mac-optimizer',
    color: '#9a8e80',
    ringColor: '#bcaF9d',
    size: 0.3,
    orbit: 2.05,
    phase: 2.35,
    orbitSpeed: 0.22,
    spin: 0.4,
    texture: 'mercury',
  },
  {
    id: 'analyze',
    name: '木星',
    role: '分析',
    title: '让磁盘变成一张地图',
    blurb: '色块按占用排开,沿着路径一路下探,大文件无处躲藏。',
    bullets: ['色块展示占用,大小一眼可见', '逐层展开到任意文件夹', '移除之前总会再次确认'],
    poem: '一眼看尽,轻重分明',
    verse: '一图千里,轻重自明',
    ctaLabel: '分析磁盘',
    ctaHref: 'https://mole.fit/zh/mac-disk-analyzer',
    color: '#c89a6b',
    ringColor: '#dbb98f',
    size: 0.62,
    orbit: 5.15,
    phase: 2.6,
    orbitSpeed: 0.055,
    spin: 0.25,
    texture: 'jupiter',
  },
]

export const SUN: BodyDef = {
  id: 'status',
  name: '太阳',
  role: '状态',
  title: '状态一屏看完',
  blurb: 'CPU、内存、GPU、磁盘与网络,常驻菜单栏,抬眼即得。',
  bullets: ['实时查看核心指标与温度风扇', '手机与配件的电量也在同一处', '菜单栏常驻,不必打开主窗口'],
  poem: '静观其变,了然于胸',
  verse: '静观万象,心下了然',
  ctaLabel: '查看状态',
  ctaHref: 'https://mole.fit/zh/mac-system-monitor',
  color: '#e8a64c',
  ringColor: '#f2c078',
  size: 0.92,
  orbit: 0,
  phase: 0,
  orbitSpeed: 0,
  spin: 0.05,
}

// "菜单栏"没有对应行星,专属视觉是一根常驻指标条。
export const MENUBAR: BodyDef = {
  id: 'menubar',
  name: '菜单栏',
  role: '菜单栏',
  title: '抬眼即得',
  blurb: '不用打开主窗口,常用指标常驻菜单栏,提醒与养护轻点即达。',
  bullets: ['CPU、内存与网络一眼可见', '电量、温度与风扇随手可查', '提醒与屏幕常亮在菜单栏完成'],
  poem: '抬眼即得,心中有数',
  verse: '举目之间,尽在掌握',
  ctaLabel: '了解菜单栏',
  ctaHref: 'https://mole.fit/zh/',
  color: '#7d8aa3',
  ringColor: '#a9b4c6',
  size: 0,
  orbit: 0,
  phase: 0,
  orbitSpeed: 0,
  spin: 0,
}

// 阅览器与工具页的完整序列(包含菜单栏)。
export const ALL_BODIES: BodyDef[] = [...PLANETS, SUN, MENUBAR]

// 太阳系区块只关心真正的星体。
export const SOLAR_BODIES: BodyDef[] = [...PLANETS, SUN]

export function getBody(id: string): BodyDef {
  return ALL_BODIES.find((body) => body.id === id) ?? PLANETS[0]
}

export type MockKind = 'clean' | 'ai' | 'apps' | 'optimize' | 'analyze' | 'status'

export const MOCK_TABS: { id: MockKind; label: string }[] = [
  { id: 'clean', label: '清理' },
  { id: 'ai', label: 'AI' },
  { id: 'apps', label: '软件' },
  { id: 'optimize', label: '优化' },
  { id: 'analyze', label: '分析' },
  { id: 'status', label: '状态' },
]
