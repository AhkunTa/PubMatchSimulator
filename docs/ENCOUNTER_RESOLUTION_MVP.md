# 节点内结算 MVP

> 目标：定义单个事件节点中的回合状态机、结算顺序、敌方模板、资源掉落、抢包和节点结束条件。  
> 关联文档：[MVP](MVP.md) · [MVP 卡牌基础池](CARD_POOL_MVP.md) · [AI 响应权重 MVP](AI_RESPONSE_MVP.md) · [技术架构](SYSTEM_ARCHITECTURE.md)

## 1. 节点内目标

MVP 的事件节点不是完整战棋地图，而是一个 `2..5` 回合的半自动冲突。

每个节点必须回答：

- 玩家本回合做了什么。
- 两名 AI 队友是否配合、偏离、作恶或撤离。
- 敌方压力如何改变局势。
- 谁受伤、谁拿到物资、谁离队、谁结仇。
- 节点是否完成、撤退、失败或进入下一回合。

## 2. 回合状态机

```text
ENTER_NODE
→ ROUND_START
→ DRAW_CARDS
→ AI_PREVIEW
→ PLAYER_ACTION
→ AI_RESPONSE_LOCK
→ ENEMY_INTENT_LOCK
→ RESOLVE_POSITION
→ RESOLVE_COMBAT
→ RESOLVE_RESOURCE
→ RESOLVE_ESCAPE
→ APPLY_RELATION_AND_CHAOS
→ CHECK_END
→ ROUND_START / NODE_RESULT
```

UI 可以合并展示阶段，但规则层按以上顺序执行。

## 3. 输入与输出

```text
ResolutionInput
  run_snapshot
  encounter_state
  player_card
  player_shout_id
  ai_response_results[]
  enemy_intents[]
  rng_seed
```

```text
ResolutionResult
  round_index
  action_logs[]
  effect_logs[]
  state_delta
  explanations[]
  node_result: continue / success / retreat / evac_success / defeat
```

规则层输出 `state_delta`，表现层只播放和展示，不重新计算。

## 4. EncounterState

```text
EncounterState
  encounter_id
  node_type: battle / search / dispute / accident / evac / unknown
  round_index
  max_rounds
  objective_progress: 0..100
  enemy_pressure: 0..100
  resource_value: 0..100
  chaos: 0..100
  evac_window: 0..100
  actors[]
  enemies[]
  loot_points[]
  flags[]
```

## 5. ActorState

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
  position: front / mid / back / solo / disengaging / evacuated
  guard: 0..100
  suppression: 0..100
  inventory_value
  inventory_weight
  is_down
  current_intent
```

`guard` 和 `suppression` 是节点内临时值，每回合结束后按规则衰减。

## 6. 敌方模板

MVP 使用 3 个简化敌人，不做敌方手牌。

| id | 名称 | health | marksmanship | agility | 行为倾向 |
| --- | --- | ---: | ---: | ---: | --- |
| `enemy_rusher` | 近压手 | 65 | 48 | 62 | 优先攻击前线，敌方压力高时推进 |
| `enemy_shooter` | 枪手 | 55 | 72 | 42 | 优先压制我方中后线 |
| `enemy_looter` | 捡漏者 | 50 | 42 | 70 | 有倒地或高价值物资时抢包/撤退 |

### 6.1 敌方意图

| intent | 条件 | 效果 |
| --- | --- | --- |
| `enemy_attack_front` | 默认、我方前线有人 | 对前线造成伤害 |
| `enemy_suppress` | 敌方枪手存活 | 提高我方压力和压制 |
| `enemy_flank` | chaos >= 50 或我方后线肥包 | 攻击中后线或提高抢包风险 |
| `enemy_grab_loot` | 有倒地者或资源点暴露 | 抢走资源或转移掉落 |
| `enemy_retreat` | 敌方残血或节点目标完成 | 敌方压力下降，节点可能成功 |

敌方意图由固定权重选择，MVP 不需要完整 AI 服务。

## 7. 站位结算

站位从前到后为：

```text
front → mid → back → disengaging → evacuated
solo
```

### 7.1 移动规则

- `MoveSelf(+1)`：向前移动一段，最高到 `front`。
- `MoveSelf(-1)`：向后移动一段，最低到 `disengaging`。
- `solo` 角色不参与主战区协同。
- `disengaging` 角色本回合仍可能被打断。
- `evacuated` 角色离开节点，不再参与回合。

### 7.2 少打多压力

```text
active_allies = 我方未倒地且 position in front/mid/back 的人数
active_enemies = 敌方未倒地人数
outnumber_pressure = max(0, active_enemies - active_allies) * 8
```

`outnumber_pressure` 加到敌方伤害和我方压力变化中。

## 8. 战斗结算

### 8.1 伤害公式

```text
base_damage = effect_damage
+ floor(marksmanship * 0.12)
+ floor(agility * 0.05)
- floor(stress * 0.06)
- floor(target_guard * 0.35)
- floor(attacker_suppression * 0.25)
```

最终伤害钳制到：

```text
damage = clamp(base_damage, 0, 35)
```

目标生命变化：

```text
target.health = max(0, target.health - damage)
if target.health == 0:
  target.is_down = true
  target.position = front if target.position == front else mid
```

### 8.2 协同伤害

当玩家牌有协同条件时：

```text
follow_count = count(ai_response in full_follow / partial_follow)
full_follow_bonus = 1.0
partial_follow_bonus = 0.55
```

例如 `focus_target`：

```text
total_bonus_damage =
  full_follow_count * 9
  + partial_follow_count * floor(9 * 0.55)
```

### 8.3 压制

```text
target.suppression += suppression_amount
target.suppression = clamp(target.suppression, 0, 100)
```

压制效果：

- 被压制者本回合输出降低。
- 被压制者移动和抢包成功率降低。
- 回合结束时 `suppression -20`。

### 8.4 防护

```text
actor.guard += guard_amount
actor.guard = clamp(actor.guard, 0, 100)
```

防护效果只持续一回合。回合结束时 `guard = 0`。

## 9. 资源结算

### 9.1 资源点

```text
LootPoint
  id
  value_remaining
  weight_remaining
  risk: 0..100
  tags[]
```

MVP 每个节点最多 `1` 个主要资源点。

### 9.2 搜刮

```text
loot_amount =
base_loot
+ floor(actor.agility * 0.12)
- floor(actor.load * 0.08)
- floor(enemy_pressure * 0.05)
```

最终：

```text
loot_amount = clamp(loot_amount, 0, loot_point.value_remaining)
weight_gain = ceil(loot_amount / 3)
```

资源进入执行者个人背包。

### 9.3 丢包

```text
drop_value = min(requested_drop_value, actor.inventory_value)
actor.inventory_value -= drop_value
actor.inventory_weight -= ceil(drop_value / 2)
actor.load = max(0, actor.load - 20)
```

丢包后的节点掉落可被其他角色抢走。

## 10. 抢包结算

### 10.1 可抢目标

- 倒地角色。
- 撤离中角色。
- 同行且背包价值高的队友。
- 战场掉落包。

### 10.2 成功率

```text
steal_score =
45
+ floor(attacker.agility * 0.25)
+ floor(encounter.chaos * 0.15)
+ trait_bonus
+ target_down_bonus
- floor(target.agility * 0.20)
- floor(target.marksmanship * 0.10)
- nearby_guard_penalty
```

修正：

```text
trait_bonus:
  贪财 +10
  多疑 +6
  仗义 -10

target_down_bonus:
  target.is_down ? +25 : 0

nearby_guard_penalty:
  有仗义或断后角色在同区域 ? 12 : 0
```

判定：

```text
success = rng_roll(1..100) <= clamp(steal_score, 5, 95)
```

### 10.3 后果

成功：

- 攻击者获得 `min(35, target.inventory_value)` 物资。
- 目标物资减少相同数量。
- 玩家抢包时 `player_infamy +12`。
- 被抢者若存活，`trust -18`，`stress +10`。

失败：

- 攻击者压力 `+8`。
- 玩家失败时 `player_infamy +6`。
- 目标若存活，`trust -10`。
- chaos `+6`。

## 11. 撤退与撤离

### 11.1 撤退推进

```text
escape_progress_gain =
card_escape_amount
+ floor(actor.agility * 0.12)
- floor(actor.load * 0.10)
- floor(enemy_pressure * 0.06)
+ cover_bonus
```

角色撤退进度达到 `30`：

```text
position = disengaging
```

达到 `60`：

```text
position = evacuated
is_evacuated = true
```

MVP 可把撤退进度存在临时字段：

```text
escape_progress_by_actor_id{}
```

### 11.2 撤离窗口

每回合结束：

```text
evac_window -= 6
evac_window -= floor(threat_level / 25)
evac_window -= 5 if chaos >= 70 else 0
```

`evac_window <= 0` 时：

- 新的撤离推进收益减半。
- 敌方更容易追击。
- 玩家未撤离且路线结束时进入失败判定。

## 12. 关系、压力和混乱

### 12.1 压力变化

```text
stress_delta =
damage_taken / 2
+ outnumber_pressure / 2
+ 8 if ally_down_this_round
+ 6 if betrayed_or_stolen
- 6 if node_objective_progress >= 100
- 4 if hold_ground_played
```

### 12.2 信任变化

| 条件 | trust delta |
| --- | ---: |
| 玩家喊救援并实际救援 | +8 |
| 玩家喊撤并一起撤退 | +5 |
| 玩家喊跟我但独自搜刮/撤退 | -10 |
| 玩家抢该 AI 的包 | -18 |
| 玩家断后让 AI 成功撤退 | +10 |
| 玩家放弃倒地 AI | -12 |

### 12.3 恶名变化

| 条件 | player_infamy delta |
| --- | ---: |
| 抢包成功 | +12 |
| 抢包失败 | +6 |
| 假救援 | +14 |
| 丢下队友独撤 | +10 |
| 引怪卖人 | +16 |

### 12.4 混乱变化

```text
chaos_delta =
floor(enemy_pressure / 20)
+ 8 if steal_happened
+ 8 if panic_break_happened
+ 6 if ally_down_this_round
+ 6 if team_split
- 8 if objective_completed_cleanly
```

## 13. 节点目标

### 13.1 战斗节点

目标：

```text
objective_progress += damage_to_enemies * 0.6
objective_progress += suppression_to_enemies * 0.25
```

成功条件：

- `objective_progress >= 100`，或
- 敌方全部倒地/撤退。

### 13.2 搜索节点

目标：

```text
objective_progress += loot_gained * 0.8
objective_progress += 15 if enemy_pressure <= 30 after round
```

成功条件：

- 资源点被搜到 `70%` 以上，或
- 玩家选择撤退且至少带走 `40` 物资。

### 13.3 争执节点

目标：

```text
objective_progress += 20 if no steal this round
objective_progress += 15 if player keeps promise
objective_progress -= 20 if steal or betrayal happened
```

成功条件：

- `objective_progress >= 60` 后可离开。

争执节点不追求满进度，重点是关系和物资归属。

### 13.4 事故节点

目标：

```text
objective_progress += rescued_actor ? 35 : 0
objective_progress += escaped_danger ? 35 : 0
objective_progress += recovered_loot ? 20 : 0
```

成功条件：

- 处理主要事故，或
- 玩家安全撤出。

### 13.5 撤离节点

目标：

```text
objective_progress += player_escape_progress
```

成功条件：

- 玩家 `is_evacuated = true`。

## 14. 结束判定

按顺序检查：

1. 玩家生命为 `0` 且无人救援可达：`defeat`
2. 玩家已撤离：`evac_success`
3. 我方全部倒地或撤离失败：`defeat`
4. 节点目标完成且玩家未倒地：`success`
5. 玩家主动撤退成功：`retreat`
6. `round_index >= max_rounds`：根据玩家状态和目标进度判定 `success / retreat / defeat`
7. 否则：`continue`

## 15. 节点结果

### 15.1 success

- 应用节点奖励。
- 保留个人背包归属。
- 敌方压力下降。
- 回路线选择。

### 15.2 retreat

- 玩家和同行者离开节点。
- 未带走的掉落留在节点历史，不进入收益。
- 可能增加威胁或混乱。
- 回路线选择或进入撤离结算。

### 15.3 evac_success

- 本局结束。
- 只结算已撤离角色身上的物资。
- 展示抢包、丢包、背刺和放弃队友记录。

### 15.4 defeat

- 本局失败。
- 可记录事故时间线。
- MVP 可用弹窗结算，不必做完整结算场景。

## 16. 最小可玩节点

第一版建议只实现一个固定节点：

```text
encounter_id: warehouse_test
node_type: search
max_rounds: 4
resource_value: 80
enemy_pressure: 45
chaos: RunState.chaos
evac_window: RunState.evac_window
enemies:
  enemy_rusher
  enemy_shooter
  enemy_looter
loot_point:
  value_remaining: 90
  weight_remaining: 30
```

它必须能验证：

- 玩家强攻但 AI 不跟，形成 `2v3` 或 `1v3` 压力。
- 玩家搜刮时，贪财 AI 可能单走。
- 有人倒地后，救援和搜包都可能发生。
- 玩家可以丢包提高撤退稳定度。
- 玩家或 AI 可以带货撤离。

## 17. 实现验收

- 同一输入和随机种子得到相同 `ResolutionResult`。
- 回合结算输出完整 `action_logs[]` 和 `effect_logs[]`。
- 伤害、压制、搜刮、抢包、撤退都通过统一管线写入 `state_delta`。
- 任何角色倒地后，其背包仍可被抢。
- 玩家撤离后只结算玩家背包收益。
- 节点失败、撤退、成功和撤离成功都有明确分支。
- UI 不直接修改结算数值，只提交 `player_card` 和 `player_shout_id`。
