# 关键词中英对照速查表

游戏设定相关概念的统一术语，供设计文档、数据文件、代码注释参考。

---

### 存档系统

| 中文 | 英文 | 说明 |
|------|------|------|
| 存档 | save | 游戏进度存储 |
| 槽位 | save slot | 存档位，如 slot_0 ~ slot_4 |
| 地图 | map | 底板 + 房间布局 + 可能被地图保存的一切信息 |

---

### 游戏基础

| 中文 | 英文 | 说明 |
|------|------|------|
| 旧日档案馆 | old archives | 游戏全称 |
| 地图编辑器 | map editor | 编辑地图（底板、房间等） |

---

### 资源与因子

| 中文 | 英文 | 数据键 / 说明 |
|------|------|---------------|
| 因子 | factor | 复数 factors |
| 认知 | cognition | factors.cognition |
| 计算 | computation | factors.computation |
| 意志 | willpower | factors.willpower |
| 权限 | permission | factors.permission |
| 信息 | info | currency.info |
| 真相 | truth | currency.truth |

---

### 人员

| 中文 | 英文 | 数据键 / 说明 |
|------|------|---------------|
| 研究员 | researcher | personnel.researcher |
| 劳动力 | labor | personnel.labor（当前版本暂未使用） |
| 被侵蚀 | eroded | personnel.eroded |
| 调查员 | investigator | personnel.investigator |
| 住房 | housing | 1 研究员需 1 住房 |
| 英杰 | hero | 特殊单位，不占研究员/调查员名额 |
| 管理员 | administrator | 玩家扮演的英杰 |

---

### 房间与区域

| 中文 | 英文 | 说明 |
|------|------|------|
| 空间单位 | space unit / unit | 1 单位 = 5 网格；简称「单位」 |
| 研究区 | research area | 建设于图书室/机房/资料库/教学室，产出因子 |
| 造物区 | creation area | 建设于实验室/推理室，消耗意志产出权限/信息 |
| 生活区 | living area | 建设于宿舍，提供住房 |
| 事务所 | office | 建设于事务所遗址 |
| 宿舍 | dormitory | 可建设生活区，3 单位提供 4 住房 |
| 空房间 | empty room | 可改造为造物区房间 |
| 改造 | remodel | 空房间→实验室/推理室等 |
| 清理 | clean | 未清理房间需先清理才能建设 |
| 档案馆核心 | archive core | 消耗计算因子提供庇护 |

---

### 房间类型（RoomType）

| 中文 | 英文 | 说明 |
|------|------|------|
| 图书室 | library | 研究区→认知 |
| 机房 | server room | 研究区→计算 |
| 教学室 | classroom | 研究区→意志 |
| 资料库 | archive | 研究区→权限 |
| 实验室 | lab | 造物区→权限 |
| 推理室 | reasoning | 造物区→信息 |
| 事务所遗址 | office site | 可建设事务所 |
| 宿舍 | dormitory | 可建设生活区 |
| 空房间 | empty room | 可改造 |

---

### 侵蚀与庇护

| 中文 | 英文 | 说明 |
|------|------|------|
| 文明 | civilization | 与神秘对应 |
| 神秘 | mystery | 与文明对应 |
| 侵蚀 | erosion | 神秘侵蚀 |
| 侵蚀预测 | erosion forecast | 未来 3 个月侵蚀 |
| 庇护 | shelter | 文明的庇佑 |
| 庇护等级 | shelter level | 核心出力 1～4 级 |
