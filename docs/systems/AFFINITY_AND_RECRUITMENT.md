# 好感度与招募系统

> 文档版本：0.1  
> 目标：定义局外长期好感、特殊 ID 队友、招募、双排与三排的设计和代码落地方式。  
> 关联文档：[角色数值与成长](CHARACTER_AND_PROGRESSION.md) · [AI 响应权重 MVP](AI_RESPONSE_MVP.md) · [节点内结算 MVP](ENCOUNTER_RESOLUTION_MVP.md)

## 1. 系统定位

好感度系统服务于局外长期记忆，不替代局内的 `trust`、`resentment`、`stress` 和 `panic`。

- 局内关系描述“这一局里他现在信不信你、烦不烦你、怕不怕”。
- 局外好感描述“这个特殊角色长期怎么看你，愿不愿意再和你排”。
- 招募不是把 AI 变成稳定下属，而是把“路人队友”变成“愿意和你固定组队的麻烦熟人”。

特殊 ID 角色被招募后，可以在局外大厅选择一起双排；满足更高条件后，可以组建三排。固定队友仍保留私心、压力、误判和作恶倾向，只是初始信任、配合意愿、特殊事件和角色专属成长会发生变化。

## 2. 核心循环

```text
普通野排
→ 遇到特殊 ID 角色
→ 局内互动改变临时关系和局外好感
→ 触发角色好感事件
→ 达到招募条件
→ 招募为固定队友
→ 双排进入行动
→ 提升羁绊与队伍默契
→ 解锁三排候选、组合事件和专属卡牌
```

这个循环的重点不是“刷满数值”，而是让玩家记住某些队友：谁救过你、谁抢过你的包、谁被你卖过又回来报复、谁嘴很臭但关键时刻靠谱。

## 3. 特殊 ID 角色

特殊 ID 角色是有固定设定、固定头像/代号、长期档案和专属事件链的 AI 队友。普通 AI 使用“模板 + 随机昵称”生成，特殊 ID 使用 `special_teammate_id` 读取配置。

### 3.1 与普通 AI 的区别

| 项目 | 普通 AI | 特殊 ID |
| --- | --- | --- |
| 名字 | 模板昵称随机生成 | 固定代号和别名 |
| 局外记录 | 不保留 | 保留好感、招募状态、事件进度 |
| 事件 | 只触发通用事故 | 可触发专属好感事件 |
| 成长 | 单局状态为主 | 可解锁专属队友特性 |
| 招募 | 不可招募 | 达成条件后可招募 |

### 3.2 设计原则

- 特殊 ID 不应比普通 AI 全面更强，而应更有记忆点。
- 每名特殊 ID 至少有一个“好用的点”和一个“会出事的点”。
- 好感提升不应消除其人格缺陷，只是让玩家更容易预判和利用。
- 招募后依然可能和玩家冲突，否则会破坏野排主题。

## 4. 好感度结构

局外好感使用 `0—100`，但不单独决定一切。建议拆成三层数据：

| 字段 | 范围 | 说明 |
| --- | --- | --- |
| `affinity` | 0—100 | 长期好感，决定事件阶段和招募门槛 |
| `bond` | 0—100 | 组队默契，招募后增长，影响双排/三排配合 |
| `grudge` | 0—100 | 长期怨账，记录玩家反复卖人、抢包、食言 |

`affinity` 高但 `grudge` 也高时，角色可能愿意和玩家组队，但会触发“嘴硬、试探、报复、抢先声明规则”等事件。不要把关系压成单一正负值。

### 4.1 好感阶段

| 好感 | 阶段 | 表现 |
| --- | --- | --- |
| 0—19 | 拉黑边缘 | 出现时更可能拒绝合作、抢先撤离或嘲讽 |
| 20—39 | 记得你 | 会认出玩家，但不稳定 |
| 40—59 | 熟面孔 | 初始信任略高，可能触发小事件 |
| 60—79 | 愿意再排 | 可触发招募事件，双排初始默契提高 |
| 80—100 | 固定搭子 | 解锁高阶羁绊事件、组合牌或三排条件 |

### 4.2 长期怨账阶段

| 怨账 | 阶段 | 表现 |
| --- | --- | --- |
| 0—19 | 没放在心上 | 无明显负面 |
| 20—39 | 记小本 | 分配、救援、撤离事件中更敏感 |
| 40—69 | 不信你嘴 | 玩家喊话和承诺更容易被质疑 |
| 70—100 | 准备清算 | 触发专属冲突事件，招募和组队可能被锁定 |

## 5. 好感变化来源

好感变化必须来自可解释行为，结算时应展示 1—3 条原因。

| 行为 | `affinity` | `bond` | `grudge` | 说明 |
| --- | ---: | ---: | ---: | --- |
| 成功救援该角色 | +8 | +4 | -4 | 若救援失败但付出代价，也可给少量好感 |
| 履行“包归你”等承诺 | +6 | +3 | -3 | 需要结算层记录承诺 |
| 合作撤离且双方带出收益 | +5 | +5 | 0 | 招募后主要提升默契 |
| 抢该角色的包 | -10 | -6 | +14 | 若对方倒地或撤离中，怨账更高 |
| 说要救援却撤离 | -12 | -4 | +16 | 与喊话系统强绑定 |
| 卖人但全队成功撤离 | -4 | -2 | +8 | 角色可能承认结果，但记仇 |
| 让该角色拿到关键收益 | +7 | +2 | -2 | 适合物资欲高角色 |
| 遵守该角色的专属底线 | +5 | +3 | -5 | 由角色配置定义 |
| 触犯专属底线 | -8 | -3 | +12 | 例如抛弃新丁、浪费医疗包 |

好感变化建议每局对同一角色设置软上限，避免单局刷爆：

```text
per_run_affinity_gain_cap = 18
per_run_affinity_loss_cap = 24
per_run_grudge_gain_cap = 30
```

## 6. 招募设计

招募是一个局外事件，不是结算界面自动弹出按钮。玩家需要在局内与特殊 ID 形成足够故事，再在局外大厅触发招募剧情。

### 6.1 招募条件

基础条件：

- `affinity >= 65`
- `grudge <= 45`
- 至少共同成功撤离 `2` 次
- 完成该角色的 `recruitment_event`
- 玩家账号等级达到角色配置要求

部分角色可以有特殊条件，例如：

- 救援型角色要求玩家至少完成一次高风险救援。
- 贪财型角色要求玩家让出一次高价值物资。
- 莽撞型角色要求玩家和他完成一次正面突破。
- 记仇型角色要求玩家先完成“道歉/补偿”事件。

### 6.2 招募结果

招募成功后：

- 角色加入 `recruited_teammates`。
- 局外可选择其作为固定队友进入双排。
- 该角色解锁 `bond`、队友熟练度、专属事件链。
- 初始局内 `trust` 提高，但不会固定满值。
- 该角色更容易响应符合其性格的战斗卡和事件卡。

招募失败后：

- 不应永久关闭。
- 根据失败原因增加 `grudge` 或设置冷却。
- 下一次招募事件文案应承认前一次失败。

## 7. 双排与三排

### 7.1 双排

双排表示玩家带一名固定队友，再匹配一名随机 AI。

优势：

- 固定队友初始 `trust +10—20`。
- 与固定队友相关的事件预判更清楚。
- 可携带 1 张该队友的支援卡或组合卡。
- 结算后提升 `bond`。

代价：

- 随机 AI 可能对固定二人组产生疏离或嫉妒。
- 固定队友会要求玩家遵守更明确的底线。
- 玩家反复卖固定队友会造成更高长期怨账。

### 7.2 三排

三排表示玩家带两名固定队友进入行动。三排不是纯加强，应引入组合关系。

解锁条件建议：

- 至少招募 `2` 名特殊 ID。
- 两名队友分别 `bond >= 50`。
- 两名队友之间没有未解决的 `pair_conflict_lock`。
- 完成一次三排解锁事件。

三排优势：

- 初始队伍凝聚力更高。
- 可使用组合事件卡或组合被动。
- 队友间救援和掩护倾向提高。

三排风险：

- 两名固定队友可能互相看不惯。
- 玩家偏袒一方会让另一方积累长期怨账。
- 三排失败会产生更重的局外事件后果。

## 8. 角色 JSON 设计

特殊 ID 角色建议用 JSON 维护。Godot 可以先通过 `JSON.parse_string()` 加载字典，后续再转换为 `Resource`。

```json
{
  "id": "sp_laozhou",
  "display_name": "老周",
  "codename": "铁算盘",
  "archetype": "logistics_survivor",
  "rarity": "story",
  "unlock_rule": {
    "min_account_level": 2,
    "route_tags": ["market", "warehouse"],
    "encounter_weight": 12
  },
  "base_ai": {
    "template": "old_timer",
    "abilities": {
      "combat": [35, 55],
      "support": [30, 50],
      "scouting": [50, 70],
      "carrying": [70, 90],
      "discipline": [65, 85],
      "improvisation": [45, 65]
    },
    "drives": {
      "lootDrive": [65, 85],
      "survivalDrive": [60, 80],
      "egoDrive": [20, 40],
      "herdDrive": [35, 55],
      "riskAppetite": [25, 45],
      "blameTendency": [35, 60]
    }
  },
  "relationship": {
    "initial_affinity": 30,
    "initial_grudge": 0,
    "recruit_affinity": 65,
    "max_grudge_for_recruit": 45
  },
  "boundaries": [
    {
      "id": "no_waste_loot",
      "text": "不要无意义丢弃高价值物资",
      "on_respected": { "affinity": 4, "bond": 2 },
      "on_violated": { "affinity": -6, "grudge": 10 }
    }
  ],
  "recruitment_event": {
    "id": "recruit_laozhou_split_the_take",
    "required_flags": ["escaped_together_twice"],
    "choice_ids": ["fair_split", "promise_next_run", "mock_his_rules"]
  },
  "recruited_perks": [
    {
      "id": "settle_accounts",
      "name": "账算清楚",
      "effect_refs": ["reduce_greed_pressure_on_fair_split"]
    }
  ],
  "exclusive_cards": ["event_fair_split", "combat_cover_the_carrier"]
}
```

## 9. 存档结构

```json
{
  "special_teammates": {
    "sp_laozhou": {
      "met_count": 4,
      "runs_together": 3,
      "successful_extractions": 2,
      "affinity": 68,
      "bond": 22,
      "grudge": 15,
      "recruited": true,
      "recruitment_state": "recruited",
      "event_flags": [
        "first_met",
        "escaped_together_twice",
        "recruit_laozhou_complete"
      ],
      "cooldowns": {}
    }
  },
  "active_party": {
    "mode": "duo",
    "teammate_ids": ["sp_laozhou"]
  }
}
```

## 10. 代码模块建议

| 模块 | 职责 |
| --- | --- |
| `SpecialTeammateDatabase` | 读取特殊 ID JSON，提供查询和校验 |
| `RelationshipProfile` | 保存单名特殊 ID 的局外关系状态 |
| `AffinityService` | 根据结算事件计算好感、默契和怨账变化 |
| `RecruitmentService` | 判断招募条件、触发招募事件、写入招募状态 |
| `PartyService` | 管理单排、双排、三排队伍选择 |
| `EncounterSpawner` | 按权重把特殊 ID 混入野排候选 |
| `RunSummaryService` | 输出关系变化原因和结算文案 |

### 10.1 结算事件接口

好感服务不应直接读取战斗细节，而应消费统一的结算事件。

```text
RelationshipEvent
  type: rescue / abandon / steal_loot / promise_kept / promise_broken / extract_together / boundary_respected / boundary_violated
  actor_id: String
  target_id: String
  run_id: String
  value: int
  tags: String[]
  reason_key: String
```

## 11. MVP 与 Alpha 范围

MVP 暂不需要实现完整招募，但可以预留数据字段。

MVP 建议只做：

- 结算记录中保留特殊 ID 字段。
- 支持 1 名测试特殊 ID 的出现。
- 结算后显示好感变化文本。

Alpha 建议实现：

- 3 名特殊 ID。
- 招募 1 名固定队友。
- 双排模式。
- 每名特殊 ID 至少 3 个好感事件。

Beta 再实现：

- 三排模式。
- 固定队友之间的组合关系。
- 组合卡牌和组合事故。
