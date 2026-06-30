# 卡牌系统

> 文档版本：0.1  
> 目标：定义长期版卡牌系统，将卡牌拆分为战斗卡牌和事件卡牌，并给出可用 JSON 数据结构。  
> 关联文档：[MVP 卡牌基础池](CARD_POOL_MVP.md) · [AI 响应权重 MVP](AI_RESPONSE_MVP.md) · [节点内结算 MVP](ENCOUNTER_RESOLUTION_MVP.md) · [好感度与招募系统](AFFINITY_AND_RECRUITMENT.md)

## 1. 系统定位

《野排模拟器》的卡牌不是传统意义上的“全队命令”。卡牌代表玩家在当前局面中拿得出手的一种行动、话术、战术倾向或临场选择。

长期版卡牌分成两套：

1. **战斗卡牌**：在节点回合中由玩家主动打出，主要影响战斗、站位、救援、搜刮、撤离和 AI 响应。
2. **事件卡牌**：在特殊事件、事故、好感事件或局外招募事件中出现，主要影响剧情分支、关系、资源分配和长期状态。

两套卡牌共享效果系统和标签规范，但拥有不同的牌库、触发时机和展示方式。

## 2. 设计边界

- 战斗卡牌解决“这一回合我怎么行动”。
- 事件卡牌解决“这个突发局面我怎么处理”。
- 喊话可以继续作为轻量附加选择，不必全部做成卡。
- 角色专属牌和招募队友牌是扩展来源，不是基础系统前提。
- 卡牌不能保证 AI 服从，只能提供信号、收益、代价和关系变化。

## 3. 统一数据模型

所有卡牌都使用可序列化数据维护。建议先使用 JSON，后续再按需要转换为 Godot `Resource`。

```json
{
  "id": "combat_focus_fire",
  "name": "集火目标",
  "card_set": "base",
  "card_kind": "combat",
  "type": "attack",
  "rarity": "common",
  "owner_rule": "player",
  "tags": ["attack", "signal_focus_fire", "risk_overextend"],
  "play_window": "encounter_turn",
  "target_rule": "enemy_lowest_health",
  "cost": {
    "stamina": 0,
    "focus": 0,
    "loot": 0
  },
  "requirements": {
    "positions": ["front", "mid", "back"],
    "run_tags_any": [],
    "requires_recruited_teammate": null
  },
  "effects": [
    {
      "op": "deal_damage",
      "target": "selected_enemy",
      "amount": 10
    },
    {
      "op": "add_ai_signal",
      "signal": "signal_focus_fire",
      "amount": 18
    }
  ],
  "ai_signal_tags": ["signal_focus_fire", "signal_attack"],
  "risk_tags": ["risk_overextend"],
  "preview_text": "标记一个低生命敌人。队友若跟进，会造成额外协同伤害。",
  "result_text_key": "card.combat_focus_fire.result"
}
```

## 4. 战斗卡牌

战斗卡牌在节点回合中进入手牌。玩家每回合通常打出 `1` 张，也可以通过角色能力、事件奖励或高阶专长改变出牌数。

### 4.1 战斗卡分类

| 类型 | 作用 | 示例 |
| --- | --- | --- |
| `attack` | 造成伤害、压制、推进、追击 | 强攻推进、集火目标 |
| `survival` | 防护、减压、撤退、断后 | 稳住阵脚、断后掩护 |
| `resource` | 搜刮、抢包、丢包、分配 | 趁乱搜刮、抢包夺货 |
| `support` | 救援、治疗、安抚、协同 | 战地处理、拉他一把 |
| `social` | 喊话强化、劝说、威慑、欺骗 | 跟我上、先撤再说 |
| `role` | 玩家角色专属行动 | 压制突入、现场分配 |
| `partner` | 招募队友或组合队伍提供 | 账算清楚、背我一程 |

### 4.2 战斗卡牌字段

```text
CombatCardDefinition
  id: String
  name: String
  card_kind: combat
  type: attack / survival / resource / support / social / role / partner
  card_set: base / role / partner / event_reward / challenge
  rarity: common / uncommon / rare / story
  play_window: encounter_turn / reaction / evacuation
  playable_positions[]
  target_rule
  cost
  requirements
  effects[]
  ai_signal_tags[]
  risk_tags[]
  preview_text
  result_text_key
```

### 4.3 战斗牌库规则

基础规则：

```text
base_deck = 基础战斗卡
role_cards = 当前玩家角色解锁牌
partner_cards = 当前固定队友提供牌
event_cards = 本局事件临时洗入牌
deck = base_deck + selected_role_cards + selected_partner_cards + event_cards
draw_count_per_round = 3
hand_limit = 5
play_count_per_round = 1
discard_after_play = true
reshuffle_when_deck_empty = true
```

构筑限制建议：

- 基础牌保证玩家永远有行动可选。
- 角色牌最多带 `3—5` 张，避免角色机制淹没基础玩法。
- 固定队友牌最多带 `1—2` 张，体现组队差异但不替代玩家角色。
- 事件临时牌应在本局或本节点结束后移除。

### 4.4 战斗卡 JSON 示例

```json
{
  "id": "combat_rear_guard",
  "name": "断后掩护",
  "card_kind": "combat",
  "type": "survival",
  "card_set": "base",
  "rarity": "common",
  "play_window": "encounter_turn",
  "playable_positions": ["front", "mid", "back"],
  "target_rule": "ally_disengaging",
  "cost": {
    "stamina": 5
  },
  "effects": [
    {
      "op": "gain_guard",
      "target": "self",
      "amount": 8
    },
    {
      "op": "advance_escape",
      "target": "target_ally",
      "amount": 18
    },
    {
      "op": "modify_actor_state",
      "target": "self",
      "state": "stress",
      "amount": 5
    }
  ],
  "ai_signal_tags": ["signal_cover", "signal_retreat"],
  "risk_tags": ["risk_low_reward"],
  "preview_text": "帮一名正在撤离的队友推进撤离，但自己压力上升。",
  "result_text_key": "card.combat_rear_guard.result"
}
```

## 5. 事件卡牌

事件卡牌不进入普通战斗手牌。它们由节点、事故、角色事件、好感事件、招募事件或局外大厅触发。

事件卡牌更像“可配置的事件选项”，但用卡牌数据维护，可以复用效果系统、标签、解锁条件和 UI 展示。

### 5.1 事件卡分类

| 类型 | 触发场景 | 示例 |
| --- | --- | --- |
| `accident` | 局内事故爆发 | 争抢物资、甩锅争吵 |
| `relationship` | 队友关系变化 | 私下劝说、当面道歉 |
| `recruitment` | 特殊 ID 招募 | 分账邀请、再排一把 |
| `loot_split` | 物资分配 | 公平分配、先拿后说 |
| `evacuation` | 撤离分歧 | 等他上车、关门跑路 |
| `story` | 角色专属事件 | 老周的规矩、夜眼的预警 |
| `camp` | 局外大厅事件 | 送物资、复盘事故 |

### 5.2 事件卡字段

```text
EventCardDefinition
  id: String
  name: String
  card_kind: event
  type: accident / relationship / recruitment / loot_split / evacuation / story / camp
  trigger
  requirements
  choices[]
  effects[]
  relationship_events[]
  preview_text
  result_text_key
```

事件卡可以有多个 `choices[]`。每个选择可以拥有独立要求、效果和风险。

```json
{
  "id": "event_split_loot_with_laozhou",
  "name": "老周要先分账",
  "card_kind": "event",
  "type": "recruitment",
  "trigger": {
    "window": "camp",
    "requires_teammate": "sp_laozhou",
    "requires_flags": ["escaped_together_twice"],
    "min_affinity": 60
  },
  "choices": [
    {
      "id": "fair_split",
      "text": "按规矩分",
      "requirements": {
        "loot_fund_min": 40
      },
      "effects": [
        {
          "op": "spend_meta_currency",
          "currency": "action_fund",
          "amount": 40
        },
        {
          "op": "modify_affinity",
          "target": "sp_laozhou",
          "amount": 8
        },
        {
          "op": "set_recruitment_state",
          "target": "sp_laozhou",
          "state": "recruited"
        }
      ],
      "relationship_events": [
        {
          "type": "promise_kept",
          "target_id": "sp_laozhou",
          "value": 40,
          "reason_key": "relationship.laozhou.fair_split"
        }
      ]
    },
    {
      "id": "empty_promise",
      "text": "下把一定补",
      "effects": [
        {
          "op": "modify_affinity",
          "target": "sp_laozhou",
          "amount": -4
        },
        {
          "op": "modify_grudge",
          "target": "sp_laozhou",
          "amount": 10
        }
      ],
      "relationship_events": [
        {
          "type": "promise_broken",
          "target_id": "sp_laozhou",
          "value": 10,
          "reason_key": "relationship.laozhou.empty_promise"
        }
      ]
    }
  ],
  "preview_text": "老周愿意再排，但要求先把上次那笔账算清楚。",
  "result_text_key": "event.split_loot_with_laozhou.result"
}
```

## 6. 效果系统

两套卡牌共享 `effects[]`。效果应保持小而可组合，避免每张卡硬编码逻辑。

### 6.1 基础效果枚举

```text
deal_damage(target, amount)
apply_suppression(target, amount)
move_actor(target, position_delta)
gain_guard(target, amount)
modify_actor_state(target, state, amount)
modify_run_state(state, amount)
loot(target, amount, weight)
steal_loot(source, target, amount)
drop_loot(target, amount, weight)
advance_escape(target, amount)
add_ai_signal(signal, amount)
add_intent_bias(target, intent, amount)
modify_trust(target, amount)
modify_resentment(target, amount)
modify_infamy(amount)
modify_affinity(target, amount)
modify_bond(target, amount)
modify_grudge(target, amount)
set_event_flag(flag)
set_recruitment_state(target, state)
add_temp_card(card_id, destination)
remove_temp_card(card_id)
```

### 6.2 效果执行原则

- UI 只预览效果，不直接修改状态。
- 结算服务负责应用效果和钳制数值。
- 关系类效果同时产出可读原因。
- 事件卡的选择结果必须进入对局记录或局外记录。
- 未识别的效果 `op` 应在加载时被校验出来，而不是运行时静默失败。

## 7. 标签系统

### 7.1 通用标签

| 标签 | 用途 |
| --- | --- |
| `attack` | 进攻类 |
| `defense` | 防守类 |
| `loot` | 资源类 |
| `rescue` | 救援类 |
| `evacuation` | 撤离类 |
| `betrayal` | 作恶或背叛 |
| `promise` | 承诺相关 |
| `recruitment` | 招募相关 |
| `partner_combo` | 固定队友组合 |

### 7.2 AI 信号标签

沿用 [MVP 卡牌基础池](CARD_POOL_MVP.md) 的 `ai_signal_tags[]`，长期版可以新增：

| 标签 | 含义 |
| --- | --- |
| `signal_rescue` | 玩家准备救援 |
| `signal_share_loot` | 玩家愿意分配收益 |
| `signal_betrayal` | 玩家表现出背叛倾向 |
| `signal_wait_for_ally` | 玩家愿意等待队友 |
| `signal_partner_priority` | 玩家明显偏向固定队友 |

### 7.3 风险标签

长期版新增：

| 标签 | 含义 |
| --- | --- |
| `risk_partner_jealousy` | 随机队友可能不满固定队友待遇 |
| `risk_long_grudge` | 可能增加局外长期怨账 |
| `risk_recruit_fail` | 可能导致招募失败或冷却 |
| `risk_pair_conflict` | 固定队友之间可能冲突 |

## 8. 解锁与来源

| 来源 | 解锁内容 |
| --- | --- |
| 账号等级 | 基础战斗卡、通用事件卡 |
| 玩家角色熟练度 | 角色专属战斗卡、角色事件卡 |
| 特殊 ID 好感 | 队友支援卡、招募事件卡 |
| 固定队友默契 | 组合卡、双排/三排事件卡 |
| 路线主题 | 主题事故卡、主题资源卡 |
| 挑战模式 | 高风险变体卡 |

卡牌解锁以横向玩法为主，不直接堆永久伤害。

## 9. 数据文件建议

```text
data/cards/combat/base_cards.json
data/cards/combat/role_cards.json
data/cards/combat/partner_cards.json
data/cards/event/accident_cards.json
data/cards/event/recruitment_cards.json
data/cards/event/camp_cards.json
data/cards/tags.json
data/cards/effects_schema.json
```

每个 JSON 文件可以是数组，也可以按 `id` 建字典。实现上建议加载后统一建立 `id -> CardDefinition` 索引。

## 10. 代码模块建议

| 模块 | 职责 |
| --- | --- |
| `CardDatabase` | 加载、索引、校验全部卡牌 |
| `DeckService` | 构建战斗牌库、抽牌、弃牌、洗牌 |
| `CardRequirementService` | 判断卡牌和选项是否可用 |
| `CardEffectResolver` | 把 `effects[]` 应用到局内或局外状态 |
| `EventCardService` | 根据触发条件生成事件卡和选项 |
| `CardPreviewService` | 生成 UI 预览文本、风险提示、目标高亮 |
| `CardUnlockService` | 根据账号、角色、好感和挑战解锁卡牌 |

## 11. MVP 与长期版关系

[MVP 卡牌基础池](CARD_POOL_MVP.md) 仍是第一版实现范围。长期版卡牌系统不要求 MVP 立刻实现事件卡、构筑和队友牌。

MVP 保留：

- 固定 12 张基础战斗卡。
- 每回合抽 3、出 1。
- AI 只读取 `ai_signal_tags[]` 和局势状态。

Alpha 增加：

- 角色专属战斗卡。
- 少量事故事件卡。
- 卡牌 JSON 加载和校验。

Beta 增加：

- 招募队友牌。
- 双排/三排组合卡。
- 局外事件卡和招募事件卡。
