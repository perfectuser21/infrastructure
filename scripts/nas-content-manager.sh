#!/bin/bash
# NAS 内容管理工具 - 可被 N8N/Skills 调用
# 使用方式：./nas-content-manager.sh <command> [args]

set -euo pipefail

NAS_IP="100.110.241.76"
NAS_USER="徐啸"
NAS_BASE="/volume1/workspace/vault/zenithjoy-creator/content"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 检查依赖
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        log_error "jq 未安装。请运行: sudo apt-get install jq"
        exit 1
    fi

    if ! command -v ssh &> /dev/null; then
        log_error "ssh 未安装"
        exit 1
    fi
}

# 列出所有内容
list_contents() {
    log_info "列出所有内容..."
    ssh ${NAS_USER}@${NAS_IP} "sudo find ${NAS_BASE} -maxdepth 1 -type d -name '20*' | sort" 2>/dev/null | while read dir; do
        content_id=$(basename "$dir")
        manifest="${dir}/manifest.json"

        # 读取 manifest
        title=$(ssh ${NAS_USER}@${NAS_IP} "sudo cat ${manifest} 2>/dev/null | jq -r '.title' 2>/dev/null" || echo "N/A")
        status=$(ssh ${NAS_USER}@${NAS_IP} "sudo cat ${manifest} 2>/dev/null | jq -r '.status.state' 2>/dev/null" || echo "unknown")
        type=$(ssh ${NAS_USER}@${NAS_IP} "sudo cat ${manifest} 2>/dev/null | jq -r '.content_type' 2>/dev/null" || echo "unknown")

        echo "$content_id | $status | $type | $title"
    done
}

# 查看内容详情
show_content() {
    local content_id="$1"

    if [ -z "$content_id" ]; then
        log_error "请提供 content_id"
        exit 1
    fi

    local content_path="${NAS_BASE}/${content_id}"

    # 检查是否存在
    if ! ssh ${NAS_USER}@${NAS_IP} "sudo test -d ${content_path}" 2>/dev/null; then
        log_error "内容不存在: $content_id"
        exit 1
    fi

    log_info "内容详情: $content_id"
    echo ""

    # 显示 manifest
    echo "=== Manifest ==="
    ssh ${NAS_USER}@${NAS_IP} "sudo cat ${content_path}/manifest.json" 2>/dev/null | jq . || {
        log_error "无法读取 manifest.json"
        exit 1
    }

    echo ""
    echo "=== 文件列表 ==="
    ssh ${NAS_USER}@${NAS_IP} "sudo find ${content_path} -type f" 2>/dev/null || {
        log_error "无法列出文件"
        exit 1
    }
}

# 读取文本内容
read_text() {
    local content_id="$1"
    local version="${2:-v1}"

    if [ -z "$content_id" ]; then
        log_error "请提供 content_id"
        exit 1
    fi

    local text_file="${NAS_BASE}/${content_id}/text/text_${version}.md"

    if ! ssh ${NAS_USER}@${NAS_IP} "sudo test -f ${text_file}" 2>/dev/null; then
        log_error "文本文件不存在: ${text_file}"
        exit 1
    fi

    ssh ${NAS_USER}@${NAS_IP} "sudo cat ${text_file}" 2>/dev/null || {
        log_error "无法读取文本文件"
        exit 1
    }
}

# 更新文本内容
update_text() {
    local content_id="$1"
    local local_file="$2"
    local version="${3:-v1}"

    if [ -z "$content_id" ] || [ -z "$local_file" ]; then
        log_error "用法: update_text <content_id> <local_file> [version]"
        exit 1
    fi

    if [ ! -f "$local_file" ]; then
        log_error "本地文件不存在: $local_file"
        exit 1
    fi

    local content_path="${NAS_BASE}/${content_id}"
    local text_file="text_${version}.md"

    # 检查 content_id 是否存在
    if ! ssh ${NAS_USER}@${NAS_IP} "sudo test -d ${content_path}" 2>/dev/null; then
        log_error "内容不存在: $content_id"
        exit 1
    fi

    log_info "上传文本: $local_file -> ${content_id}/text/${text_file}"

    # 上传到临时位置
    scp "$local_file" ${NAS_USER}@${NAS_IP}:/tmp/${text_file} 2>/dev/null || {
        log_error "文件上传失败"
        exit 1
    }

    # 移动到目标位置
    ssh ${NAS_USER}@${NAS_IP} "sudo mv /tmp/${text_file} ${content_path}/text/${text_file}" 2>/dev/null || {
        log_error "文件移动失败"
        exit 1
    }

    # 更新 manifest 的 updated_at
    local updated_at=$(date -Iseconds)
    ssh ${NAS_USER}@${NAS_IP} "sudo jq '.status.updated_at = \"${updated_at}\"' ${content_path}/manifest.json > /tmp/manifest_temp.json && sudo mv /tmp/manifest_temp.json ${content_path}/manifest.json" 2>/dev/null || {
        log_error "Manifest 更新失败"
        exit 1
    }

    log_info "✅ 文本更新完成"
}

# 更新状态
update_status() {
    local content_id="$1"
    local new_state="$2"

    if [ -z "$content_id" ] || [ -z "$new_state" ]; then
        log_error "用法: update_status <content_id> <state>"
        log_info "可用状态: draft, ready, publishing, published, failed"
        exit 1
    fi

    local manifest_path="${NAS_BASE}/${content_id}/manifest.json"

    if ! ssh ${NAS_USER}@${NAS_IP} "sudo test -f ${manifest_path}" 2>/dev/null; then
        log_error "内容不存在: $content_id"
        exit 1
    fi

    log_info "更新状态: $content_id -> $new_state"

    local updated_at=$(date -Iseconds)
    ssh ${NAS_USER}@${NAS_IP} "sudo jq '.status.state = \"${new_state}\" | .status.updated_at = \"${updated_at}\"' ${manifest_path} > /tmp/manifest_temp.json && sudo mv /tmp/manifest_temp.json ${manifest_path}" 2>/dev/null || {
        log_error "状态更新失败"
        exit 1
    }

    log_info "✅ 状态更新完成"
}

# 添加平台
add_platform() {
    local content_id="$1"
    local platform="$2"

    if [ -z "$content_id" ] || [ -z "$platform" ]; then
        log_error "用法: add_platform <content_id> <platform>"
        exit 1
    fi

    local manifest_path="${NAS_BASE}/${content_id}/manifest.json"

    if ! ssh ${NAS_USER}@${NAS_IP} "sudo test -f ${manifest_path}" 2>/dev/null; then
        log_error "内容不存在: $content_id"
        exit 1
    fi

    log_info "添加平台: $content_id -> $platform"

    ssh ${NAS_USER}@${NAS_IP} "sudo jq '.platforms += [\"${platform}\"] | .platforms |= unique' ${manifest_path} > /tmp/manifest_temp.json && sudo mv /tmp/manifest_temp.json ${manifest_path}" 2>/dev/null || {
        log_error "平台添加失败"
        exit 1
    }

    log_info "✅ 平台添加完成"
}

# 上传图片
upload_image() {
    local content_id="$1"
    local local_file="$2"
    local role="${3:-cover}"

    if [ -z "$content_id" ] || [ -z "$local_file" ]; then
        log_error "用法: upload_image <content_id> <local_file> [role]"
        exit 1
    fi

    if [ ! -f "$local_file" ]; then
        log_error "本地文件不存在: $local_file"
        exit 1
    fi

    local filename=$(basename "$local_file")
    local content_path="${NAS_BASE}/${content_id}"
    local target_file="images/${filename}"

    # 检查 content_id 是否存在
    if ! ssh ${NAS_USER}@${NAS_IP} "sudo test -d ${content_path}" 2>/dev/null; then
        log_error "内容不存在: $content_id"
        exit 1
    fi

    log_info "上传图片: $local_file -> ${content_id}/images/${filename}"

    # 上传
    scp "$local_file" ${NAS_USER}@${NAS_IP}:/tmp/${filename} 2>/dev/null || {
        log_error "图片上传失败"
        exit 1
    }

    ssh ${NAS_USER}@${NAS_IP} "sudo mv /tmp/${filename} ${content_path}/images/${filename}" 2>/dev/null || {
        log_error "图片移动失败"
        exit 1
    }

    # 更新 manifest
    local image_path="${content_path}/${target_file}"
    ssh ${NAS_USER}@${NAS_IP} "sudo jq '.assets.images += [{\"role\": \"${role}\", \"path\": \"${image_path}\"}]' ${content_path}/manifest.json > /tmp/manifest_temp.json && sudo mv /tmp/manifest_temp.json ${content_path}/manifest.json" 2>/dev/null || {
        log_error "Manifest 更新失败"
        exit 1
    }

    log_info "✅ 图片上传完成"
}

# 搜索内容
search_contents() {
    local keyword="$1"

    if [ -z "$keyword" ]; then
        log_error "请提供搜索关键词"
        exit 1
    fi

    log_info "搜索关键词: $keyword"

    ssh ${NAS_USER}@${NAS_IP} "sudo find ${NAS_BASE} -name 'manifest.json' -type f -exec grep -l \"${keyword}\" {} \\;" 2>/dev/null | while read manifest; do
        content_id=$(basename $(dirname "$manifest"))
        title=$(ssh ${NAS_USER}@${NAS_IP} "sudo cat ${manifest} | jq -r '.title'" 2>/dev/null || echo "N/A")
        echo "$content_id | $title"
    done
}

# 按状态筛选
filter_by_status() {
    local status="$1"

    if [ -z "$status" ]; then
        log_error "请提供状态"
        log_info "可用状态: draft, ready, publishing, published, failed"
        exit 1
    fi

    log_info "筛选状态: $status"

    ssh ${NAS_USER}@${NAS_IP} "sudo find ${NAS_BASE} -name 'manifest.json' -type f" 2>/dev/null | while read manifest; do
        current_status=$(ssh ${NAS_USER}@${NAS_IP} "sudo cat ${manifest} | jq -r '.status.state'" 2>/dev/null || echo "unknown")

        if [ "$current_status" = "$status" ]; then
            content_id=$(basename $(dirname "$manifest"))
            title=$(ssh ${NAS_USER}@${NAS_IP} "sudo cat ${manifest} | jq -r '.title'" 2>/dev/null || echo "N/A")
            echo "$content_id | $title"
        fi
    done
}

# 统计信息
stats() {
    log_info "内容统计"
    echo ""

    # 总数
    local total=$(ssh ${NAS_USER}@${NAS_IP} "sudo find ${NAS_BASE} -maxdepth 1 -type d -name '20*' | wc -l" 2>/dev/null || echo "0")
    echo "总内容数: $total"
    echo ""

    # 按类型统计
    echo "按类型:"
    ssh ${NAS_USER}@${NAS_IP} "sudo find ${NAS_BASE} -name 'manifest.json' -type f -exec cat {} \\;" 2>/dev/null | jq -r '.content_type' | sort | uniq -c | sort -rn || echo "无数据"
    echo ""

    # 按状态统计
    echo "按状态:"
    ssh ${NAS_USER}@${NAS_IP} "sudo find ${NAS_BASE} -name 'manifest.json' -type f -exec cat {} \\;" 2>/dev/null | jq -r '.status.state' | sort | uniq -c | sort -rn || echo "无数据"
}

# 创建新内容
create_content() {
    local content_id="$1"
    local title="$2"
    local content_type="${3:-article}"

    if [ -z "$content_id" ] || [ -z "$title" ]; then
        log_error "用法: create_content <content_id> <title> [content_type]"
        exit 1
    fi

    local content_path="${NAS_BASE}/${content_id}"

    # 检查是否已存在
    if ssh ${NAS_USER}@${NAS_IP} "sudo test -d ${content_path}" 2>/dev/null; then
        log_error "内容已存在: $content_id"
        exit 1
    fi

    log_info "创建新内容: $content_id"

    # 创建目录结构
    ssh ${NAS_USER}@${NAS_IP} "sudo mkdir -p ${content_path}/{text,images,videos,exports,logs}" 2>/dev/null || {
        log_error "目录创建失败"
        exit 1
    }

    # 创建 manifest.json
    local created_at=$(date -Iseconds)
    ssh ${NAS_USER}@${NAS_IP} "sudo tee ${content_path}/manifest.json > /dev/null" 2>/dev/null << EOF
{
  "content_id": "${content_id}",
  "version": 1,
  "title": "${title}",
  "content_type": "${content_type}",
  "platforms": [],
  "assets": {
    "text": "${content_path}/text/text_v1.md",
    "images": [],
    "videos": []
  },
  "tags": [],
  "status": {
    "state": "draft",
    "created_at": "${created_at}",
    "updated_at": "${created_at}"
  }
}
EOF

    if [ $? -ne 0 ]; then
        log_error "Manifest 创建失败"
        exit 1
    fi

    log_info "✅ 内容创建完成"
}

# 显示帮助
show_help() {
    cat << EOF
NAS 内容管理工具

用法: $0 <command> [args]

命令:
  list                                列出所有内容
  show <content_id>                   查看内容详情
  read <content_id> [version]         读取文本内容
  update-text <content_id> <file> [v] 更新文本内容
  update-status <content_id> <state>  更新状态
  add-platform <content_id> <platform> 添加平台
  upload-image <content_id> <file> [role] 上传图片
  search <keyword>                    搜索内容
  filter <status>                     按状态筛选
  stats                               统计信息
  create <content_id> <title> [type]  创建新内容
  help                                显示帮助

示例:
  $0 list
  $0 show 2025-11-03-009a0b
  $0 read 2025-11-03-009a0b
  $0 update-status 2025-11-03-009a0b ready
  $0 add-platform 2025-11-03-009a0b xhs
  $0 search "AI"
  $0 filter draft
  $0 stats
  $0 create 2026-02-10-test "测试文章" deep-post

状态值: draft, ready, publishing, published, failed
内容类型: deep-post, short-post, broad-post, newsletter, explainer
平台: xhs, weibo, douyin, toutiao
EOF
}

# 检查依赖
check_dependencies

# 主命令路由
case "${1:-}" in
    list)
        list_contents
        ;;
    show)
        show_content "${2:-}"
        ;;
    read)
        read_text "${2:-}" "${3:-v1}"
        ;;
    update-text)
        update_text "${2:-}" "${3:-}" "${4:-v1}"
        ;;
    update-status)
        update_status "${2:-}" "${3:-}"
        ;;
    add-platform)
        add_platform "${2:-}" "${3:-}"
        ;;
    upload-image)
        upload_image "${2:-}" "${3:-}" "${4:-cover}"
        ;;
    search)
        search_contents "${2:-}"
        ;;
    filter)
        filter_by_status "${2:-}"
        ;;
    stats)
        stats
        ;;
    create)
        create_content "${2:-}" "${3:-}" "${4:-article}"
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        log_error "未知命令: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
