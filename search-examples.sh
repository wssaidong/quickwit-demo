#!/bin/bash
#
# Quickwit 搜索示例集合
# 演示各种搜索和聚合查询
#

set -e

API_BASE="http://localhost:7280/api/v1/stackoverflow"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

check_server() {
    if ! curl -s "$API_BASE/search?query=test" &>/dev/null; then
        echo -e "${RED}错误: Quickwit 服务未运行${NC}"
        echo "请先运行: ./run-demo.sh"
        exit 1
    fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Quickwit 搜索示例集合${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_server

# 示例 1: 基本搜索
echo -e "${GREEN}[示例 1] 基本搜索${NC}"
echo -e "${YELLOW}查询: search AND engine${NC}"
echo -e "${CYAN}curl \"$API_BASE/search?query=search+AND+engine\"${NC}"
echo ""
curl -s "$API_BASE/search?query=search+AND+engine" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'找到 {data.get(\"num_hits\", 0)} 条结果')
for hit in data.get('hits', [])[:3]:
    print(f'  - {hit.get(\"title\", \"N/A\")[:60]}...')
"
echo ""

# 示例 2: 字段搜索
echo -e "${GREEN}[示例 2] 字段搜索${NC}"
echo -e "${YELLOW}查询: title:rust${NC}"
echo -e "${CYAN}curl \"$API_BASE/search?query=title:rust\"${NC}"
echo ""
curl -s "$API_BASE/search?query=title:rust" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'找到 {data.get(\"num_hits\", 0)} 条结果')
for hit in data.get('hits', [])[:3]:
    print(f'  - {hit.get(\"title\", \"N/A\")[:60]}')
"
echo ""

# 示例 3: JSON 格式搜索
echo -e "${GREEN}[示例 3] JSON 格式搜索（限制结果数量）${NC}"
echo -e "${YELLOW}查询: javascript，最大 5 条结果${NC}"
echo -e "${CYAN}curl -XPOST \"$API_BASE/search\" -H 'Content-Type: application/json' -d '{\"query\": \"javascript\", \"max_hits\": 5}'${NC}"
echo ""
curl -s -XPOST "$API_BASE/search" -H 'Content-Type: application/json' -d '{"query": "javascript", "max_hits": 5}' | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'找到 {data.get(\"num_hits\", 0)} 条结果，显示前 5 条:')
for hit in data.get('hits', []):
    print(f'  - [{hit.get(\"score\", 0):.2f}] {hit.get(\"title\", \"N/A\")[:60]}')
"
echo ""

# 示例 4: 聚合查询 - 标签统计
echo -e "${GREEN}[示例 4] 聚合查询 - 热门标签统计${NC}"
echo -e "${CYAN}curl -XPOST \"$API_BASE/search\" -H 'Content-Type: application/json' -d '{\"query\": \"*\", \"max_hits\": 0, \"aggs\": {\"top_tags\": {\"terms\": {\"field\": \"tags\", \"size\": 10}}}}'${NC}"
echo ""
curl -s -XPOST "$API_BASE/search" -H 'Content-Type: application/json' -d '{"query": "*", "max_hits": 0, "aggs": {"top_tags": {"terms": {"field": "tags", "size": 10}}}}' | python3 -c "
import json, sys
data = json.load(sys.stdin)
aggs = data.get('aggregations', {})
if 'top_tags' in aggs:
    print('热门标签:')
    for i, bucket in enumerate(aggs['top_tags'].get('buckets', []), 1):
        print(f'  {i}. {bucket.get(\"key\", \"N/A\")} ({bucket.get(\"doc_count\", 0)} 条)')
"
echo ""

# 示例 5: 时间范围搜索
echo -e "${GREEN}[示例 5] 时间范围搜索${NC}"
echo -e "${YELLOW}查询: 2010 年之前的文档${NC}"
echo ""
curl -s -XPOST "$API_BASE/search" -H 'Content-Type: application/json' -d '{"query": "creationDate:[* TO 2010-01-01T00:00:00Z]", "max_hits": 5}' | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'2010 年之前的文档数: {data.get(\"num_hits\", 0)}')
for hit in data.get('hits', [])[:3]:
    print(f'  - {hit.get(\"creationDate\", \"N/A\")} | {hit.get(\"title\", \"N/A\")[:50]}')
"
echo ""

# 示例 6: 短语搜索
echo -e "${GREEN}[示例 6] 短语搜索${NC}"
echo -e "${YELLOW}查询: \"search engine\"（精确短语）${NC}"
echo ""
curl -s "$API_BASE/search?query=%22search%20engine%22" | python3 -c "
import json, sys, urllib.parse
data = json.load(sys.stdin)
print(f'找到 {data.get(\"num_hits\", 0)} 条包含短语 \"search engine\" 的结果')
for hit in data.get('hits', [])[:3]:
    print(f'  - {hit.get(\"title\", \"N/A\")[:60]}')
"
echo ""

# 示例 7: 高亮显示
echo -e "${GREEN}[示例 7] 搜索建议${NC}"
echo -e "${CYAN}curl \"$API_BASE/search?query=python&max_hits=3\"${NC}"
echo ""
curl -s "$API_BASE/search?query=python&max_hits=3" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'Python 相关结果 (显示前 3 条，共 {data.get(\"num_hits\", 0)} 条):')
for hit in data.get('hits', []):
    title = hit.get('title', 'N/A')
    print(f'  - {title[:70]}')
"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  搜索示例结束${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "更多 API 文档: https://quickwit.io/docs/reference/rest-api"
