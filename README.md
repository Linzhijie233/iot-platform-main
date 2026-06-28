# iot-platform 速桥云一键部署

把 `iot-platform`（NestJS 单进程托管 UmiJS 前端 + `/api`）部署到速桥云容器。

- `iot-src-nosecret.tar.gz` — 无密钥源码包（已剔除 `node_modules` / `dist` / `.git` / `backend/.env` / 项目资料）
- `run.sh` — 引导脚本：python3 强制 IPv4 装 Node → 取源码 → 跑项目 `deploy.sh` → pm2 启动，监听 `0.0.0.0:30749`

## 在容器里部署（网页终端粘**一行**）

```
python3 -c "import socket,ssl,os,urllib.request as u;_o=socket.getaddrinfo;socket.getaddrinfo=lambda *a,**k:[x for x in _o(*a,**k) if x[0]==socket.AF_INET];c=ssl._create_unverified_context();open('/root/run.sh','wb').write(u.urlopen(u.Request('https://raw.githubusercontent.com/Linzhijie233/iot-platform-main/main/run.sh',headers={'User-Agent':'M'}),timeout=90,context=c).read());os.system('nohup bash /root/run.sh >/root/run.log 2>&1 &');print('STARTED -> tail -f /root/run.log')"
```

看进度：`tail -f /root/run.log`（约 3–8 分钟）。

容器内自测：

```
python3 -c "import urllib.request as u;print(u.urlopen('http://127.0.0.1:30749/',timeout=5).status)"
```

返回 `200` 即容器内部署成功。公网 `http://219.133.7.139:30749` 还取决于平台反向代理是否已把流量转发进本 Pod。

## 改端口

平台分配的服务端口若变化，部署前先 `export PORT=新端口`，或编辑 `run.sh` 顶部 `PORT=`。
