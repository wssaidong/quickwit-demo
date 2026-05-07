#!/bin/bash
#
# Quickwit Demo 一键运行脚本
# 演示如何在本地启动 Quickwit 并运行 StackOverflow 搜索示例
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

QW_VERSION="nightly"
QW_DIR="quickwit-${QW_VERSION}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Quickwit Demo 一键运行脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检测系统架构
detect_arch() {
    case "$(uname -m)" in
        x86_64)
            echo "x86_64-unknown-linux-gnu"
            ;;
        aarch64|arm64)
            if [[ "$(uname -s)" == "Linux" ]]; then
                echo "aarch64-unknown-linux-gnu"
            else
                echo "aarch64-apple-darwin"
            fi
            ;;
        *)
            echo "x86_64-unknown-linux-gnu"
            ;;
    esac
}

# 检测系统类型
detect_os() {
    case "$(uname -s)" in
        Linux)
            echo "linux"
            ;;
        Darwin)
            echo "darwin"
            ;;
        *)
            echo "linux"
            ;;
    esac
}

install_quickwit() {
    echo -e "${YELLOW}[1/6] 安装 Quickwit ${QW_VERSION}...${NC}"

    if command -v ./quickwit &> /dev/null; then
        echo -e "${GREEN}✓ Quickwit 已安装，跳过安装步骤${NC}"
        return
    fi

    ARCH=$(detect_arch)
    OS=$(detect_os)

    # 如果是 macOS，使用 darwin
    if [[ "$(uname -s)" == "Darwin" ]]; then
        ARCH=$(uname -m)
        if [[ "$ARCH" == "arm64" ]]; then
            ARCH="aarch64-apple-darwin"
        else
            ARCH="x86_64-apple-darwin"
        fi
    fi

    DOWNLOAD_URL="https://github.com/quickwit-oss/quickwit/releases/download/${QW_VERSION}/quickwit-${QW_VERSION}-${ARCH}.tar.gz"

    echo "  下载地址: $DOWNLOAD_URL"
    echo "  目标架构: $ARCH"

    curl -L "$DOWNLOAD_URL" -o quickwit.tar.gz
    tar -xzf quickwit.tar.gz
    rm quickwit.tar.gz

    # 检查解压结果
    if [[ ! -d "$QW_DIR" ]]; then
        # 尝试直接解压
        if [[ -d "quickwit-"* ]]; then
            QW_DIR=$(ls -d quickwit-* | head -1)
        fi
    fi

    echo -e "${GREEN}✓ Quickwit 安装完成${NC}"
}

download_data() {
    echo -e "${YELLOW}[2/6] 下载数据集...${NC}"

    DATA_FILE="stackoverflow.posts.transformed-10000.json"

    if [[ -f "$DATA_FILE" ]]; then
        echo -e "${GREEN}✓ 数据集已存在，跳过下载${NC}"
        return
    fi

    echo "  从 S3 下载 StackOverflow 数据集 (10,000 条)..."
    curl -O https://quickwit-datasets-public.s3.amazonaws.com/stackoverflow.posts.transformed-10000.json

    echo -e "${GREEN}✓ 数据集下载完成${NC}"
}

start_server() {
    echo -e "${YELLOW}[3/6] 启动 Quickwit 服务...${NC}"

    # 创建数据目录
    mkdir -p qwdata

    echo "  启动服务器 (端口 7280)..."
    echo "  按 Ctrl+C 停止服务"
    echo ""

    # 在后台启动 Quickwit
    ./quickwit run &
    QW_PID=$!

    # 等待服务启动
    echo -n "  等待服务就绪"
    for i in {1..30}; do
        if curl -s http://localhost:7280/api/v1/version &>/dev/null; then
            echo ""
            echo -e "${GREEN}✓ Quickwit 服务已启动 (PID: $QW_PID)${NC}"
            return 0
        fi
        echo -n "."
        sleep 1
    done

    echo ""
    echo -e "${RED}✗ 服务启动超时${NC}"
    return 1
}

create_index() {
    echo -e "${YELLOW}[4/6] 创建索引...${NC}"

    # 下载索引配置（如果不存在）
    if [[ ! -f "stackoverflow-index-config.yaml" ]]; then
        echo "  下载索引配置..."
        curl -o stackoverflow-index-config.yaml https://raw.githubusercontent.com/quickwit-oss/quickwit/main/config/tutorials/stackoverflow/index-config.yaml
    fi

    echo "  创建索引 'stackoverflow'..."
    ./quickwit index create --index-config ./stackoverflow-index-config.yaml 2>&1

    echo -e "${GREEN}✓ 索引创建完成${NC}"
}

ingest_data() {
    echo -e "${YELLOW}[5/6] 导入数据...${NC}"

    echo "  导入 10,000 条 StackOverflow 文档..."
    ./quickwit index ingest --index stackoverflow --input-path ./stackoverflow.posts.transformed-10000.json --force 2>&1

    echo -e "${GREEN}✓ 数据导入完成${NC}"
}

run_demo_search() {
    echo -e "${YELLOW}[6/6] 执行示例搜索...${NC}"
    echo ""

    # 运行搜索示例脚本
    if [[ -f "./search-examples.sh" ]]; then
        chmod +x ./search-examples.sh
        ./search-examples.sh
    else
        # 直接执行基本搜索
        echo -e "${BLUE}=== 基本搜索 ===${NC}"
        echo -e "${YELLOW}\$ curl \"http://localhost:7280/api/v1/stackoverflow/search?query=search+AND+engine\"${NC}"
        echo ""
        curl -s "http://localhost:7280/api/v1/stackoverflow/search?query=search+AND+engine" | head -c 500
        echo ""
        echo ""
        echo "... (运行 search-examples.sh 查看更多示例)"
    fi

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Demo 运行完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "  UI 控制台: ${BLUE}http://localhost:7280${NC}"
    echo -e "  API 文档:  ${BLUE}https://quickwit.io/docs/reference/rest-api${NC}"
    echo ""
    echo -e "  按 ${YELLOW}Ctrl+C${NC} 停止服务"
    echo ""
}

cleanup() {
    echo ""
    echo -e "${YELLOW}正在停止 Quickwit 服务...${NC}"
    pkill -f "quickwit run" 2>/dev/null || true
    echo -e "${GREEN}服务已停止${NC}"
}

# 主流程
main() {
    # 清理函数
    trap cleanup EXIT

    cd "$(dirname "$0")"

    install_quickwit
    download_data
    start_server
    create_index
    ingest_data
    run_demo_search

    # 保持运行
    echo ""
    echo -e "${YELLOW}服务持续运行中...${NC}"
    wait
}

# 如果有 --only-search 参数，只运行搜索
if [[ "$1" == "--only-search" ]]; then
    echo -e "${BLUE}仅运行搜索示例（假设服务已启动）${NC}"
    if [[ -f "./search-examples.sh" ]]; then
        chmod +x ./search-examples.sh
        ./search-examples.sh
    else
        curl -s "http://localhost:7280/api/v1/stackoverflow/search?query=search+AND+engine"
    fi
    exit 0
fi

main
