# 部署指南（Deploy）
PortfolioBrain 支持多种部署方式。
---
## 1. Docker 部署
docker-compose up -d
## 2. 文档网站部署（GitHub Pages）
mkdocs gh-deploy
## 3. 服务器部署
推荐：
Nginx 反向代理
Supervisor / systemd 管理进程
后台运行 Web API + Scheduler
## 4. 移动端部署
可直接打包为：
Android APK
iOS IPA（需 Mac）