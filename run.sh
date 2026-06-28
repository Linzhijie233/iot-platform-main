#!/usr/bin/env bash
# iot-platform 速桥云一键(重)部署引导脚本
# 容器约束: 最小镜像, 有 python3/bash, 无 curl/wget/git, 无 IPv6 路由, 仅白名单网络
# 用法(网页终端): 见 README / DEPLOYMENTS.md 的一行命令
set -e

PORT="${PORT:-30749}"
NODE_VER="v20.18.0"
WORK="/root/iot-platform"
TARBALL="/root/iot-src-nosecret.tar.gz"
RAW="https://raw.githubusercontent.com/Linzhijie233/iot-platform-main/main/iot-src-nosecret.tar.gz"
JSD="https://cdn.jsdelivr.net/gh/Linzhijie233/iot-platform-main@main/iot-src-nosecret.tar.gz"
NODE_URL="https://registry.npmmirror.com/-/binary/node/${NODE_VER}/node-${NODE_VER}-linux-x64.tar.gz"
NODE_DIR="/opt/node-${NODE_VER}-linux-x64"
NPM_MIRROR="https://registry.npmmirror.com"

echo "================ IoT 重新部署开始 (PORT=${PORT}) ================"

# 强制 IPv4 下载, 多源回退 (python3, 无需 curl/wget)
pydl() {  # pydl OUT URL1 [URL2 ...]
  local out="$1"; shift
  python3 - "$out" "$@" <<'PY'
import sys, socket, ssl, urllib.request
_orig = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: [x for x in _orig(*a, **k) if x[0] == socket.AF_INET]
out, urls = sys.argv[1], sys.argv[2:]
ctx = ssl._create_unverified_context()
for u in urls:
    try:
        req = urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0'})
        data = urllib.request.urlopen(req, timeout=180, context=ctx).read()
        if len(data) < 100:
            raise Exception('内容过小 %d 字节' % len(data))
        open(out, 'wb').write(data)
        print('    下载成功 %.2f MB  <- %s' % (len(data) / 1048576, u))
        sys.exit(0)
    except Exception as e:
        print('    源失败 (%s): %s' % (u, e))
sys.exit(1)
PY
}

untar() {  # untar TARBALL DEST   (python3, 不依赖系统 tar)
  python3 - "$1" "$2" <<'PY'
import sys, tarfile
with tarfile.open(sys.argv[1]) as t:
    t.extractall(sys.argv[2])
print('    解压完成 ->', sys.argv[2])
PY
}

# 所有 node/npm/pnpm 优先走 IPv4, 规避容器无 IPv6 路由的 ENETUNREACH
export NODE_OPTIONS="--dns-result-order=ipv4first"

# ---- 1) Node ----
if ! command -v node >/dev/null 2>&1 && [ ! -x "${NODE_DIR}/bin/node" ]; then
  echo "[1/4] 安装 Node ${NODE_VER} (npmmirror) ..."
  pydl /opt/node.tar.gz "$NODE_URL"
  untar /opt/node.tar.gz /opt
fi
for b in node npm npx; do ln -sf "${NODE_DIR}/bin/$b" "/usr/local/bin/$b" 2>/dev/null || true; done
export PATH="${NODE_DIR}/bin:/usr/local/bin:${PATH}"
echo "    node $(node -v)"

# ---- 2) 取源码 ----
echo "[2/4] 下载并解压源码包 ..."
pydl "$TARBALL" "$RAW" "$JSD"
rm -rf "$WORK"
untar "$TARBALL" /root
[ -d "$WORK" ] || { echo "!! 解压后未找到 $WORK"; exit 1; }
echo "    源码就绪: $WORK"

# ---- 3) npm 镜像 ----
npm config set registry "$NPM_MIRROR" >/dev/null 2>&1 || true

# ---- 4) 执行项目部署脚本 (端口 ${PORT}) ----
echo "[3/4] 安装依赖 + 构建 + pm2 启动 (deploy.sh) ..."
cd "$WORK"
chmod +x deploy.sh 2>/dev/null || true
PORT="$PORT" bash deploy.sh

echo "[4/4] 部署引导结束。pm2 进程 'iot' 监听 0.0.0.0:${PORT}"
echo "================ 完成 ================"
echo "容器内自测:  python3 -c \"import urllib.request as u;print(u.urlopen('http://127.0.0.1:${PORT}/',timeout=5).status)\""
echo "公网访问:    http://219.133.7.139:${PORT}"
