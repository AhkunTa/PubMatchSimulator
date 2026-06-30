# MVP 卡牌基础池

> 目标：把 `12` 张基础行动牌定义到可直接实现、可测试、可调数值的粒度。  
> 关联文档：[MVP](../core/MVP.md) · [节点内 3v3 半自动卡牌战基础设计](../superpowers/specs/2026-06-26-node-card-combat-design.md) · [AI 响应权重 MVP](AI_RESPONSE_MVP.md) · [节点内结算 MVP](ENCOUNTER_RESOLUTION_MVP.md)

## 1. 设计边界

MVP 卡牌不是全队命令。每张牌同时代表：

- 玩家本回合实际执行的动作。
- 队友观察到的战术信号。

玩家每回合默认打出 `1` 张主行动牌，并可选择 `1` 句喊话。MVP 暂不实现自由构筑、升级牌、角色专属牌、临时污染牌和复杂费用系统。

## 2. 通用牌字段

```text
CardDefinition
  id: String
  name: String
  type: attack / survival / resource / social
  playable_positions[]: front / mid / back / solo / disengaging
  target_rule: self / ally / enemy / downed_actor / loot_point / escape
  base_effects[]
  ai_signal_tags[]
  risk_tags[]
  preview_text: String
  result_text_key: String
```

### 2.1 基础效果枚举

```text
DealDamage(amount, target_rule)
ApplySuppression(amount, target_rule)
MoveSelf(position_delta)
MoveAlly(position_delta)
GainGuard(amount)
ReduceStress(amount, target_rule)
IncreaseStress(amount, target_rule)
Loot(amount, weight)
StealLoot(amount, target_rule)
DropLoot(amount, weight)
AdvanceEscape(amount)
ModifyTrust(amount, target_rule)
ModifyInfamy(amount)
AddIntentBias(action_id, amount, target_rule)
```

MVP 实现时可以先用字典承载效果，后续再抽成 Godot `Resource`。

## 3. 标签规范

### 3.1 AI 信号标签

| 标签 | 含义 |
| --- | --- |
| `signal_attack` | 玩家正在发起正面进攻 |
| `signal_suppress` | 玩家正在压制敌人，适合跟进或撤退 |
| `signal_focus_fire` | 玩家希望集中攻击同一目标 |
| `signal_reposition` | 玩家正在调整站位 |
| `signal_hold` | 玩家希望稳住局势 |
| `signal_retreat` | 玩家希望撤退或撤离 |
| `signal_cover` | 玩家正在掩护他人 |
| `signal_loot` | 玩家正在搜刮资源 |
| `signal_steal` | 玩家正在抢包或作恶 |
| `signal_drop_load` | 玩家选择牺牲收益换稳定 |
| `signal_follow_me` | 玩家希望队友跟进自己 |
| `signal_escape_now` | 玩家希望队友优先撤离 |

### 3.2 风险标签

| 标签 | 含义 |
| --- | --- |
| `risk_overextend` | 队友不跟时容易少打多 |
| `risk_noise` | 提高威胁或吸引敌人 |
| `risk_friendly_split` | 可能造成队伍分裂 |
| `risk_greed` | 刺激 AI 搜刮或抢包 |
| `risk_infamy` | 玩家恶名可能上升 |
| `risk_abandon` | 可能被理解为抛弃队友 |
| `risk_low_reward` | 当前回合收益低，可能引发不满 |

## 4. 基础牌组

### 4.1 进攻牌

| id | 名称 | 可用站位 | 主效果 | AI 信号 | 风险 |
| --- | --- | --- | --- | --- | --- |
| `attack_push` | 强攻推进 | `front`, `mid` | 对最危险敌人造成 `14` 伤害；自己向前移动 1 段；若至少 1 名队友跟进，额外造成 `8` 协同伤害 | `signal_attack`, `signal_follow_me` | `risk_overextend`, `risk_noise` |
| `suppress_fire` | 压制射击 | `front`, `mid`, `back` | 对敌方前线施加 `18` 压制；本回合敌方伤害总量 `-6`；自己压力 `+4` | `signal_suppress`, `signal_hold` | `risk_noise`, `risk_low_reward` |
| `focus_target` | 集火目标 | `front`, `mid`, `back` | 标记最低生命敌人；玩家造成 `10` 伤害；每名跟进队友额外造成 `9` 伤害 | `signal_focus_fire`, `signal_attack` | `risk_overextend` |
| `close_swap` | 逼近换位 | `mid`, `back` | 自己向前移动 1 段；若目标敌人被压制，造成 `12` 伤害；否则自己承受 `6` 反击伤害 | `signal_reposition`, `signal_attack` | `risk_overextend`, `risk_friendly_split` |

### 4.2 生存牌

| id | 名称 | 可用站位 | 主效果 | AI 信号 | 风险 |
| --- | --- | --- | --- | --- | --- |
| `hold_ground` | 稳住阵脚 | `front`, `mid`, `back` | 自己获得 `12` 防护；自己压力 `-8`；同行队友压力 `-4` | `signal_hold` | `risk_low_reward` |
| `fallback` | 暂时撤退 | `front`, `mid` | 自己后退 1 段；撤退推进 `+12`；若队友不撤，队伍分裂风险 `+8` | `signal_retreat`, `signal_escape_now` | `risk_abandon`, `risk_friendly_split` |
| `rear_guard` | 断后掩护 | `front`, `mid`, `back` | 自己获得 `8` 防护；一名撤退中队友撤退推进 `+18`；自己压力 `+5` | `signal_cover`, `signal_retreat` | `risk_low_reward` |

### 4.3 资源牌

| id | 名称 | 可用站位 | 主效果 | AI 信号 | 风险 |
| --- | --- | --- | --- | --- | --- |
| `scramble_loot` | 趁乱搜刮 | `mid`, `back`, `solo` | 从当前资源点获得 `30` 轻物资和 `10` 负重；若敌方未被压制，自己承受 `5` 风险伤害 | `signal_loot` | `risk_greed`, `risk_friendly_split` |
| `steal_bag` | 抢包夺货 | `front`, `mid`, `solo` | 从倒地或撤离中的目标抢走 `35` 物资；若目标清醒，按抢包公式判定；成功后恶名 `+12` | `signal_steal` | `risk_infamy`, `risk_greed` |
| `drop_load` | 丢包轻装 | `front`, `mid`, `back`, `disengaging` | 丢弃 `30` 物资并降低 `20` 负重；撤退推进 `+16`；被抢包倾向 `-10` | `signal_drop_load`, `signal_retreat` | `risk_low_reward` |

### 4.4 关系牌

| id | 名称 | 可用站位 | 主效果 | AI 信号 | 风险 |
| --- | --- | --- | --- | --- | --- |
| `follow_me` | 跟我上 | `front`, `mid` | 本回合队友 `full_follow` 和 `partial_follow` 权重 `+18`；若玩家没有进攻或推进，恶名 `+8` | `signal_follow_me`, `signal_attack` | `risk_infamy`, `risk_overextend` |
| `escape_first` | 先撤再说 | `front`, `mid`, `back` | 本回合队友撤退相关权重 `+18`；自己撤退推进 `+8`；背肥包 AI 额外更愿意独撤 | `signal_escape_now`, `signal_retreat` | `risk_abandon`, `risk_friendly_split` |

## 5. 喊话池

喊话不是牌，不进入牌库。玩家每回合最多选一句。

| id | 文案 | 权重修正 | 反噬条件 |
| --- | --- | --- | --- |
| `shout_follow` | 跟我！ | `full_follow +10`，`partial_follow +6` | 玩家选择资源或撤退牌时，`player_infamy +6` |
| `shout_retreat` | 撤了！ | `retreat_only_self +8`，`full_follow retreat +8` | 背肥包 AI 可能独撤 |
| `shout_rescue` | 我去救！ | `rescue_target +12`，目标信任预期 `+8` | 玩家未救援却搜刮或撤退时，`player_infamy +14` |
| `shout_take_point` | 你顶一下！ | `hold_position +8`，莽撞 AI `full_follow +6` | 低信任 AI 压力 `+6` |
| `shout_your_loot` | 包归你。 | `solo_loot +10`，`steal_bag -6` | 结算未分配物资时，目标信任 `-12` |
| `shout_cover_me` | 我断后。 | `retreat_only_self -8`，队友撤退推进预期 `+8` | 玩家没有掩护时恶名 `+10` |

## 6. 抽牌与弃牌规则

MVP 使用固定基础牌组，不洗入角色牌。

```text
deck = 12 张基础牌
draw_count_per_round = 3
hand_limit = 5
play_count_per_round = 1
discard_after_play = true
reshuffle_when_deck_empty = true
```

回合开始流程：

1. 若牌库不足抽牌数，先把弃牌堆洗回牌库。
2. 抽到 `3` 张，直到手牌达到上限 `5`。
3. 玩家选择 `1` 张牌。
4. 被打出的牌进入弃牌堆。
5. 未打出的手牌保留到下回合。

## 7. 实现验收

- 能从 12 张基础牌中抽出 3 张手牌。
- 每张牌都能生成预览文本：玩家效果、AI 信号、主要风险。
- 每张牌都能转换为统一 `base_effects[]`。
- AI 响应服务只读取 `ai_signal_tags[]` 和局势状态，不硬编码中文牌名。
- 打出 `follow_me` 但玩家没有进攻时，能记录恶名反噬。
- 打出 `steal_bag` 成功后，物资归属、恶名和目标关系都发生变化。
