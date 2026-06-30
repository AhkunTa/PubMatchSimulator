# AI 响应权重 MVP

> 目标：定义两名 AI 队友在玩家出牌后的行为候选、权重公式和可解释输出。  
> 关联文档：[MVP](../core/MVP.md) · [MVP 卡牌基础池](CARD_POOL_MVP.md) · [节点内结算 MVP](ENCOUNTER_RESOLUTION_MVP.md)

## 1. 核心原则

AI 不做“服从判定”。AI 每回合选择自己效用最高的行为。

玩家出牌只影响 AI 权重，不直接控制 AI。AI 的选择必须能解释给玩家看，避免像纯随机惩罚。

## 2. 输入快照

```text
AIResponseInput
  actor: ActorState
  player: ActorState
  other_ai: ActorState
  card: CardDefinition
  shout_id: String
  encounter: EncounterState
  run: RunState
  rng_seed: int
```

### 2.1 ActorState 需要字段

```text
ActorState
  id
  display_name
  actor_type: player / ai / enemy
  health: 0..100
  agility: 0..100
  marksmanship: 0..100
  stress: 0..100
  load: 0..100
  trust: 0..100
  traits[]
  position: front / mid / back / solo / disengaging
  inventory_value
  is_down
  is_evacuated
  current_intent
```

### 2.2 EncounterState 需要字段

```text
EncounterState
  node_type: battle / search / dispute / accident / evac / unknown
  resource_value: 0..100
  threat_level: 0..100
  chaos: 0..100
  evac_window: 0..100
  enemy_pressure: 0..100
  downed_actors[]
  high_value_loot_available: bool
  round_index
```

## 3. 输出结构

```text
AIResponseResult
  actor_id
  selected_action_id
  utility
  factors[]
  preview_label
  preview_confidence: clear / uncertain / hidden
```

```text
DecisionFactor
  source_id
  value
  display_priority
  text
```

UI 默认只显示绝对值最高的 `2` 条因素。调试模式显示完整因素列表。

## 4. 行为候选

| action_id | 行为 | 典型后果 |
| --- | --- | --- |
| `full_follow` | 完整跟进玩家牌面方向 | 形成协同伤害、协同撤退或协同搜刮 |
| `partial_follow` | 部分跟进但保守执行 | 效果较弱，压力较低 |
| `hold_position` | 原地稳住 | 降低自身风险，但减少协同 |
| `retreat_only_self` | 自己撤退或独撤 | 队伍战力下降，可能带走个人物资 |
| `solo_loot` | 单走搜刮 | 获得个人物资，主战区少人 |
| `rescue_target` | 救援倒地角色 | 可能救起队友，也可能暴露自己 |
| `steal_bag` | 抢包或搜包 | 物资转移，关系恶化 |
| `panic_break` | 崩溃乱跑或引怪 | 造成事故、威胁或混乱上升 |

## 5. 总公式

每个候选行为都使用同一层公式：

```text
utility =
base_action_weight
+ card_signal_modifier
+ shout_modifier
+ trait_modifier
+ stat_modifier
+ position_modifier
+ encounter_modifier
+ relation_modifier
+ other_ai_modifier
+ random_jitter
```

MVP 中 `random_jitter` 使用 `-8..8`。所有随机数必须由当前节点种子派生，便于复现。

最终选择：

```text
selected_action = max(utility)
```

若最高和第二高差值小于 `8`，UI 预览为 `uncertain`，结算解释也应强调“犹豫”。

## 6. 基础权重

| action_id | base_action_weight |
| --- | ---: |
| `full_follow` | 30 |
| `partial_follow` | 34 |
| `hold_position` | 28 |
| `retreat_only_self` | 18 |
| `solo_loot` | 14 |
| `rescue_target` | 10 |
| `steal_bag` | 8 |
| `panic_break` | 4 |

基础权重故意让 `partial_follow` 略高，保证普通 AI 默认不极端，但又不总是完美配合。

## 7. 卡牌信号修正

| card signal | full_follow | partial_follow | hold_position | retreat_only_self | solo_loot | rescue_target | steal_bag | panic_break |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `signal_attack` | +14 | +8 | -6 | -8 | -4 | 0 | 0 | +3 |
| `signal_suppress` | +8 | +10 | +4 | +4 | 0 | 0 | 0 | -4 |
| `signal_focus_fire` | +12 | +8 | -4 | -6 | -4 | 0 | 0 | 0 |
| `signal_reposition` | +6 | +8 | +2 | +4 | +2 | 0 | 0 | 0 |
| `signal_hold` | -4 | +8 | +14 | +2 | -4 | +2 | -2 | -6 |
| `signal_retreat` | -10 | +4 | +4 | +14 | -2 | 0 | 0 | -2 |
| `signal_cover` | +4 | +8 | +8 | +10 | -4 | +8 | -4 | -4 |
| `signal_loot` | -6 | +2 | -2 | -2 | +16 | 0 | +6 | +2 |
| `signal_steal` | -8 | -2 | -4 | -2 | +4 | -8 | +20 | +6 |
| `signal_drop_load` | -6 | +4 | +4 | +12 | -8 | 0 | -8 | -4 |
| `signal_follow_me` | +16 | +8 | -4 | -6 | -4 | 0 | 0 | +2 |
| `signal_escape_now` | -10 | +2 | +2 | +18 | -4 | 0 | 0 | -2 |

若一张牌有多个信号，修正相加后钳制到 `-20..24`，避免单张牌过度支配 AI。

## 8. 喊话修正

| shout_id | 修正 |
| --- | --- |
| `shout_follow` | `full_follow +10`，`partial_follow +6` |
| `shout_retreat` | `retreat_only_self +8`，`partial_follow +4` |
| `shout_rescue` | `rescue_target +12`；若无人倒地，改为 `hold_position +4` |
| `shout_take_point` | `hold_position +8`；有 `莽撞` 时 `full_follow +6` |
| `shout_your_loot` | `solo_loot +10`，`steal_bag -6` |
| `shout_cover_me` | `retreat_only_self -8`，`partial_follow +6` |

喊话修正受信任影响：

```text
effective_shout_modifier = shout_modifier * trust_scale
trust_scale = clamp(trust / 60.0, 0.25, 1.35)
```

## 9. 词条修正

| trait | full_follow | partial_follow | hold_position | retreat_only_self | solo_loot | rescue_target | steal_bag | panic_break |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `侦察位` | +2 | +4 | 0 | +4 | +8 | 0 | +2 | 0 |
| `突击位` | +10 | +4 | -4 | -6 | 0 | 0 | +2 | +2 |
| `支援位` | +2 | +6 | +4 | 0 | -2 | +12 | -6 | -2 |
| `后勤位` | -2 | +4 | +6 | +2 | +6 | +4 | -4 | -2 |
| `懦弱` | -10 | -2 | +8 | +16 | -4 | -6 | -4 | +4 |
| `莽撞` | +14 | +2 | -8 | -12 | -2 | -4 | +4 | +8 |
| `贪财` | -6 | -2 | -4 | -2 | +18 | -8 | +14 | +4 |
| `多疑` | -8 | +2 | +6 | +4 | +2 | -4 | +8 | +6 |
| `仗义` | +4 | +8 | +2 | -8 | -6 | +16 | -8 | -6 |
| `背肥包` | -8 | -2 | +2 | +12 | +6 | -4 | +8 | +2 |
| `刚被卖过` | -14 | -8 | +8 | +8 | +4 | -10 | +10 | +6 |

同一角色多个词条相加后，每个行为的词条修正钳制到 `-24..28`。

## 10. 数值修正

### 10.1 生命

```text
if health <= 25:
  retreat_only_self +18
  hold_position +8
  full_follow -14
  panic_break +8
elif health <= 50:
  retreat_only_self +8
  hold_position +4
  full_follow -6
elif health >= 75:
  full_follow +5
```

### 10.2 压力

```text
stress_modifier = floor((stress - 50) / 10)
panic_break += stress_modifier * 4
retreat_only_self += stress_modifier * 3
full_follow -= max(stress_modifier, 0) * 2
```

压力低于 `25` 时：

```text
hold_position -3
full_follow +3
partial_follow +2
```

### 10.3 负重

```text
if load >= 70:
  retreat_only_self +12
  solo_loot -6
  full_follow -8
  steal_bag +4
elif load >= 50:
  retreat_only_self +6
  full_follow -4
```

### 10.4 信任

```text
trust_delta = trust - 50
full_follow += floor(trust_delta / 5)
partial_follow += floor(trust_delta / 10)
steal_bag -= floor(trust_delta / 8)
retreat_only_self -= floor(trust_delta / 10)
```

信任低于 `25` 时额外：

```text
full_follow -8
steal_bag +8
solo_loot +6
```

## 11. 局势修正

| 条件 | 修正 |
| --- | --- |
| `resource_value >= 70` | `solo_loot +14`，`steal_bag +6` |
| `high_value_loot_available` | `solo_loot +10`，`steal_bag +8` |
| `evac_window <= 30` | `retreat_only_self +14`，`full_follow -6` |
| `enemy_pressure >= 70` | `hold_position +8`，`retreat_only_self +8`，`panic_break +8` |
| `chaos >= 70` | `panic_break +10`，`steal_bag +8`，`full_follow -6` |
| 有同行角色倒地 | `rescue_target +12`，`steal_bag +8` |
| 玩家倒地 | `rescue_target +8`，低信任时 `retreat_only_self +8` |
| AI 自己在 `solo` | `solo_loot +8`，`full_follow -12` |
| AI 自己在 `disengaging` | `retreat_only_self +16`，`full_follow -14` |

## 12. 另一名 AI 的影响

MVP 只做轻量同伴影响：

```text
if other_ai.current_intent == full_follow:
  full_follow +4
  partial_follow +4
if other_ai.current_intent == retreat_only_self:
  retreat_only_self +5
  hold_position +3
if other_ai.current_intent == solo_loot:
  solo_loot +4
  steal_bag +4
if other_ai.is_down:
  rescue_target +6
```

后续可扩展 AI 之间信任关系，MVP 暂不需要。

## 13. 解释文本生成

每个修正项都生成 `DecisionFactor`，但 UI 只展示最有代表性的 `1..3` 条。

### 13.1 优先级

| 来源 | display_priority |
| --- | ---: |
| 倒地、濒死、撤离窗口低 | 100 |
| 当前牌信号 | 80 |
| 高价值资源、背肥包 | 70 |
| 词条 | 60 |
| 信任、压力 | 50 |
| 另一名 AI 影响 | 30 |
| 随机扰动 | 0，默认不显示 |

### 13.2 文案模板

```text
{name} 可能跟进：你打出了强攻信号，且他血量还撑得住。
{name} 大概率不撤：背包里有高价值货，且他有贪财词条。
{name} 想先撤：撤离窗口快关了，当前生命也偏低。
{name} 可能搜包：有人倒地，且局势很混乱。
{name} 犹豫：跟进和保守的权重很接近。
```

## 14. 最小测试场景

### 14.1 强攻不跟

输入：

- 玩家打出 `attack_push`
- AI 生命 `35`
- AI 压力 `70`
- AI 词条 `懦弱`
- trust `40`

期望：

- `full_follow` 不是最高。
- `hold_position` 或 `retreat_only_self` 更高。
- 解释包含生命低、压力高或懦弱。

### 14.2 肥资源诱发单走

输入：

- 玩家打出 `scramble_loot`
- 节点 `resource_value = 85`
- AI 词条 `贪财`
- trust `42`

期望：

- `solo_loot` 权重明显上升。
- 解释包含资源肥和贪财。

### 14.3 低撤离窗口诱发独撤

输入：

- 玩家打出 `escape_first`
- `evac_window = 20`
- AI `load = 75`
- AI 背包价值高

期望：

- `retreat_only_self` 最高。
- 解释包含撤离窗口低和背包重。

### 14.4 仗义救援

输入：

- 玩家打出 `rear_guard`
- 一名队友倒地
- AI 词条 `仗义`
- trust `70`

期望：

- `rescue_target` 进入前两名。
- 若 `rescue_target` 最高，解释包含仗义和倒地队友。

## 15. 实现验收

- AI 响应服务对同一输入和同一随机种子输出一致。
- 每个候选行为都保留完整因素列表。
- UI 能显示最高行为和主要 `1..3` 条原因。
- 强信任不保证跟随，只提高跟随权重。
- 贪财、高压力、低撤离窗口能稳定推动不同 AI 做出不同选择。
- AI 响应服务不读取场景节点，不直接修改 `RunState`。
