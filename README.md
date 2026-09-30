# Knowledge Workspace Framework

[![Validation](https://github.com/Xenzjay/agent-knowledge-vault/actions/workflows/validate.yml/badge.svg)](https://github.com/Xenzjay/agent-knowledge-vault/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

面向知识管理与 AI Agent 协作的通用信息架构。结构覆盖快速收集、笔记、外部资源、沉淀知识、项目与系统、事务记录、健康、财务、生活领域以及归档整理。

## 快速开始

需要 PowerShell 7 或更新版本：

```powershell
pwsh -NoProfile -File .\scripts\bootstrap.ps1 -Target "D:\KnowledgeWorkspace"
```

默认生成完整的一级大区和二级分类。若同时创建清单中建议的三级主题目录：

```powershell
pwsh -NoProfile -File .\scripts\bootstrap.ps1 -Target "D:\KnowledgeWorkspace" -IncludeSuggestedSubgroups
```

初始化行为：

- 目标目录不存在或为空时直接创建。
- 目标目录非空时默认停止，避免误写入已有资料。
- 使用 `-Force` 时执行合并：补齐缺失目录，并覆盖本框架生成的 `目录结构.md`、`AGENTS.md`、`工作区导航.md` 和 `_模板` 中同名模板；其他已有文件保留。

## 使用方式

目录和模板对 Obsidian 与普通 Markdown 文件夹保持一致，使用时不需要选择模式。

### Obsidian

1. 用 Obsidian 打开初始化后的目标目录。
2. 将 `工作区导航.md` 作为入口页，将 `目录结构.md` 作为分类总览。
3. 使用 `_模板` 中的模板创建资源、批量记录和决策记录。
4. 图片和文档放入 `_附件/YYYY/`，正文使用相对链接或 Obsidian 双链引用。

### 普通 Markdown 与 Agent

1. 将目标目录作为普通 Markdown 工作区打开或交给 Agent。
2. 先读取 `AGENTS.md`、`工作区导航.md` 和 `目录结构.md`。
3. 根据 `manifest/routing-rules.yaml` 的路由规则选择目标目录。
4. 记录时保留简洁的 frontmatter、来源、能力说明和入口链接；不需要 Obsidian 插件也可以使用。

## 信息架构

```text
收件箱          临时捕获、任务与待读
笔记            灵感、阅读、学习、随笔、创作与媒体
资源            网站、工具、代码仓库、剪藏、娱乐与素材
知识            技术、方法、调研、生活、办事与人文
工作台          项目、AI 系统、自动化、实验与基础设施
事务记录        账号、个人档案与订阅
健康            健身、饮食与医疗健康
财务            收支、投资与保险
家庭与生活      家务、宠物、人际、旅行与礼物
归档            已完成或不再活跃的内容
待整理区        未分类、待确认与待删除项目
```

完整分类和可选主题见 [`manifest/vault-manifest.json`](manifest/vault-manifest.json)。生成的 `目录结构.md` 提供可浏览的分类总览。目录层级默认是“领域 → 稳定主题”；只有主题需要独立检索或维护时再增加下一级。

## Agent 工作流

```text
记录：
批量记录：
暂存：
批量入库
```

Agent 路由规则位于 `manifest/routing-rules.yaml`，协作约定位于 `vault/AGENTS.md`。资源记录采用简洁能力卡，说明内容是什么、能做什么、适用场景和入口。

## 配置

- `manifest/vault-manifest.json`：完整目录模型及分类
- `manifest/routing-rules.yaml`：内容到目录的路由规则
- `templates/`：资源、批量记录和决策模板
- `scripts/bootstrap.ps1`：按 manifest 创建工作区
- `scripts/validate.ps1`：检查 manifest、路由目标、frontmatter 和常见敏感字段
- `scripts/smoke-test.ps1`：在临时目录验证初始化和合并行为

## 校验

```powershell
pwsh -NoProfile -File .\scripts\validate.ps1
pwsh -NoProfile -File .\scripts\smoke-test.ps1
```

工作区的数据保护边界见 [`SECURITY.md`](SECURITY.md) 与 [`docs/数据保护.md`](docs/数据保护.md)。
