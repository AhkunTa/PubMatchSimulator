# 技术与系统架构

> 文档版本：0.1  
> 目标引擎：Godot 4.6  
> 原则：数据驱动、事件解耦、规则可测试、表现层不直接修改游戏状态。

## 1. 架构目标

- 角色、人格、指令和事件可以通过资源配置扩展。
- AI 决策可以在无 UI 环境下重复测试。
- 单局状态与局外存档明确分离。
- 结算过程可回放、可解释、可记录。
- MVP 不为尚未确定的联网和实时战斗过度设计。

## 2. 分层

```text
UI / Presentation
        ↓ 发送玩家意图
Application / Match Flow
        ↓ 调用规则
Domain / Rules & AI
        ↓ 读写
Runtime State

Content Resources → Domain
Persistence ←→ Meta State
```

### 表现层

负责界面、动画、声音和文本展示。只发送命令和监听结果，不直接计算伤害或修改信任。

### 流程层

负责节点阶段、输入锁定、结算顺序、暂停和场景切换。

### 规则层

负责 AI 效用、战斗/搜索/救援结算、状态修正和撤离条件。规则应尽量使用纯函数。

### 数据层

分为静态内容资源、单局运行状态和局外存档。

## 3. 推荐目录

```text
res://
  scenes/
    bootstrap/
    main/
    match/
    meta/
    results/
    ui/
  scripts/
    autoload/
      game.gd
      content_db.gd
      save_service.gd
      event_bus.gd
    match/
      match_controller.gd
      node_controller.gd
      resolution_pipeline.gd
    domain/
      ai_decision_service.gd
      combat_resolver.gd
      relation_resolver.gd
      extraction_resolver.gd
    state/
      run_state.gd
      actor_state.gd
      teammate_state.gd
      meta_state.gd
    resources/
      role_definition.gd
      personality_definition.gd
      command_definition.gd
      event_definition.gd
      effect_definition.gd
    ui/
  data/
    roles/
    personalities/
    commands/
    events/
  tests/
    unit/
    simulation/
  docs/
```

## 4. 核心对象

### 静态定义

静态定义建议使用 Godot `Resource`，在运行时只读。

```text
RoleDefinition
  id
  display_name
  base_stat_modifiers
  passive_effects
  unique_commands

PersonalityDefinition
  id
  drive_ranges
  utility_modifiers
  feedback_texts

CommandDefinition
  id
  tags
  target_rule
  base_influence
  costs
  effects

EventDefinition
  id
  type
  conditions
  visible_info
  hidden_info
  candidate_actions
  result_table
```

JSON 适合外部表格管线，但 Godot 原型阶段使用 `.tres` 能获得类型、编辑器和资源引用支持。若后续内容团队需要表格，再增加导入器，不要让运行时代码同时维护两套格式。

### 运行状态

```text
RunState
  seed
  phase
  threat
  cohesion
  greed_pressure
  loot_value
  current_node
  player
  teammates[]
  history[]

ActorState
  health
  stress
  temporary_effects[]

TeammateState extends ActorState
  trust
  drives
  personal_loot
  current_intent
  personality_id
```

运行状态不能持有 UI 节点引用。

## 5. 单局状态机

```text
SETUP
→ NODE_REVEAL
→ PLAYER_COMMAND
→ AI_INTENT
→ OPTIONAL_RESPONSE
→ RESOLUTION
→ AFTERMATH
→ ROUTE_CHOICE
→ NODE_REVEAL

任意阶段 → EXTRACTION / DEFEAT → RESULTS
```

| 阶段 | 职责 |
| --- | --- |
| SETUP | 创建角色、队友、随机种子和初始节点 |
| NODE_REVEAL | 生成并展示情报 |
| PLAYER_COMMAND | 接受玩家指令 |
| AI_INTENT | 计算每名 AI 候选行为 |
| OPTIONAL_RESPONSE | 劝说、强制或角色能力 |
| RESOLUTION | 按固定顺序结算 |
| AFTERMATH | 更新关系、压力、威胁和事故 |
| ROUTE_CHOICE | 深入、分支或撤离 |
| RESULTS | 生成结算并提交局外奖励 |

流程切换只由 `MatchController` 发起，避免 UI 和事件脚本各自切换状态。

## 6. 结算管线

一次节点结算推荐使用不可变的输入快照：

```text
ResolutionInput
  run_snapshot
  event_definition
  player_command
  ai_intents
  random_seed
```

输出：

```text
ResolutionResult
  actions[]
  effects[]
  state_delta
  explanations[]
  follow_up_tags[]
```

执行顺序：

1. 锁定所有参与者意图。
2. 结算先手与情报效果。
3. 结算战斗、搜索或救援主体。
4. 结算伤势和物资。
5. 结算信任、压力、凝聚力。
6. 判断事故、撤离和失败。
7. 生成解释文本与日志。

表现层消费结果播放动画，播放完成后再应用下一阶段，不能在动画回调中重新计算规则。

## 7. AI 决策服务

`AIDecisionService` 输入当前快照、事件、玩家指令和某个队友，输出候选行为列表。

```text
DecisionOption
  action_id
  utility
  factors[]

DecisionFactor
  source_id
  value
  display_priority
  localized_text_key
```

示例：

```text
撤离：58
  玩家指令 +22
  信任 +13
  生存欲 +18
  高价值物资 -11
  扰动 -4
```

系统保留所有 factor，UI 只显示绝对值最大的 2—3 项。这同时解决可解释性和界面信息过载。

随机数必须来自本局持有的 `RandomNumberGenerator`，并记录初始种子。规则层禁止直接调用全局随机函数，否则无法复现问题。

## 8. 效果系统

指令、角色、事件和人格都可能修改状态，建议统一为小型效果对象，而不是在各处写分支。

MVP 效果类型：

- `ModifyStat`
- `ModifyTrust`
- `ModifyRunState`
- `AddTemporaryEffect`
- `ForceAction`
- `RevealInfo`
- `GrantLoot`
- `DealDamage`
- `Heal`

效果由 `EffectResolver` 应用并生成 `StateDelta`。复杂条件通过标签和条件资源组合；MVP 阶段不制作通用脚本语言。

## 9. 信号与通信

建议保留少量全局事件：

```text
match_started
phase_changed
state_changed
resolution_ready
match_finished
save_completed
```

具体按钮点击等局部信号保留在场景内部。不要把所有通信都塞进全局 `EventBus`，否则依赖关系难以追踪。

## 10. 存档

### 局外存档

```text
MetaState
  schema_version
  account_level
  account_xp
  unlocked_roles[]
  unlocked_commands[]
  role_mastery{}
  currency
  settings
```

要求：

- JSON 或二进制均可，但必须包含 `schema_version`。
- 保存时写入临时文件，成功后替换正式存档。
- 加载失败时保留损坏文件并创建默认状态。
- 静态定义只保存 ID，不序列化整份 Resource。

### 中途存档

MVP 可不支持战斗中断点。若后续加入，应保存完整 `RunState`、当前状态机阶段和随机数状态。

## 11. 可测试性

### 单元测试

- 属性钳制。
- 服从公式。
- 效果应用顺序。
- 撤离和失败条件。
- 存档迁移。

### 模拟测试

无 UI 连续运行 1,000—10,000 局，记录：

- 各指令选择率和成功率。
- 各人格违抗率。
- 每节点平均威胁和压力。
- 事故触发节点。
- 撤离率、死亡率和平均收益。
- 各角色胜率与收益差。

如果某人格的违抗率极高，先检查其因素和反馈是否合理，不应只把概率压平。人格需要差异，但不能成为固定陷阱。

## 12. 日志与调试

开发模式提供：

- 当前随机种子。
- 完整 AI 候选行为与效用因素。
- 状态变化前后对比。
- 强制跳转节点。
- 修改威胁、信任、压力。
- 快速触发撤离或事故。

每次结算生成结构化历史记录，错误报告可附带最近 20 条记录。

## 13. 实施顺序

1. `Resource` 定义与运行状态。
2. 单局状态机和最简 UI。
3. AI 决策服务及解释因素。
4. 指令与效果结算。
5. 事件节点和撤离。
6. 医生、突击手两个角色。
7. 局外结算与存档。
8. 模拟测试与数值调整。

在第 5 步之前不投入大量动画、美术和内容生产，先确认核心循环成立。

具体场景职责、路线生成和界面流转见[场景与界面流程](SCENE_DESIGN.md)。

## 14. 架构约束

- UI 不直接写 `RunState`。
- 静态 `Resource` 在运行时不可修改。
- 规则计算不依赖场景树。
- 所有随机决策可通过种子复现。
- 角色能力优先组合已有 Effect，避免每个角色创建专属硬编码流程。
- 配置读取失败必须尽早报错，不能静默回退到零值。
- MVP 不引入 ECS、网络同步、数据库或复杂依赖注入框架。
