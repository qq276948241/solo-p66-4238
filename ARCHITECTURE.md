# 校园二手教材交易平台 — 架构文档

## 1. 项目概览

基于 Sinatra + ActiveRecord + SQLite 的 RESTful JSON API，为高校二手教材交易提供后端服务。核心模块：

- **用户（User）**：学生注册 → 学校邮箱后缀自动认证 → API Token 鉴权
- **教材（Textbook）**：ISBN 录入、成色分级、课程名 + 价格区间筛选、状态流转
- **订单（Order）**：买卖双方下单 → 双方确认收货 → 双方互评（1-5 星）
- **收藏（Favorite）**：认证用户收藏 / 取消收藏 / 查看收藏列表

```
project66/
├── app.rb                      # Sinatra 应用入口 + 全局 before filter + 异常处理
├── config.ru                   # Rack 启动入口
├── Rakefile                    # 数据库迁移任务
├── Gemfile                     # 依赖声明
├── db/
│   ├── campus_textbook.db      # SQLite 数据库文件
│   ├── migrate/                # 5 个迁移（6_create_favorites 为收藏扩展）
│   └── seeds.rb                # 种子数据：4 所高校
├── models/                     # ActiveRecord 模型层（纯数据 + 校验）
│   ├── school.rb
│   ├── user.rb
│   ├── textbook.rb
│   ├── order.rb
│   ├── review.rb
│   └── favorite.rb
├── helpers/                    # Sinatra helpers（请求级工具，感知 HTTP）
│   └── auth.rb
├── services/                   # 业务服务层（跨 Model 协作，无 HTTP 感知）
│   └── favorite_service.rb
└── routes/                     # 路由层（参数解析 + 权限 + 调用 Model/Service + 响应）
    ├── users.rb
    ├── textbooks.rb
    ├── orders.rb
    └── favorites.rb
```

---

## 2. 分层架构 & 职责边界

```
┌────────────────────────────────────────────────────────────┐
│                        HTTP Request                         │
└────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────┐
│  app.rb — before filter                                     │
│  · 统一设置 content-type: application/json                 │
│  · URL 粒度的鉴权守卫（authenticate! / authorize_verified!）│
│  · 全局异常映射（RecordNotFound→404，RecordInvalid→422）    │
└────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────┐
│  routes/*.rb — 路由层                                       │
│  · 解析 JSON 请求体 / URL 参数                              │
│  · 调用 helpers 做细粒度权限检查（"只能修改自己发布的教材"） │
│  · 调用 Service / Model 执行业务                            │
│  · 组装 JSON 响应体 + 设置 HTTP 状态码                      │
└────────────────────────────────────────────────────────────┘
            │                               │
            ▼                               ▼
┌──────────────────────────┐    ┌───────────────────────────┐
│  helpers/auth.rb         │    │  services/*.rb            │
│  · authenticate!         │    │  · 业务跨模型时的封装     │
│  · authorize_verified!   │    │    （如 FavoriteService   │
│  · resolve_viewer        │    │    同时操作 Favorite +    │
│  · favorite_service()    │    │     Textbook 两个表）     │
│                          │    │  · enrich 收藏状态到 JSON  │
└──────────────────────────┘    └───────────────────────────┘
            │                               │
            └───────────────┬───────────────┘
                            ▼
                ┌────────────────────────┐
                │  models/*.rb            │
                │  · 表结构映射           │
                │  · 关联（belongs_to 等）│
                │  · 字段校验             │
                │  · 纯数据序列化 as_json │
                │  · 领域方法（如          │
                │    buyer_confirm!）     │
                └────────────────────────┘
                            │
                            ▼
                ┌────────────────────────┐
                │  SQLite (ActiveRecord) │
                └────────────────────────┘
```

**关键原则**：

- **Model 不感知当前用户**：`as_json` 永远返回纯数据，不接受 `current_user` 参数。收藏状态等"视图态"由 Service 层在返回路由层时注入。
- **Service 不感知 HTTP**：返回纯数组 / 对象，由路由层负责翻译成 HTTP 状态码和 JSON 格式。
- **Helper 只做请求级别的事**：鉴权、从请求头里取用户、构造 Service 实例，不写业务逻辑。
- **before filter 里只做路由匹配级别的守卫**："是否需要登录？是否需要认证？"细粒度的"是否是本人？"写在具体路由里。

---

## 3. 各模块详解

### 3.1 学校（School）

**文件**：[models/school.rb](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/school.rb)

| 字段 | 说明 |
|---|---|
| `name` | 学校名称 |
| `email_suffix` | 学校邮箱后缀（如 `pku.edu.cn`），唯一索引 |

- 种子数据在 [db/seeds.rb](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/db/seeds.rb)，启动后执行 `rake db:seed` 写入 4 所高校。
- 通过 `has_many :users` 反查本校学生。
- 被 [models/user.rb#L39-L48](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/user.rb#L39-L48) 里的 `auto_verify_school` 回调查询，匹配邮箱后缀则自动把用户标记 `verified = true`。

### 3.2 用户（User）

**文件**：[models/user.rb](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/user.rb)

| 字段 | 说明 |
|---|---|
| `name` | 昵称 |
| `email` | 邮箱，注册时与 School.email_suffix 匹配 |
| `password_digest` | BCrypt 哈希，`has_secure_password` 提供 |
| `school_id` | 关联学校，未匹配时为 NULL |
| `verified` | 是否已通过学校邮箱认证（核心权限开关） |
| `api_token` | 登录后作为 Bearer Token 使用，`SecureRandom.hex(16)` 生成 |

**注册流程（[routes/users.rb#L9-L27](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/routes/users.rb#L9-L27)）**：

```
用户提交 { name, email, password }
        │
        ▼
  User.new → before_validation :auto_verify_school
        │
        ├── email 后缀匹配 School.email_suffix → verified = true, school_id = <id>
        └── 不匹配                              → verified = false, school_id = nil
        │
        ▼
  before_create :generate_api_token（生成一次性 Token 随注册响应返回）
```

**登录流程（[routes/users.rb#L29-L38](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/routes/users.rb#L29-L38)）**：

```
User.authenticate(email, password) → BCrypt 校验 → 成功则返回 user（含 api_token）
```

**权限矩阵**（由 [helpers/auth.rb](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/helpers/auth.rb) 和 app.rb before filter 共同实现）：

| 能力 | 未登录 | 已登录未认证 | 已登录已认证（verified=true） |
|---|---|---|---|
| 浏览学校列表 | ✅ | ✅ | ✅ |
| 浏览教材（GET） | ✅ | ✅ | ✅ |
| 注册 / 登录 | ✅ | ✅ | ✅ |
| 查看教材详情 | ✅ | ✅ | ✅（下架的只有卖家自己能看） |
| 发布教材 | ❌ | ❌ | ✅ |
| 修改 / 删除自己教材 | ❌ | ❌ | ✅ |
| 下单 / 订单操作 | ❌ | ❌ | ✅ |
| 收藏 / 取消收藏 | ❌ | ❌ | ✅ |
| 查看自己收藏列表 | ❌ | ❌ | ✅ |

### 3.3 教材（Textbook）

**文件**：[models/textbook.rb](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/textbook.rb)

| 字段 | 说明 |
|---|---|
| `title` | 书名 |
| `isbn` | ISBN 编号（未强制唯一，同一本书可多人发布） |
| `original_price` | 原价 |
| `selling_price` | 售价 |
| `condition_level` | 成色：0 全新 / 1 九成新 / 2 八成新 / 3 一般 / 4 较差 |
| `course_name` | 所属课程名（用于筛选） |
| `description` | 描述 |
| `seller_id` | 发布者 FK |
| `status` | 状态：`available`（在售，默认）/ `sold`（已售） |

**状态过滤**（全链路一致策略）：

| 场景 | 是否过滤 available | 例外 |
|---|---|---|
| 教材列表 `Textbook.filter` | ✅（硬编码） | — |
| 教材详情 `GET /api/textbooks/:id` | ✅ | 卖家本人能看已下架 |
| 收藏列表 `FavoriteService#list` | ✅（硬编码） | — |
| 新增加收藏 `FavoriteService#add` | ✅（拒绝收藏已下架） | — |
| 下单 `Order.textbook_must_be_available` | ✅（Model 校验） | — |
| 修改 / 删除教材 | 不基于 available 过滤 | 已售教材禁止修改删除 |

**筛选接口**（[routes/textbooks.rb#L2-L14](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/routes/textbooks.rb#L2-L14)）：

```
GET /api/textbooks?course_name=高等数学&min_price=10&max_price=50
```

### 3.4 收藏（Favorite）

**文件**：
- Model：[models/favorite.rb](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/favorite.rb)
- Service：[services/favorite_service.rb](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/services/favorite_service.rb)
- Routes：[routes/favorites.rb](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/routes/favorites.rb)

| 字段 | 说明 |
|---|---|
| `user_id` + `textbook_id` | 联合唯一索引（同一用户对同一教材只能收藏一次） |

**为什么单独抽 Service**：收藏操作跨越 User / Favorite / Textbook 三个模型，且需要把"当前用户是否收藏"这种视图态注入到教材 JSON 响应里。这部分逻辑放在路由层会让 textbooks.rb 膨胀（重构前的问题），放在 Model 层又会让 as_json 耦合 current_user。所以抽到 Service：

| 方法 | 做什么 |
|---|---|
| `FavoriteService#list` | 查用户收藏 + 过滤 available + 预加载 seller |
| `FavoriteService#add(id)` | 校验教材在售 → 创建 Favorite → 返回 `[success, favorite, textbook, error_msg]` |
| `FavoriteService#remove(id)` | 查找并删除 Favorite |
| `FavoriteService#enrich(json_hash, textbook)` | 对单条教材 JSON 追加 `favorited: true/false` |
| `FavoriteService#enrich_collection(rel)` | 批量 enrich |

### 3.5 订单（Order） & 评价（Review）

这是系统最复杂的业务流程，单独用第 4 章详细展开。

- **Order Model**：[models/order.rb](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/order.rb)
- **Review Model**：[models/review.rb](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/review.rb)
- **Order Routes**：[routes/orders.rb](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/routes/orders.rb)

---

## 4. 订单全流程详解（核心业务）

### 4.1 状态机

订单有 4 种状态，严格按顺序流转（见 [models/order.rb#L13](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/order.rb#L13) 的 `STATUS_FLOW`）：

```
          买家下单              买家确认收货              卖家确认发货
  (初始) ───────────► pending ─────────────────► buyer_confirmed ──────────────► seller_confirmed
                                                                                      │
                                                                                      │  try_complete!
                                                                                      ▼
                                                                    双方都确认后自动： textbook.status = sold
                                                                                    order.status  = completed
                                                                                    order.completed_at = now
                                                                                      │
                                                                                      ▼
                                                                                  互评窗口开启
                                                                                  买卖双方各可写一条 Review
```

> **关键约束**：`buyer_confirm!` 只接受 `pending → buyer_confirmed`，`seller_confirm!` 只接受 `buyer_confirmed → seller_confirmed`。谁先点都行，只是字段含义上"买家确认收货，卖家确认发货"语义更清晰。两边都点完的一瞬间自动把订单推到 `completed` 并把教材标记为 `sold`。

### 4.2 数据模型

**Order 字段**：

| 字段 | 说明 |
|---|---|
| `textbook_id` | FK 到教材（创建时校验必须 available） |
| `buyer_id` / `seller_id` | FK 到用户（buyer_id 不能等于 seller_id） |
| `status` | pending / buyer_confirmed / seller_confirmed / completed |
| `buyer_confirmed_at` | 买家点确认的时间 |
| `seller_confirmed_at` | 卖家点确认的时间 |
| `completed_at` | 双方都确认后自动写入 |

**Review 字段**：

| 字段 | 说明 |
|---|---|
| `order_id` + `reviewer_id` | 联合唯一（每人每单只能评一次） |
| `reviewee_id` | 被评价人，自动取订单的另一方 |
| `rating` | 1-5 星 |
| `comment` | 文字评价，可选 |

Review 有两条 Model 校验：
- `order_must_be_completed`：订单必须是 completed 状态
- `reviewer_must_be_participant`：评价人必须是买卖双方之一

### 4.3 时序图（Sequence Diagram）

```
┌───────┐        ┌──────────┐        ┌───────┐        ┌───────┐        ┌──────────┐
│ 买家  │        │ API 网关 │        │ Order │        │ 卖家  │        │ Textbook │
└───┬───┘        └────┬─────┘        └───┬───┘        └───┬───┘        └────┬─────┘
    │  下单 textbook=2  │                  │                  │                  │
    │──────────────────►│                  │                  │                  │
    │                   │  POST /api/orders│                  │                  │
    │                   │─────────────────►│                  │                  │
    │                   │                  │ 校验：             │                  │
    │                   │                  │ · textbook必须available │              │
    │                   │                  │ · buyer != seller │                  │
    │                   │   status = p     │                  │                  │
    │                   │◄─────────────────┤                  │                  │
    │    201 订单创建   │                  │                  │                  │
    │◄──────────────────┤                  │                  │                  │
    │                   │                  │                  │                  │
    │  买方确认收货     │                  │                  │                  │
    │──────────────────►│                  │                  │                  │
    │                   │POST buyer_confirm│                  │                  │
    │                   │─────────────────►│                  │                  │
    │                   │                  │ status = bc      │                  │
    │                   │                  │ buyer_confirmed_at=now              │
    │                   │                  │ 检查 seller_confirmed_at？→ 空       │
    │                   │   等待卖方确认   │                  │                  │
    │◄──────────────────┤                  │                  │                  │
    │                   │                  │                  │                  │
    │                   │                  │                  │  卖方确认发货     │
    │                   │                  │                  │◄─────────────────┤
    │                   │                  │                  │  POST seller_confirm              │
    │                   │                  │◄─────────────────┤                  │
    │                   │                  │ status = sc      │                  │
    │                   │                  │ seller_confirmed_at=now              │
    │                   │                  │ 两端都非空？→ 是   │                  │
    │                   │                  │──────────────────────────────────────►│
    │                   │                  │      try_complete! │                  │
    │                   │                  │                  │                  │ status = sold
    │                   │   status = completed               │                  │
    │◄──────────────────┤◄─────────────────┤                  │                  │
    │  双方已确认，订单完成 │               │                  │                  │
    │                   │                  │                  │                  │
    │  给卖家打 5 星     │                  │                  │                  │
    │──────────────────►│                  │                  │                  │
    │                   │POST /orders/1/reviews(rating=5)     │                  │
    │                   │─────────────────►│                  │                  │
    │                   │                  │ 校验：             │                  │
    │                   │                  │ · order.completed │                  │
    │                   │                  │ · reviewer唯一     │                  │
    │                   │                  │ · reviewee=seller  │                  │
    │                   │   评价成功       │                  │                  │
    │◄──────────────────┤                  │                  │                  │
    │                   │                  │                  │  给买家打 4 星     │
    │                   │                  │                  │─────────────────►│
    │                   │                  │                  │POST /orders/1/reviews(rating=4)
    │                   │                  │◄─────────────────┤                  │
    │                   │  评价成功       │                  │                  │
    │◄───────────────────────────────────────┤                  │                  │
```

### 4.4 涉及的代码位置速查表

| 环节 | 路由层 | 模型层 |
|---|---|---|
| 下单校验 `buyer != seller` | — | [order.rb#L51-L53](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/order.rb#L51-L53) |
| 下单校验 `textbook.available?` | — | [order.rb#L55-L58](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/order.rb#L55-L58) |
| 下单接口 | [orders.rb#L2-L19](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/routes/orders.rb#L2-L19) | — |
| 买家确认 | [orders.rb#L32-L42](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/routes/orders.rb#L32-L42) | [order.rb#L15-L19](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/order.rb#L15-L19) |
| 卖家确认 | [orders.rb#L44-L54](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/routes/orders.rb#L44-L54) | [order.rb#L21-L25](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/order.rb#L21-L25) |
| 自动完成 + 教材标记售 | — | [order.rb#L44-L49](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/order.rb#L44-L49) |
| 写评价（含 reviewee 反推导） | [orders.rb#L56-L79](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/routes/orders.rb#L56-L79) | [review.rb#L6-L31](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/review.rb#L6-L31) |
| 查看订单评价（仅参与方） | [orders.rb#L81-L85](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/routes/orders.rb#L81-L85) | — |

---

## 5. 鉴权机制

### 5.1 Bearer Token 鉴权

所有需要登录的接口从 HTTP Header 中取 `Authorization: Bearer <api_token>`，流程在 [helpers/auth.rb#L2-L7](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/helpers/auth.rb#L2-L7)：

1. 正则去掉 `Bearer ` 前缀拿到 token 字符串
2. `User.find_by(api_token: token)` 查用户
3. 查不到 → halt 401 `未登录` / `Token无效`

> Token 是注册时生成的 `SecureRandom.hex(16)`，**当前设计没有过期机制**。如果未来要做退出登录 / 令牌刷新，可加 `expires_at` 字段或换成 JWT。

### 5.2 邮箱自动认证（注册时）

见 [models/user.rb#L39-L48](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/models/user.rb#L39-L48) `auto_verify_school`：

```ruby
domain = email.split('@').last
school = School.find_by(email_suffix: domain)
self.school_id = school.id   if school
self.verified  = !!school
```

> 设计上这是"后缀即认证"的简化方案。真实生产环境应该发一封带验证码的邮件到学生邮箱，用户点链接后再把 `verified` 置 true。

### 5.3 Before Filter 粒度映射

在 [app.rb#L28-L51](file:///D:/code/ai-prompt/solo-chrome-dev-F12/repos/repo66/project66/app.rb#L28-L51) 里定义：

| URL 模式 | HTTP 方法 | 拦截 | 说明 |
|---|---|---|---|
| `/api/textbooks` | GET | 放行 | 任何人可浏览 |
| `/api/textbooks` | 其它 | authenticate! + authorize_verified! | 发布需认证 |
| `/api/textbooks/*` | GET | 放行 | 详情可看 |
| `/api/textbooks/*` | 其它 | authenticate! + authorize_verified! | 修改删除需认证 |
| `/api/orders` + `/api/orders/*` | ALL | authenticate! | 所有订单操作需登录（通过后再到路由层里校验 verified） |
| 正则 `/api/(favorites\|textbooks/\d+/favorite)` | ALL | authenticate! + authorize_verified! | 收藏相关必须认证学生 |

> 注：`/api/orders` 这里只做了 authenticate，没有 authorize_verified —— 这是因为历史上订单流程里直接依赖了路由层的逻辑。实际测试时，未认证用户 token 无法通过下单接口（因为 POST /api/orders 的 before filter 只要求 authenticate），但具体路由中没有二次校验 verified。**建议新人在后续把订单路由的 before filter 也加上 authorize_verified!，或在下单路由里加 halt。**

---

## 6. 数据库迁移历史

| 序号 | 文件 | 建表 | 说明 |
|---|---|---|---|
| 1 | `001_create_schools` | schools | 高校邮箱后缀字典 |
| 2 | `002_create_users` | users | 学生用户 + api_token 索引 |
| 3 | `003_create_textbooks` | textbooks | 教材 + ISBN / 课程名 索引 |
| 4 | `004_create_orders` | orders | 订单 + 三方 FK 索引 |
| 5 | `005_create_reviews` | reviews | 评价 + (order_id, reviewer_id) 唯一索引 |
| 6 | `006_create_favorites` | favorites | 收藏 + (user_id, textbook_id) 唯一索引 |

迁移执行：

```bash
bundle exec rake db:create       # 创建 SQLite 文件
bundle exec rake db:migrate      # 顺序执行 db/migrate/*.rb
bundle exec rake db:seed         # 写入 seeds.rb 数据
```

---

## 7. 本地启动 & 调试

```bash
# 1. 安装依赖
bundle install

# 2. 初始化数据库（首次）
bundle exec rake db:create db:migrate db:seed

# 3. 启动服务（默认 4567）
bundle exec ruby app.rb -p 4567
# 或用 rackup（生产推荐）
bundle exec rackup -p 4567

# 4. 调试工具：看数据库
bundle exec rails dbconsole   # 或直接用 sqlite3 客户端
```

### 推荐的接口冒烟测试顺序（新人第一次跑时照这个走一遍）

1. 注册 → `POST /api/users/register` 用 `@pku.edu.cn` 邮箱 → 看响应 `verified: true`
2. 注册 → 用 `@gmail.com` 邮箱 → 看响应 `verified: false`
3. 登录 → `POST /api/users/login` 拿到 token
4. 用认证 token 发教材 → `POST /api/textbooks` → 返回 textbook.id
5. 用未认证 token 发教材 → 应返回 403
6. 列表 → `GET /api/textbooks` → 看到上一步的教材
7. 另一认证用户下单 → `POST /api/orders` → 返回 order.id（status=pending）
8. 买方确认 → `POST /api/orders/:id/buyer_confirm` → status=buyer_confirmed
9. 卖方确认 → `POST /api/orders/:id/seller_confirm` → status=completed，textbook.status=sold
10. 双方各打一条评价 → `POST /api/orders/:id/reviews`（各一次，再试第三次会报错重复）
11. 收藏 → `POST /api/textbooks/:id/favorite`，列表 → `GET /api/favorites`
12. 取消收藏 → `DELETE /api/textbooks/:id/favorite`

---

## 8. 常见扩展方向（留给接手的同学）

| 需求 | 建议改哪里 |
|---|---|
| Token 过期 / 退出登录 | User 加 `token_expires_at` 或改成 JWT |
| 邮箱真实认证 | User 加 `verification_token` / `verified_at`，注册后发邮件 |
| 密码重置 | 同邮箱认证，加 reset 表 + 邮件链接 |
| 课程名关联到 Course 表 | 新建 Course 模型，Textbook belongs_to :course |
| 分页 | `Textbook.filter` 返回值后加 `.page(params[:page]).per(20)`（加 kaminari gem） |
| 教材图片 | Textbook 加 images 表，用 Active Storage 或对象存储 |
| 聊天 / 议价 | 新建 Conversation + Message 表，关联 buyer_id/seller_id |
| 收藏状态缓存 `favorited` 查询 | `enrich_collection` 里现在是 N+1，可以改成先查 `Favorite.where(user_id:..., textbook_id: ids)` 一次性取出来做 Hash 映射 |
| 订单流程改为买家先确认付款再发货 | 加 status = `paid` / `shipped`，引入支付回调 |
