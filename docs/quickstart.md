# 快速开始
## 1. 克隆仓库
`git clone https://github.com/yourname/PortfolioBrain`
`cd PortfolioBrain`
## 2. 安装依赖
`pip install -r requirements.txt`
## 3. 初始化数据库
`mysql -u root -p < db/schema_mysql.sql`
## 4. 启动 Web API
`python web/app.py`
## 5. 启动 Dashboard
`streamlit run dashboard/dashboard.py`
## 6. 启动移动端（可选）
`flutter run`
7. 导入 Excel 数据（可选）
将 Excel 文件放入：
`data/`
运行：
`python migrate/migrate_all.py`
8. 启动自动任务系统（可选）
`python tasks/scheduler.py`
你现在已经成功启动 PortfolioBrain。
