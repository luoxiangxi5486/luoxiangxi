#!/usr/bin/env bash
#
# OpenStack Train 双节点环境自检脚本
#
# 用法：
#   bash verify-openstack.sh              # 完整检查（需先在控制节点执行 . admin-login）
#   bash verify-openstack.sh --local-only # 仅检查本机基础服务，不依赖 OpenStack 凭据
#
# 说明：本脚本按 docs/服务验证记录.md 的检查清单实现，
#       仅做只读检查，不修改任何系统状态。
#
set -uo pipefail

PASS=0
FAIL=0
SKIP=0
FAILED_ITEMS=()

C_RESET=''; C_GREEN=''; C_RED=''; C_YELLOW=''
if [ -t 1 ]; then
    C_RESET='\033[0m'; C_GREEN='\033[32m'; C_RED='\033[31m'; C_YELLOW='\033[33m'
fi

pass() { PASS=$((PASS+1)); printf '  %b✔%b %s\n' "$C_GREEN" "$C_RESET" "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_ITEMS+=("$1"); printf '  %b✘%b %s\n' "$C_RED" "$C_RESET" "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  %b-%b %s（跳过：%s）\n' "$C_YELLOW" "$C_RESET" "$1" "${2:-}"; }
section() { printf '\n== %s ==\n' "$1"; }

# 判断命令是否存在
has() { command -v "$1" >/dev/null 2>&1; }

# 端口是否监听
port_listening() {
    # $1 = 端口
    if has ss; then
        ss -Htlnu 2>/dev/null | awk '{print $5}' | grep -qE "[:.]$1\$"
    elif has netstat; then
        netstat -tlnu 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$1\$"
    else
        return 2
    fi
}

LOCAL_ONLY=0
[ "${1:-}" = "--local-only" ] && LOCAL_ONLY=1

printf 'OpenStack 环境自检\n'
printf '主机名: %s\n' "$(hostname 2>/dev/null || echo unknown)"
printf '时间:   %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null)"

# ---------------------------------------------------------------- 基础环境
section "基础环境"

if [ -f /etc/hosts ]; then
    if grep -qE '^[0-9.]+[[:space:]]+controller([[:space:]]|$)' /etc/hosts && \
       grep -qE '^[0-9.]+[[:space:]]+compute([[:space:]]|$)' /etc/hosts; then
        pass "/etc/hosts 含 controller 与 compute 解析"
    else
        fail "/etc/hosts 缺少 controller 或 compute 解析" "所有服务端点依赖该解析"
    fi
else
    fail "无法读取 /etc/hosts"
fi

if has ping; then
    if ping -c 1 -W 2 compute >/dev/null 2>&1; then
        pass "可达 compute 节点"
    else
        fail "无法 ping 通 compute" "检查网络与 /etc/hosts"
    fi
else
    skip "节点互通" "未安装 ping"
fi

if has chronyc; then
    src_count=$(chronyc sources 2>/dev/null | grep -cE '^\^\*|^\^\+' || true)
    if [ "${src_count:-0}" -gt 0 ]; then
        pass "Chrony 至少 1 个同步源"
    else
        fail "Chrony 无可用同步源" "chronyc sources -v"
    fi
else
    skip "Chrony" "未安装"
fi

# ---------------------------------------------------------------- 基础服务
section "基础服务（控制节点）"

check_port() {
    # $1 名称  $2 端口
    port_listening "$2"
    case $? in
        0) pass "$1 监听 $2" ;;
        1) fail "$1 未监听 $2" ;;
        *) skip "$1" "缺少 ss/netstat" ;;
    esac
}

check_port "MariaDB" 3306
check_port "RabbitMQ" 5672
check_port "Memcached" 11211
check_port "etcd" 2379

if has rabbitmqctl; then
    if rabbitmqctl list_users 2>/dev/null | grep -q '^openstack'; then
        pass "RabbitMQ 存在 openstack 用户"
    else
        fail "RabbitMQ 缺少 openstack 用户" "rabbitmqctl add_user openstack 000000"
    fi
else
    skip "RabbitMQ 用户" "未安装 rabbitmqctl"
fi

if [ "$LOCAL_ONLY" -eq 1 ]; then
    printf '\n（--local-only：跳过 OpenStack 组件检查）\n'
else
    # ------------------------------------------------------------ OpenStack
    section "OpenStack 服务（需已执行 . admin-login）"

    if [ -z "${OS_AUTH_URL:-}" ]; then
        if [ -f "$HOME/admin-login" ]; then
            # shellcheck disable=SC1091
            . "$HOME/admin-login"
            pass "已自动加载 ~/admin-login"
        elif [ -f /root/admin-login ]; then
            # shellcheck disable=SC1091
            . /root/admin-login
            pass "已自动加载 /root/admin-login"
        else
            fail "未设置 OS_AUTH_URL" "先执行 . admin-login"
        fi
    else
        pass "环境变量已就绪（OS_AUTH_URL=${OS_AUTH_URL}）"
    fi

    if ! has openstack; then
        fail "未安装 openstack 客户端" "yum -y install python-openstackclient"
    else
        # Keystone
        if openstack token issue >/dev/null 2>&1; then
            pass "Keystone 可签发 Token"
        else
            fail "Keystone 无法签发 Token" "检查 httpd 与 keystone 配置"
        fi

        # Glance
        img=$(openstack image list -f value -c ID 2>/dev/null | wc -l)
        if [ "${img:-0}" -gt 0 ]; then
            pass "Glance 有 ${img} 个镜像"
        else
            fail "Glance 无镜像或不可用"
        fi

        # Placement
        if openstack resource provider list >/dev/null 2>&1; then
            pass "Placement API 可用"
        else
            fail "Placement API 不可用" "检查 httpd 中 placement 配置"
        fi

        # Nova
        nova_up=$(openstack compute service list -f value -c State 2>/dev/null | grep -c '^up$' || true)
        if [ "${nova_up:-0}" -ge 3 ]; then
            pass "Nova 有 ${nova_up} 个服务 up（期望 ≥3）"
        else
            fail "Nova 服务数不足（up=${nova_up:-0}，期望 ≥3）" "nova-manage cell_v2 discover_hosts"
        fi

        if has nova-status; then
            if nova-status upgrade check >/dev/null 2>&1; then
                pass "nova-status upgrade check 通过"
            else
                fail "nova-status upgrade check 有告警" "nova-status upgrade check"
            fi
        else
            skip "nova-status" "未安装"
        fi

        # Neutron
        agent_up=$(openstack network agent list -f value -c Alive 2>/dev/null | grep -c ':-)' || true)
        if [ "${agent_up:-0}" -ge 4 ]; then
            pass "Neutron 有 ${agent_up} 个代理存活（期望 ≥4）"
        else
            fail "Neutron 存活代理不足（${agent_up:-0}，期望 ≥4）" "openstack network agent list"
        fi

        # Cinder
        cinder_up=$(openstack volume service list -f value -c State 2>/dev/null | grep -c '^up$' || true)
        if [ "${cinder_up:-0}" -ge 2 ]; then
            pass "Cinder 有 ${cinder_up} 个服务 up（期望 ≥2）"
        else
            fail "Cinder 服务数不足（up=${cinder_up:-0}，期望 ≥2）" "检查 lvm 卷组与 cinder-volume"
        fi
    fi
fi

# ---------------------------------------------------------------- 汇总
printf '\n----------------------------------------\n'
printf '通过 %d  失败 %d  跳过 %d\n' "$PASS" "$FAIL" "$SKIP"
if [ "$FAIL" -gt 0 ]; then
    printf '\n失败项：\n'
    for item in "${FAILED_ITEMS[@]}"; do
        printf '  - %s\n' "$item"
    done
    printf '\n排查请参考 docs/服务验证记录.md §四 故障与处理记录\n'
    exit 1
fi
printf '全部检查通过\n'
exit 0
