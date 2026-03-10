# Datasophon 服务端口汇总
http://192.168.0.84:8081/ddh/# 
admin
admin123
本文档汇总了 Datasophon 集群管理系统中所有服务的端口配置信息。
## 网络拓扑
| IP | HostName | Role |
|------|------|------|
| 192.168.0.84 | ddp01 | manager worker |
| 192.168.0.90 | ddp02 | worker |
| 192.168.0.91 | ddp03 | worker |

## 基础服务端口

### Datasophon API
| 端口 | 协议 | 说明 |
|------|------|------|
| 8081 | HTTP | API 服务默认端口 |
| /ddh | - | Context Path |

### Datasophon Worker
| 端口 | 协议 | 说明 |
|------|------|------|
| 2551 | - | Worker 默认端口 |

## Hadoop 生态

### HDFS (Hadoop 3.3.6)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| NameNode | 8020 | RPC | NameNode RPC 通信端口 |
| NameNode | 9870 | HTTP | NameNode Web UI |
| NameNode | 1026 | HTTP | DataNode 地址 |
| DataNode | 8010 | RPC | DataNode 数据传输 |
| DataNode | 1025 | HTTP | DataNode HTTP 地址 |
| JournalNode | 8485 | RPC | JournalNode 通信端口 |
| JournalNode | 8480 | HTTP | JournalNode Web UI |
| ZKFC | 8019 | RPC | ZKFC 通信端口 |
| NameNode JMX | 27001 | JMX | NameNode JMX 监控端口 |
| DataNode JMX | 27002 | JMX | DataNode JMX 监控端口 |
| JournalNode JMX | 27003 | JMX | JournalNode JMX 监控端口 |
| ZKFC JMX | 27004 | JMX | ZKFC JMX 监控端口 |

### YARN (Hadoop 3.3.6)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| ResourceManager | 8030 | RPC | ApplicationMaster 通信 |
| ResourceManager | 8031 | RPC | NodeManager 通信 |
| ResourceManager | 8032 | RPC | 客户端 RPC 通信 |
| ResourceManager | 8088 | HTTP | ResourceManager Web UI |
| NodeManager | 45454 | RPC | NodeManager 地址 |
| NodeManager | 8042 | HTTP | NodeManager Web UI |
| HistoryServer | 19888 | HTTP | JobHistory Web UI |
| ResourceManager JMX | 9323 | JMX | ResourceManager JMX 监控 |
| NodeManager JMX | 9324 | JMX | NodeManager JMX 监控 |
| HistoryServer JMX | 9325 | JMX | HistoryServer JMX 监控 |

## 存储与数据库

### ZooKeeper (3.8.4)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| ZkServer | 2181 | TCP | 客户端连接端口 |
| ZkServer | 2888 | TCP | 集群内部通信端口 (Leader 选举) |
| ZkServer | 3888 | TCP | 集群内部选举端口 |
| ZkServer JMX | 7000 | JMX | JMX 监控端口 |

### HBase (2.4.16)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| HMaster | 16000 | RPC | HBase Master RPC |
| HMaster | 16010 | HTTP | HBase Master Web UI |
| HMaster | 16030 | HTTP | HBase Master REST |
| RegionServer | 16020 | RPC | RegionServer RPC |
| RegionServer | 16030 | HTTP | RegionServer Web UI |
| Master JMX | 16100 | JMX | HMaster JMX 监控 |
| RegionServer JMX | 16101 | JMX | RegionServer JMX 监控 |

### Hive (3.1.3)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| HiveServer2 | 10000 | TCP | JDBC 连接端口 |
| HiveServer2 | 10002 | HTTP | HiveServer2 Web UI |
| HiveMetaStore | 9083 | TCP | Metastore Thrift 服务 |
| HiveServer2 JMX | 11000 | JMX | HiveServer2 JMX 监控 |
| HiveMetaStore JMX | 12000 | JMX | Metastore JMX 监控 |

### Kafka (2.4.1)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| KafkaBroker | 9092 | TCP | Kafka 服务端口 |
| KafkaBroker JMX | 9991 | JMX | Kafka JMX 监控 |

### Doris (2.0.7)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| DorisFE | 8030 | HTTP | FE HTTP 端口 |
| DorisFE | 9030 | TCP | FE MySQL 协议端口 |
| DorisFE | 9020 | TCP | FE Thrift RPC 端口 |
| DorisFE | 9010 | TCP | FE EditLog 端口 |
| DorisFE JMX | 18030 | JMX | FE JMX 监控 |
| DorisFEObserver | 18031 | JMX | Observer JMX 监控 |
| DorisBE | 9060 | TCP | BE Admin 端口 |
| DorisBE | 8060 | TCP | BE RPC 端口 |
| DorisBE | 18040 | HTTP | BE WebServer 端口 |
| DorisBE JMX | 18040 | JMX | BE JMX 监控 |

### ElasticSearch (7.16.2)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| ElasticSearch | 9200 | HTTP | REST API 端口 |
| ElasticSearch | 9300 | TCP | 集群通信端口 |
| EsExporter | 9114 | HTTP | ES Exporter 指标导出 |

## 实时计算

### Kyuubi (1.7.4)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| KyuubiServer JMX | 10019 | JMX | Kyuubi JMX 监控 |

### Trino (367)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| TrinoCoordinator | 8086 | HTTP | Coordinator Web UI |
| TrinoCoordinator | 8087 | JMX | Coordinator JMX 监控 |
| TrinoWorker | 8089 | JMX | Worker JMX 监控 |

### StreamPark (2.1.1)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| StreamPark | 10000 | HTTP | StreamPark Web UI |
| StreamPark JMX | 10086 | JMX | 监控端口 |

## 调度与管理

### DolphinScheduler (3.1.8)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| ApiServer | 12345 | HTTP | API Server |
| MasterServer | 5679 | TCP | Master 服务 |
| MasterServer JMX | 5679 | JMX | Master 监控 |
| WorkerServer | 1235 | TCP | Worker 服务 |
| WorkerServer JMX | 1235 | JMX | Worker 监控 |
| AlertServer | 50053 | TCP | Alert 服务 |

## 监控与告警

### Prometheus (2.17.2)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| Prometheus | 9090 | HTTP | Prometheus Web UI |

### Grafana (9.1.6)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| Grafana | 3000 | HTTP | Grafana Web UI |

### AlertManager (0.23.0)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| AlertManager | 9093 | HTTP | AlertManager Web UI |

## 安全与权限

### Ranger (2.1.0)
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| RangerAdmin | 6080 | HTTP | Ranger Admin Web UI |
| RangerAdmin JMX | 6081 | JMX | Ranger JMX 监控 |

### Kerberos
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| KDC | 88 | TCP/UDP | Kerberos 认证服务 |
| kadmin | 749 | TCP | Kerberos 管理服务 |

## 其他服务

### Redis
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| Redis | 7000 | TCP | Redis master服务 |
| Redis | 7001 | TCP | Redis slave服务 |
| Redis Exporter | 9120 | HTTP | Redis 指标导出 (Master) |
| Redis Exporter | 9121 | HTTP | Redis 指标导出 (Worker) |

### MinIO
| 角色 | 端口 | 协议 | 说明 |
|------|------|------|------|
| MinIO | 9000 | HTTP | MinIO API |
| MinIO | 9001 | HTTP | MinIO Console |

## 数据库端口

### MySQL
| 端口 | 协议 | 说明 |
|------|------|------|
| 3306 | TCP | MySQL 数据库服务 |

## 端口规划建议

### 核心服务端口范围
- **Hadoop 生态**: 8000-9999
- **JMX 监控端口**: 7xxx, 9xxx, 10xxx, 11xxx, 12xxx, 16xxx, 18xxx
- **Web UI 端口**: 3000-10000
- **RPC 服务端口**: 8000-9000

### 防火墙配置建议
- 开放所有服务端口用于集群内部通信
- Web UI 端口开放给管理网络
- JMX 监控端口开放给监控服务器
- 数据库端口严格限制访问源

## 注意事项

1. **端口冲突**: 在部署前请确保端口没有被其他服务占用
2. **安全加固**: 生产环境建议修改默认端口
3. **防火墙规则**: 根据网络安全需求配置防火墙规则
4. **高可用配置**: HA 配置下需要开放多个节点的相同端口

## 更新日志

- 2026-03-05: 移除 Flink JobManager/TaskManager (项目未定义角色)、Spark3、Kyuubi JDBC 端口、SeaTunnel、KingbaseES、DMDB
- 2026-02-06: 初始版本创建,基于 DDP-1.2.2 版本
