# 来源与许可说明

记录日期：2026-10-11。当前工作品牌：栖理 / Qili。

## 项目历史与当前设计

早期版本以 Mole 的公开 Mac 界面为视觉参考。这次调整改变了面向用户的品牌、导航结构、
颜色、清理摘要、维护面板、文件地图与网站内容，并移除了行星主题和原版页面示意。
历史参考关系仍在此记录；改名或改写文档本身不能替代对具体内容的核查。

Mole / Tw93 的名称与产品内容归其相应权利人。栖理不声称与其存在授权、关联或认可关系。
相关上游声明：[品牌政策](https://github.com/tw93/Mole/blob/main/TRADEMARK.md)、
[专有产品条款](https://mole.fit/terms)。CLI 的代码许可与 Mac 产品、商标及其他素材的权利应分别判断。

## 当前代码检索范围

检查了 `Sources/`、`scripts/`、SwiftPM 清单与网页入口及依赖清单。
当前树中未发现 vendored Mole CLI、对 Mole CLI 可执行文件的调用或 GPL 标记的源文件；
原生目标没有 SwiftPM 第三方依赖，操作通过 AppKit、系统 API 和本机命令实现。
这是一份当前树检索记录，不是对全部历史提交、所有代码片段及法律归属的证明。
独立编写的本项目代码继续使用仓库 MIT 许可证，第三方代码不能因此被重新授权。

## 品牌与素材

- 产品显示名为栖理 / Qili；此工作名称尚未完成正式商标检索。
- 鼹鼠 Logo 使用内置 image_gen 从文字提示生成，未提供原版 Logo、截图或图片作为输入。
- 母版为 `Assets/Branding/QiliLogo.png`；生成提示词原文保留。
- 图标缩放与 icns 导出由 `scripts/generate_icons.sh` 完成，透明通道保留。
- 原生界面的标准符号由系统 SF Symbols 提供；网页示意使用 CSS 绘制。
- 当前网页不包含原版截图、产品文案或行星展示代码。

AI 生成与独立设计并不等于已经完成近似商标、图片相似性或全部权利的检索。

## 第三方依赖

网站运行时使用 React / React DOM（MIT），构建工具含 Vite、TypeScript、React 类型包、
Vite React 插件与 oxlint。版本和完整依赖图见 `site/package.json` 与 `site/pnpm-lock.yaml`；
各软件包的 LICENSE / NOTICE 应按自身条款保留，仓库 MIT 不覆盖第三方的授权要求。

## 后续引入 GPL CLI 代码

如果以后复制、修改或把 Mole CLI 代码整合进发行软件，应记录准确的上游仓库、提交、
文件清单及修改内容，保留原版权和许可证，并根据 GPL-3.0 的适用条件提供对应源代码、
必要构建材料及相应许可。不能仅凭添加本仓库 MIT 文件就把 GPL 部分重新授权为 MIT。
如果通过独立进程调用 CLI，还应结合实际集成与分发方式判断义务，不能预设一律不受 GPL 约束。

GPL 许可原文：[GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0.html)。
目前尚未进行全历史代码溯源、商标注册数据库检索或律师出具的法律审查。
