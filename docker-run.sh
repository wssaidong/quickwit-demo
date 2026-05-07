#!/bin/bash
#
# 使用 Docker Compose 启动 Quickwit Demo
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMPOSE_FILE="docker-compose.yml"
QW_VERSION=${QW_VERSION:-nightly}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Quickwit Demo - Docker Compose${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查 docker-compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}错误: docker-compose 未安装${NC}"
    exit 1
fi

# 确定 docker compose 命令
DOCKER_COMPOSE="docker-compose"
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
fi

# 启动服务
start_services() {
    echo -e "${YELLOW}启动 Quickwit 服务...${NC}"
    echo ""

    # 创建数据目录
    mkdir -p qwdata

    # 启动 quickwit（单独启动，kafka 和 grafana 可选）
    $DOCKER_COMPOSE up -d quickwit

    # 等待服务就绪
    echo -n "  等待 Quickwit 就绪"
    for i in {1..30}; do
        if curl -s http://localhost:7280/api/v1/version &>/dev/null; then
            echo ""
            echo -e "${GREEN}✓ Quickwit 已启动${NC}"
            break
        fi
        echo -n "."
        sleep 1
    done
}

# 创建索引
create_index() {
    echo ""
    echo -e "${YELLOW}创建索引...${NC}"

    # 下载索引配置（如果需要）
    if [[ ! -f "stackoverflow-index-config.yaml" ]]; then
        curl -sO https://raw.githubusercontent.com/quickwit-oss/quickwit/main/config/tutorials/stackoverflow/index-config.yaml
    fi

    # 检查索引是否已存在
    if curl -s http://localhost:7280/api/v1/indexes/stackoverflow &>/dev/null; then
        echo -e "${GREEN}✓ 索引已存在，跳过创建${NC}"
    else
        echo "  创建索引..."
        curl -s -XPOST http://localhost:7280/api/v1/indexes \
            -H "Content-Type: application/yaml" \
            --data-binary @./stackoverflow-index-config.yaml
        echo -e "${GREEN}✓ 索引创建完成${NC}"
    fi
}

# 导入数据
ingest_data() {
    echo ""
    echo -e "${YELLOW}导入数据...${NC}"

    DATA_FILE="stackoverflow.posts.transformed-10000.json"
    if [[ ! -f "$DATA_FILE" ]]; then
        echo "  下载数据集..."
        curl -sO https://quickwit-datasets-public.s3.amazonaws.com/stackoverflow.posts.transformed-10000.json
    fi

    echo "  导入 10,000 条文档..."
    curl -s -XPOST "http://localhost:7280/api/v1/stackoverflow/ingest?commit=force" \
        --data-binary @$DATA_FILE
    echo ""
    echo -e "${GREEN}✓ 数据导入完成${NC}"
}

# 运行搜索示例
run_search() {
    echo ""
    echo -e "${YELLOW}运行搜索示例...${NC}"
    echo ""

    echo -e "${BLUE}=== 基本搜索 ===${NC}"
    echo -e "${YELLOW}查询: \"search AND engine\"${NC}"
    curl -s "http://localhost:7280/api/v1/stackoverflow/search?query=search+AND+engine" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'找到 {data.get(\"num_hits\", 0)} 条结果')
for hit in data.get('hits', [])[:3]:
    print(f'  - {hit.get(\"title\", \"N/A\")[:60]}...')
"
    echo ""
}

# 主流程
case "${1:-start}" in
    start)
        start_services
        create_index
        ingest_data
        run_search

        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  Demo 启动完成！${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo -e "  Quickwit UI: ${BLUE}http://localhost:7280${NC}"
        echo -e "  API 端点:    ${BLUE}http://localhost:7280/api/v1${NC}"
        echo ""
        echo -e "  可选服务:"
        echo -e "    Kafka:   ${BLUE}localhost:9092${NC}"
        echo -e "    Grafana: ${BLUE}localhost:3000${NC} (admin/admin)"
        echo ""
        echo -e "停止服务: ${YELLOW}docker-compose down${NC}"
        echo ""

        # 保持运行
        $DOCKER_COMPOSE logs -f quickwit
        ;;
    stop)
        echo -e "${YELLOW}停止所有服务...${NC}"
        $DOCKER_COMPOSE down
        echo -e "${GREEN}✓ 已停止${NC}"
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    logs)
        $DOCKER_COMPOSE logs -f ${2:-quickwit}
        ;;
    index)
        create_index
        ;;
    ingest)
        ingest_data
        ;;
    search)
        run_search
        ;;
    *)
        echo "用法: $0 {start|stop|restart|logs|index|ingest|search}"
        echo ""
        echo "  start   - 启动所有服务（默认）"
        echo "  stop    - 停止所有服务"
        echo "  restart - 重启服务"
        echo "  logs    - 查看日志"
        echo "  index   - 仅创建索引"
        echo "  ingest  - 仅导入数据"
        echo "  search  - 运行搜索示例"
        exit 1
        ;;
esac
