export const PROJECT_URL = 'https://github.com/csic21/qili'
export const DOWNLOAD_URL = `${PROJECT_URL}/releases/latest`
export const LOGO_URL = `${import.meta.env.BASE_URL}qili-logo.png`

export const TOOLS = [
  {
    id: 'clean', label: '空间整理', title: '先看清，再整理。',
    description: '把缓存、日志和开发工具数据分组，查看真实路径和大小。只有你勾选并确认的目录，才会移到废纸篓。',
    points: ['扫描用户缓存、日志、Xcode 与 npm 缓存', '查看目录明细后选择要整理的分类', '移到废纸篓后可以通过访达恢复'],
    status: '可扫描与清理',
  },
  {
    id: 'apps', label: '应用管理', title: '认识每个应用的来去。',
    description: '查看已安装应用的大小、版本和关联文件，检查可用更新，管理用户级启动项。',
    points: ['应用清单和关联文件可在访达中查看', '检查 Sparkle 与 Homebrew 更新来源', '用户级启动项可启停；暂不执行应用卸载'],
    status: '清单、更新与启动项',
  },
  {
    id: 'optimize', label: '系统维护', title: '让维护有据可查。',
    description: '重建 Quick Look 缩略图、刷新 DNS 缓存、检查 Spotlight 索引与磁盘。每项任务都会留下结果。',
    points: ['运行前可以查看任务说明', '需要管理员权限时显示系统授权窗口', '完成、跳过和失败分别记录'],
    status: '四项按需维护',
  },
  {
    id: 'analyze', label: '文件地图', title: '空间都去了哪里？',
    description: '从主目录开始查看文件夹占用，逐层打开目录，找到值得整理的大文件。',
    points: ['真实测量当前目录的文件与文件夹大小', '通过路径导航返回上级', '在访达中定位文件；此页不执行删除'],
    status: '目录测量与定位',
  },
  {
    id: 'status', label: '运行状态', title: '让数字说明此刻。',
    description: '观察 CPU、GPU、内存、磁盘与网络，查看占用较高的进程。无法读取的硬件指标会明确标注。',
    points: ['实时采样并显示变化趋势', '查看内存占用较高的进程', '温度、风扇与电池数据视机型可用'],
    status: '实时指标',
  },
] as const

export type ToolId = (typeof TOOLS)[number]['id']
export function isToolId(id: string): id is ToolId {
  return TOOLS.some((tool) => tool.id === id)
}
