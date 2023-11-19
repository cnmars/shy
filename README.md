# shy (server of hysteria2)
一个基于hysteria2核心的多用户后端框架, 欢迎大佬对接和优化

## 一键部署
```
bash <(curl -Ls https://raw.githubusercontent.com/ppoonk/shy/main/scripts/install.sh)
```
## 配置文件
路径`/usr/local/shy/`
```
panel:
  panelType: AirGo
  apiHost: http://127.0.0.1:8899
  nodeID: 4
  key: airgo
  duration: 60
tls:
  cert: t1.crt
  key: t1.key
udpIdleTimeout: 90s
ignoreClientBandwidth: true
```
- panelType：面板类型，目前仅对接了AirGo面板
- apiHost：面板地址
- nodeID：节点id
- key：前后端通信密钥
- duration：轮询时间间隔
- tls(cert,key)：ssl证书路径
- 更多配置参数同hysteria2官方：[hysteria2中文文档](https://v2.hysteria.network/zh/docs/getting-started/Installation/)

## 启动
`systemctl start shy`

TG群组：[https://t.me/AirGo_Group](https://t.me/AirGo_Group)