# moon_mutest 项目申报书

- 项目名称：moon_mutest：MoonBit 变异测试工具
- 项目方向：MoonBit 工程质量基础设施 / 测试工具
- GitHub 仓库链接：https://github.com/Magic486/moon_mutest
- Gitlink 仓库链接：https://www.gitlink.org.cn/Magic486/moon_mutest
- 项目类型：原创项目

## 项目简介

moon_mutest 面向 MoonBit 项目提供变异测试能力：自动发现源码中的可变异位置，生成 mutated source，输出文本/JSON manifest，并将后续 `moon check` / `moon test` 结果分类为 killed、survived、compile-error、timeout 等状态，用于衡量测试套件是否真正能捕获语义缺陷。

## 创新点与特点

- 面向 MoonBit 生态当前较缺少的测试质量评估能力，补充 `moon test` 和覆盖率之外的质量维度；
- 不是简单包装测试命令，而是主动注入语义变化，验证测试是否能发现真实缺陷；
- 支持从源码扫描、mutation plan、临时 workspace 复制、真实命令执行到报告汇总的闭环；
- 同时提供可复用 MoonBit 库和可运行 CLI，兼顾生态集成和直接使用；
- 支持质量门禁、分片、批次和多格式报告，具备继续接入 CI 的工程基础。

## 核心功能

- 扫描 MoonBit 源码，生成布尔、比较、关系、算术、逻辑、数字边界变异点；
- 保守跳过字符串、字符字面量、行注释、块注释和部分 MoonBit 结构符号；
- 为每个候选点生成 mutated source、全局 mutation plan 和单 mutant patch 预览；
- 支持按 mutation kind、label、行号范围筛选候选点；
- 输出文本/JSON/Markdown 报告、配置模型、执行计划、baseline gating、批次/分片计划和 mutation score；
- 支持 workspace 源文件选择、临时工作区复制、真实命令执行、Bash/PowerShell runner 脚本生成和 CI 质量门禁；
- 提供 CLI 示例入口和 GitHub Actions，覆盖 `moon check`、`moon build` 与 `moon test`。

## 实现计划

第一阶段完成核心扫描、变异生成、规则 profile、配置、项目级计划、patch 预览、报告、CLI、README 与 CI。第二阶段完成 JS/Node 临时工作区 runner，将 baseline、selection、batch、script 与 quality gate 层接入真实文件改写和命令执行。第三阶段扩展更精细的 MoonBit 语法保护、CI Markdown 报告和最小复现输出。

## 交付物

可复用 MoonBit 库、可运行 CLI、README 示例、测试用例、CI 工作流、Apache-2.0 许可证，以及后续可发布到 mooncakes.io 的包。
