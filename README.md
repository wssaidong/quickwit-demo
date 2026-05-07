# Quickwit Demo

🚀 基于 [Quickwit](https://github.com/quickwit-oss/quickwit) 云原生搜索引擎的运行示例集合。

Quickwit 是一个专为可观测性设计的开源搜索引擎（Elasticsearch/Loki/Datadog 的替代方案），支持日志、追踪和即将支持的指标。

## 功能特性

- 🔍 全文搜索与聚合查询
- 📊 Elasticsearch 兼容 API
- ☁️ 云存储优化（S3/Azure/GCS）
- 🐳 Docker 一键部署
- ⚡ 亚秒级搜索性能

## 快速开始

### 方式一：Docker 一键运行（推荐）

```bash
./run-demo.sh
```

### 方式二：手动安装

```bash
# 1. 安装 Quickwit
curl -L https://install.quickwit.io | sh

# 2. 进入安装目录
cd ./quickwit-*/

# 3. 启动服务
./quickwit run

# 4. 在另一个终端创建索引并导入数据
./quickwit index create --index-config ../quickwit-demo/stackoverflow-index-config.yaml
curl -O https://quickwit-datasets-public.s3.amazonaws.com/stackoverflow.posts.transformed-10000.json
./quickwit index ingest --index stackoverflow --input-path ./stackoverflow.posts.transformed-10000.json --force

# 5. 执行搜索
./quickwit index search --index stackoverflow --query "search AND engine"
```

## 示例索引：StackOverflow 数据

使用 StackOverflow 10,000 条问答数据演示全文搜索能力。

### 数据格式

每条文档包含：
- `title` - 问题标题（支持全文搜索）
- `body` - 问题正文（支持全文搜索）
- `creationDate` - 创建时间（用于时间范围查询）

### 索引配置

```yaml
# stackoverflow-index-config.yaml
version: 0.8
index_id: stackoverflow

doc_mapping:
  field_mappings:
    - name: title
      type: text
      tokenizer: default
      record: position
      stored: true
    - name: body
      type: text
      tokenizer: default
      record: position
      stored: true
    - name: creationDate
      type: datetime
      fast: true
      input_formats:
        - rfc3339
      fast_precision: seconds
  timestamp_field: creationDate

search_settings:
  default_search_fields: [title, body]
```

## 搜索示例

### 基本搜索

```bash
# 搜索包含 "search" 和 "engine" 的文档
curl "http://localhost:7280/api/v1/stackoverflow/search?query=search+AND+engine"

# 指定字段搜索
curl "http://localhost:7280/api/v1/stackoverflow/search?query=title:elasticsearch"
```

### 聚合查询

```bash
# 统计最热门的标签
curl -XPOST "http://localhost:7280/api/v1/stackoverflow/search" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": "type:question",
    "max_hits": 0,
    "aggs": {
      "top_tags": {
        "terms": {
          "field": "tags",
          "size": 10
        }
      }
    }
  }'
```

### JSON 格式查询

```bash
curl -XPOST "http://localhost:7280/api/v1/stackoverflow/search" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": "rust",
    "max_hits": 20,
    "sort": ["-score"]
  }'
```

### 运行所有搜索示例

```bash
./search-examples.sh
```

## 项目结构

```
quickwit-demo/
├── README.md                        # 本文件
├── stackoverflow-index-config.yaml  # StackOverflow 索引配置
├── run-demo.sh                      # 一键运行脚本
└── search-examples.sh              # 搜索示例集合
```

## API 端点

| 方法 | 端点 | 描述 |
|------|------|------|
| GET | `/api/v1/version` | 查看版本 |
| POST | `/api/v1/indexes` | 创建索引 |
| POST | `/api/v1/{index}/ingest` | 导入数据 |
| GET | `/api/v1/{index}/search` | 搜索 |
| DELETE | `/api/v1/indexes/{index}` | 删除索引 |

完整 API 文档：https://quickwit.io/docs/reference/rest-api

## 数据源

- 索引配置来源：[quickwit-oss/quickwit/config/tutorials/stackoverflow/](https://github.com/quickwit-oss/quickwit/tree/main/config/tutorials/stackoverflow)
- 数据集来源：StackOverflow 公开数据集（10,000 条 NDJSON）

## 参考资源

- [Quickwit 官方文档](https://quickwit.io/docs/)
- [Quickstart 教程](https://quickwit.io/docs/get-started/quickstart)
- [索引配置文档](https://quickwit.io/docs/configuration/index-config)
- [REST API 参考](https://quickwit.io/docs/reference/rest-api)
- [Docker 部署](https://quickwit.io/docs/get-started/installation#use-the-docker-image)

## License

Apache 2.0 - 与 Quickwit 相同
