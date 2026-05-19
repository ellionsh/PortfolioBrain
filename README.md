# PortfolioBrain

> 一个真正属于你的智能个人资产管理大脑。

<p align="center">
  <img src="site/logo.svg" width="140" alt="PortfolioBrain Logo" />
</p>

<p align="center">
  <strong>多账户 · 多资产 · 多币种 · 自动现金流 · AI 智能分析 · Dashboard 可视化 · 移动端 App</strong>
</p>

<p align="center">
  <a href="https://github.com/ellionsh/PortfolioBrain">GitHub</a> ·
  <a href="https://.github.io/PortfolioBrain">文档网站</a> ·
  <a href="#快速开始">快速开始</a>
</p>

## 简介

PortfolioBrain 是面向个人投资者的全栈资产管理系统，提供：

- 多账户：银行、券商、保险等资产类型
- 多资产：存款、理财、保险、股票、基金等
- 多币种：CNY / USD / HKD / EUR
- 自动现金流引擎：利息、付息、赎回、缴费等未来现金流生成
- DeepSeek Agent：自然语言查询、自动生成 SQL、自动操作资产
- Dashboard 可视化：资产结构、币种敞口、现金流、期限结构、净值曲线
- Flutter 移动端：随时查看资产与 AI 对话
- 自动任务系统：每日净值更新、现金流生成、到期提醒
- REST API：供前端与移动端使用

这是一个可长期维护、可扩展、可自托管的个人资产管理平台。

## 系统架构

```text
User
 ├─ Web Dashboard（Streamlit）
 ├─ Mobile App（Flutter）
 ├─ Web API（Flask）
 └─ DeepSeek Agent
      ├─ SQL Skill → MySQL（12 张表）
      └─ Operation Skill → AssetOperator
```

- 数据层：MySQL + 数据视图
- 逻辑层：AssetOperator + CashflowEngine
- AI 层：DeepSeek Chat + Tool Calling
- UI 层：Dashboard + Flutter App + Web

## 核心功能

### 🏦 多账户 / 多资产 / 多币种
支持银行存款、理财产品、保险、股票、基金等多种资产类型。

### 💰 自动现金流引擎
自动生成利息、付息、赎回、缴费等未来现金流。

### 🤖 DeepSeek Agent
通过自然语言查询资产、现金流、风险和期限结构。
支持自动生成 SQL、执行分析和解释结果。

### 📊 Dashboard 可视化
可视化展示资产结构、币种敞口、未来现金流、期限结构和净值曲线。

### 📱 Flutter 移动端
移动端随时查看资产、现金流、理财产品与 AI 对话。

### 🔄 自动任务系统
支持定时任务：

| 时间   | 任务         |
| ------ | ------------ |
| 06:00  | 更新净值     |
| 06:10  | 生成现金流   |
| 06:20  | 到期提醒     |

## 快速开始
```bash
1. 克隆仓库
    git clone https://github.com/yourname/PortfolioBrain.git
    cd PortfolioBrain
2. 安装依赖
    pip install -r requirements.txt
3. 初始化数据库
    mysql -u root -p < db/schema_mysql.sql
4. 启动 Web API
    python web/app.py
5. 启动 Dashboard
    streamlit run dashboard/dashboard.py
6. 启动移动端（可选）
    flutter run
```

### 认证与安全（API）

默认开启 Token 认证（适合公网部署）：

- 设置环境变量：
  - `PB_AUTH_SECRET`：JWT 密钥（务必设置为强随机字符串）
  - `PB_REQUIRE_AUTH=true`（默认）
  - `PB_AUTH_EXPIRES_MINUTES=720`（可选）
  - `PB_ALLOW_REGISTER=true`（可选，允许注册）
- 依赖注意：必须使用 `PyJWT` 包；若误装了 `jwt` 包会导致 `jwt.encode` 不存在（建议 `pip uninstall jwt` 后安装 `PyJWT`）
- 登录获取 Token：`POST /login`（或启用注册：`POST /register`）
- 在请求头携带：`Authorization: Bearer <token>`

### 任务配置（可选）

- `PB_FUND_NAV_RETRY_ATTEMPTS`：基金净值获取失败时的重试次数（默认 3）
- `PB_FUND_NAV_RETRY_BASE_SECONDS`：每次重试的基础等待秒数（默认 2，实际等待=基础秒数×第几次重试）

管理员用户创建脚本（兼容保留，建议用统一 CLI）：

- `python scripts/create_admin.py --username admin`

用户管理脚本（兼容保留，建议用统一 CLI）：

- `python scripts/manage_users.py list`
- `python scripts/manage_users.py deactivate --username alice`
- `python scripts/manage_users.py activate --username alice`
- `python scripts/manage_users.py promote --username alice`
- `python scripts/manage_users.py demote --username alice`

重置密码脚本（兼容保留，建议用统一 CLI）：

- `python scripts/reset_password.py --username alice`

统一管理 CLI（推荐）：

- `python scripts/admin_cli.py create-admin --username admin`
- `python scripts/admin_cli.py list`
- `python scripts/admin_cli.py deactivate --username alice`
- `python scripts/admin_cli.py activate --username alice`
- `python scripts/admin_cli.py promote --username alice`
- `python scripts/admin_cli.py demote --username alice`
- `python scripts/admin_cli.py reset-password --username alice`
## 目录结构

```text
PortfolioBrain/
  agent/              # DeepSeek Agent
  core/               # 资产操作层 + 现金流引擎
  dashboard/          # Streamlit Dashboard
  db/                 # MySQL 连接 + schema
  migrate/            # Excel → MySQL 迁移器
  tasks/              # 自动任务系统
  web/                # REST API
  site/               # 官方网站
  docs/               # 文档网站（mkdocs）
  frontend/           # Flutter App
```

## 文档

完整文档请查看 `docs/`，或访问：

https://yourname.github.io/PortfolioBrain

## 技术栈

- Python
- MySQL
- Flask
- Streamlit
- Flutter
- DeepSeek Chat
- mkdocs-material
- Docker（可选）

## 许可协议

MIT License

## 致谢

感谢 DeepSeek、Streamlit、Flutter、MySQL 等优秀开源项目。

如果你喜欢这个项目，欢迎点一个 ⭐ 支持一下！
