# moon_mutest 项目申报书

## 一、基本信息

- 项目名称：moon_mutest：MoonBit 变异测试工具
- 参赛者：请填写姓名或 Gitlink / GitHub 昵称
- 联系方式：请填写手机号或邮箱
- 项目方向：MoonBit 工程质量基础设施 / 测试工具 / 开发者工具链
- 项目类型：原创项目
- GitHub 仓库链接：https://github.com/Magic486/moon_mutest
- Gitlink 仓库链接：https://www.gitlink.org.cn/Magic486/moon_mutest
- 开源许可证：Apache-2.0

## 二、项目简介

`moon_mutest` 是一个面向 MoonBit 项目的变异测试工具包。项目通过自动扫描
MoonBit 源码、生成变异候选点、复制临时 workspace、逐个应用 mutation 并执行
`moon check` / `moon test`，帮助开发者判断现有测试是否真的能发现代码中的语义缺陷。

普通单元测试只能说明当前测试是否通过，覆盖率工具只能说明哪些代码被执行过，但它们
并不能充分证明测试拥有有效的断言能力。变异测试会主动制造小型语义变化，例如把
`==` 改为 `!=`、把 `&&` 改为 `||`、把 `true` 改为 `false`。如果测试失败，说明
测试成功发现了这个缺陷；如果测试仍然通过，则说明该位置的测试可能缺少关键断言、
边界用例或业务约束检查。

本项目希望为 MoonBit 生态补充一类目前相对空白的测试质量评估工具，让 MoonBit
开发者不仅能运行测试，还能评估测试的“杀伤力”和可信度。

## 三、项目方向与适用场景

本项目属于 MoonBit 开源生态中的工程基础设施和开发者工具方向，主要服务于以下场景：

- MoonBit 库作者希望评估测试套件是否足够有效；
- MoonBit 应用项目希望在 CI 中发现测试断言薄弱的代码区域；
- 教学、示例和开源项目希望用更直观的方式展示测试质量；
- 工具链生态希望补充 `moon test`、coverage 之外的质量度量；
- 参赛项目或社区项目希望在验收前进行更严格的自测。

与 `moon test` 的关系是互补的：`moon test` 负责运行测试，`moon_mutest` 负责进一步
追问“如果代码被改坏，测试能不能发现”。因此它可以成为 MoonBit 项目在 CI、发布前检查
和开源质量评估中的辅助工具。

## 四、拟实现的核心功能

项目计划实现并持续完善以下功能：

1. 源码扫描与变异候选发现

   支持扫描 MoonBit 源码文本，识别布尔字面量、相等比较、关系比较、算术运算、
   逻辑运算和数字边界等可变异位置。扫描器会保守跳过字符串、字符字面量、行注释
   和块注释，减少无意义 mutation。

2. 规则 profile

   提供 `basic`、`boundary`、`experimental` 等规则 profile。基础规则覆盖常见语义
   变化，边界规则额外覆盖 `0`、`1`、`-1` 等常见边界值变化，后续可继续扩展到
   模式匹配、错误处理、集合操作和函数调用等 MoonBit 语义场景。

3. Mutant 生成与 patch 预览

   为每个候选点生成 mutated source，并提供 patch preview 和可逆文本编辑能力，
   方便开发者理解每一个 mutant 到底改动了什么。

4. 项目级 mutation plan

   支持多文件项目规划，为所有 mutants 分配稳定的全局 id，并支持按 mutation kind、
   rule label、文件、行号范围、id 范围、前 N 个 mutants、批次和分片进行选择。

5. 真实 workspace 自动运行

   CLI 支持读取真实 MoonBit workspace，复制到临时目录，在临时副本中先执行 baseline，
   再逐个应用 mutant，运行 `moon check` / `moon test` 或自定义命令，并汇总真实结果。
   默认不会直接修改用户原项目。

6. 结果分类与报告

   将每个 mutant 分类为 `Killed`、`Survived`、`CompileError`、`Timeout` 或 `Skipped`。
   支持文本、Markdown 和 JSON 报告，便于本地阅读、CI 展示或其他工具集成。

7. 质量门禁

   提供 mutation score、survived mutants、compile errors、timeouts、skipped mutants
   等指标，并支持在 CI 中设置质量门禁，用于判断是否允许合并或发布。

8. 脚本与 CI 集成

   支持生成 Bash / PowerShell dry-run 脚本，便于在不同环境中接入；后续可继续补充
   GitHub Actions 示例、增量运行和可视化报告。

## 五、技术路线

项目采用“库优先，CLI 补充”的技术路线。

核心扫描、规则、规划、报告和质量门禁逻辑使用 MoonBit 实现，并拆分为清晰的功能子包：

- `core/`：扫描器、mutation 规则、过滤和 mutant 生成；
- `io/`：manifest、JSON 和文本输出；
- `plan/`：项目级规划和 workspace 文件选择；
- `run/`：patch、执行计划、项目报告、baseline、脚本和质量门禁；
- `runner/`：真实 workspace 复制、mutation 应用、进程执行和结果汇总；
- `cmd/main/`：命令行入口；
- `tests/`：黑盒测试，覆盖根包公开 API 和核心行为。

真实 workspace runner 需要访问文件系统并启动外部命令，因此 CLI 和 runner 使用
MoonBit JS target，借助 Node 环境完成目录复制、文件读写和 `moon check` /
`moon test` 执行。这样可以保持核心库逻辑可测试、可复用，同时让命令行工具具备真实
项目执行能力。

## 六、当前进展

当前仓库已经完成项目初始化、包结构整理、README、许可证、GitHub/Gitlink 同步和
核心功能实现。已经具备以下基础：

- 项目以 MoonBit 为主要实现语言；
- 已配置 GitHub 和 Gitlink 两个公开仓库；
- 已提供 Apache-2.0 许可证；
- README 已说明项目目标、快速开始、CLI 用法、真实 runner 和开发验证方式；
- 已实现扫描、规则、manifest、mutant 生成、patch preview、项目规划、报告和质量门禁；
- 已实现 JS/Node workspace runner，可以复制临时目录并运行真实 `moon` 命令；
- 已提供较完整测试，覆盖核心路径；
- 已通过 `moon check`、`moon test` 和 JS target 测试；
- Git 历史已整理为 15 个有效 commit，满足申报阶段提交记录要求。

## 七、阶段计划

### 第一阶段：项目申报与基础闭环

目标是在申报阶段形成可运行、可展示、可继续演进的 MVP。

- 完成 MoonBit 包结构和公开 API 设计；
- 完成基础 mutation 规则和源码扫描器；
- 完成文本、JSON、Markdown 报告；
- 完成 CLI 的 `scan` 和 `run` 命令；
- 完成真实 workspace runner 的基础闭环；
- 完成 README、申报书、许可证和仓库同步；
- 保持 `moon check` / `moon test` 通过。

### 第二阶段：工程质量增强

目标是提升工具在真实项目中的稳定性和可用性。

- 扩展更多 MoonBit 语法保护，减少无意义 mutation；
- 增加更细粒度的 rule profile 和配置选项；
- 优化 workspace 文件选择和路径处理；
- 增强 Markdown / JSON 报告，便于 CI 展示；
- 增加更多真实项目级端到端测试；
- 补充 GitHub Actions 或其他 CI 示例。

### 第三阶段：生态集成与验收准备

目标是让项目达到可验收、可展示、可发布的状态。

- 准备 mooncakes.io 发布材料；
- 补充最小可运行示例和完整使用教程；
- 完成质量门禁示例；
- 整理常见问题和故障排查说明；
- 准备最终展示材料，突出 MoonBit 生态价值、工程质量和长期维护计划。

## 八、预期交付物

项目预期交付以下内容：

- 一个可复用的 MoonBit mutation testing 库；
- 一个可运行的 CLI 工具；
- 支持真实 MoonBit workspace 自动执行的 runner；
- 文本、Markdown 和 JSON 三类报告输出；
- 质量门禁和 CI 接入基础能力；
- README、申报书、仓库结构说明和项目文档；
- 覆盖核心行为的 MoonBit 测试；
- GitHub 和 Gitlink 同步的公开仓库；
- Apache-2.0 开源许可证；
- 后续可发布到 mooncakes.io 的包。

## 九、原创性与差异化说明

本项目为原创 MoonBit 工具项目，不是对某个已有开源项目的直接移植。项目借鉴的是
mutation testing 这一通用软件测试思想，但具体的 MoonBit 扫描逻辑、规则模型、
执行计划、报告模型、质量门禁和 workspace runner 均围绕 MoonBit 工具链重新设计实现。

项目差异化价值主要体现在：

- 面向 MoonBit 生态当前较缺少的测试质量评估能力；
- 不是简单包装 `moon test`，而是主动注入语义变化并验证测试是否能发现；
- 同时提供库 API 和 CLI，方便二次开发和直接使用；
- 关注真实 workspace 执行，而不只停留在源码字符串扫描；
- 可以与 CI、质量门禁、报告系统继续集成；
- 对 MoonBit 工具链、开源库验收和社区项目质量提升有直接帮助。

## 十、开源合规说明

本项目采用 Apache-2.0 许可证。项目为原创实现，目前没有直接移植或复制其他开源项目
代码。若后续引入第三方代码、测试数据、样例文件或参考实现，会在 README 或专门文档中
明确说明来源、链接、许可证和参考范围，并遵守对应许可证要求。

项目仓库不包含闭源代码、私有代码或商业代码。生成文件、构建产物和临时 workspace
会尽量排除在版本控制之外，避免污染仓库和提交材料。

## 十一、风险与应对

1. 等价 mutant 风险

   部分 mutation 可能不会改变实际业务语义，导致结果需要人工判断。项目会通过更保守的
   规则、rule profile、过滤配置和报告说明逐步降低此类噪声。

2. 大型项目运行时间风险

   变异测试天然比普通测试更耗时。项目通过 `--max-mutants`、`--first`、id 范围、
   分片和批次规划降低单次运行成本，并为后续增量运行留下接口。

3. 语法覆盖不足风险

   MoonBit 语言和工具链持续演进，源码级扫描需要不断适配。项目会优先覆盖高价值、
   易解释、低误报的规则，再逐步扩展更复杂的语义场景。

4. 跨平台执行风险

   runner 依赖 JS target 和 Node 进程能力。项目会持续补充 Windows、macOS、Linux
   场景下的路径、命令和超时处理测试。

## 十二、验收标准

项目达到阶段性验收时，预期满足以下标准：

- 仓库公开可访问，GitHub 与 Gitlink 内容同步；
- 项目以 MoonBit 为主要实现语言；
- README 能让用户复现安装、检查、测试和基本使用；
- 至少提供一个可运行的 CLI 示例；
- `moon check`、`moon build`、`moon test` 能通过；
- 核心扫描、mutant 生成、workspace runner、报告和质量门禁有测试覆盖；
- 提供 OSI 认可的开源许可证；
- 能说明项目原创性、边界和后续维护计划；
- 具备发布到 mooncakes.io 的准备基础。

## 十三、可复制到报名问卷的精简版

项目名称：moon_mutest：MoonBit 变异测试工具

项目简介：`moon_mutest` 是一个面向 MoonBit 项目的变异测试工具包。它会扫描
MoonBit 源码，生成变异候选点，将 mutation 应用到真实项目的临时副本中，执行
`moon check` / `moon test`，并将结果分类为 killed、survived、compile-error、
timeout 等状态，用于衡量测试套件是否真正能发现语义缺陷。

项目方向与适用场景：本项目属于 MoonBit 工程质量基础设施和开发者工具方向，适用于
MoonBit 库作者、应用项目、CI 质量门禁和开源项目验收。它与 `moon test` 互补，
用于评估测试断言能力和发现测试薄弱区域。

核心功能：源码扫描、基础/边界 mutation 规则、mutant 生成、patch preview、多文件
mutation plan、真实 workspace runner、`moon check` / `moon test` 自动执行、文本/
Markdown/JSON 报告、质量门禁、分片和批次规划。

原创性说明：本项目为原创 MoonBit 工具项目，不是对已有开源项目的直接移植。项目参考
mutation testing 这一通用测试思想，但围绕 MoonBit 工具链独立设计扫描规则、执行计划、
报告模型、质量门禁和 workspace runner。

预期交付物：可复用 MoonBit 库、可运行 CLI、真实 workspace runner、测试用例、README、
申报书、Apache-2.0 许可证、GitHub/Gitlink 同步仓库，以及后续可发布到 mooncakes.io
的包。

GitHub 仓库：https://github.com/Magic486/moon_mutest

Gitlink 仓库：https://www.gitlink.org.cn/Magic486/moon_mutest
