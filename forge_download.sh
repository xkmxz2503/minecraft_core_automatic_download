#!/usr/bin/env sh
# 兼容POSIX sh，避免bash特有语法
set -eo pipefail
# 关闭set -u（避免未定义变量直接退出，改用默认值兼容）
set +u

# ======================== 核心优化：日志高可见配置 ========================
# 定义ANSI颜色（兼容无颜色终端，不存在则置空）
if [ -t 1 ]; then # 检测是否为交互式终端
    COLOR_RED="\033[31m"
    COLOR_GREEN="\033[32m"
    COLOR_YELLOW="\033[33m"
    COLOR_BLUE="\033[34m"
    COLOR_RESET="\033[0m"
else
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_RESET=""
fi

# 日志格式化函数（高可见核心）
# 参数1：日志级别（INFO/ERROR/SUCCESS/WARN） 参数2：日志内容
log() {
    local LEVEL=$1
    local MSG=$2
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S") # POSIX兼容的时间戳
    
    # 根据级别设置颜色和输出流
    case "${LEVEL}" in
        INFO)
            echo "${COLOR_BLUE}[${TIMESTAMP}] [INFO] ${MSG}${COLOR_RESET}"
            ;;
        SUCCESS)
            echo "${COLOR_GREEN}[${TIMESTAMP}] [SUCCESS] ${MSG}${COLOR_RESET}"
            ;;
        WARN)
            echo "${COLOR_YELLOW}[${TIMESTAMP}] [WARN] ${MSG}${COLOR_RESET}"
            ;;
        ERROR)
            echo "${COLOR_RED}[${TIMESTAMP}] [ERROR] ${MSG}${COLOR_RESET}" >&2 # 错误输出到stderr
            ;;
        *)
            echo "[${TIMESTAMP}] [UNKNOWN] ${MSG}"
            ;;
    esac
    
    # 同时写入临时日志文件（详细留存）
    echo "[${TIMESTAMP}] [${LEVEL}] ${MSG}" >> "${TEMP_LOG}"
}

# ======================== 兼容性前置处理 ========================
# 1. 字符编码兼容（适配Linux/macOS，避免中文乱码）
if [ "$(uname -s)" = "Darwin" ]; then
    # macOS优先使用UTF-8
    export LC_ALL=en_US.UTF-8
else
    # Linux尝试设置UTF-8，失败则降级
    export LANG=zh_CN.UTF-8 || export LANG=en_US.UTF-8 || true
fi

# 2. 临时文件安全创建（避免固定名称冲突，兼容不同系统mktemp）
if command -v mktemp >/dev/null 2>&1; then
    TEMP_LOG=$(mktemp -t forge_download.XXXXXX.log) || TEMP_LOG="./temp_forge.log"
else
    TEMP_LOG="./temp_forge.log"
fi
# 脚本退出时清理临时文件（保留日志路径提示）
trap 'log INFO "临时日志文件路径：${TEMP_LOG}（脚本退出后自动清理）"; rm -f "$TEMP_LOG"' EXIT INT TERM

# 3. 命令别名兼容（统一curl/wget参数，适配不同版本）
alias safe_curl='curl -sSL --user-agent "Mozilla/5.0" --connect-timeout 30 --max-time 60 --retry 2'
# 旧版wget无--show-progress，用--progress=bar替代
if wget --help 2>&1 | grep -q -- '--show-progress'; then
    alias safe_wget='wget -q --show-progress --user-agent "Mozilla/5.0" --connect-timeout 30 --timeout 60 --tries 2'
else
    alias safe_wget='wget -q --progress=bar:force --user-agent "Mozilla/5.0" --connect-timeout 30 --timeout 60 --tries 2'
fi

# ======================== 新增模块：容器环境检测 ========================
check_container_env() {
    log INFO "检测运行环境是否为容器..."
    # 容器环境判断依据（覆盖Docker/Podman/Containerd等主流容器）
    local is_container="false"
    
    # 1. 检测Docker特有文件
    if [ -f "/.dockerenv" ]; then
        is_container="true"
    # 2. 检测Podman/Containerd特有文件
    elif [ -f "/run/.containerenv" ]; then
        is_container="true"
    # 3. 检测容器环境变量（兼容k8s/OCI容器）
    elif [ -n "${container:-}" ] || [ -n "${KUBERNETES_SERVICE_HOST:-}" ]; then
        is_container="true"
    fi

    # 输出容器环境检测结果
    if [ "${is_container}" = "true" ]; then
        log INFO "当前运行环境：容器（Docker/Podman/OCI）"
        # 可选：容器环境下的特殊配置（如调整Java内存、权限等）
        # 示例：FORGE_JAVA_ARGS="${FORGE_JAVA_ARGS:-"-Xmx2G -Xms1G"}"
    else
        log INFO "当前运行环境：物理机/虚拟机"
    fi
    return 0
}

# ======================== 模块1：加载配置文件（对齐BAT逻辑+兼容处理） ========================
load_config() {
    # 初始化默认值（避免未定义变量）
    FORGE_MINECRAFT_VERSION="${FORGE_MINECRAFT_VERSION:-}"
    FORGE_VERSION="${FORGE_VERSION:-}"
    FORGE_BRANCH="${FORGE_BRANCH:-}"
    TARGET_CORE="${TARGET_CORE:-}"
    CHECK_CORE_EXIST="${CHECK_CORE_EXIST:-true}"
    AUTO_RUN_SERVER="${AUTO_RUN_SERVER:-false}"
    FORGE_JAVA_ARGS="${FORGE_JAVA_ARGS:-}"

    # 读取配置文件（兼容空行/注释/等号前后空格）
    if [ -f "script_config.txt" ]; then
        log INFO "开始加载配置文件：script_config.txt"
        while IFS='=' read -r key value; do
            # 去除key首尾空格
            key=$(echo "$key" | tr -d '[:space:]')
            # 跳过空行/注释行
            if [ -z "$key" ] || echo "$key" | grep -q '^#'; then
                continue
            fi
            # 去除value首尾空格（兼容配置项空格）
            value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            # 导出变量（POSIX兼容）
            eval "export $key='$value'"
            log INFO "加载配置项：$key=$value"
        done < "script_config.txt"
    else
        log ERROR "配置文件script_config.txt不存在"
        return 1
    fi

    # 2. 构建BMCLAPI相关URL（完全对齐BAT逻辑）
    BMCLAPI_DOMAIN="https://bmclapi2.bangbang93.com"
    BMCLAPI_API_URL="${BMCLAPI_DOMAIN}/forge/download"
    FORGE_BMCLAPI_URL="${BMCLAPI_API_URL}?mcversion=${FORGE_MINECRAFT_VERSION}&version=${FORGE_VERSION}&category=installer&format=jar"
    
    # 处理FORGE_BRANCH（有则拼接，无则不处理）
    if [ -n "${FORGE_BRANCH}" ]; then
        FORGE_BMCLAPI_URL="${FORGE_BMCLAPI_URL}&branch=${FORGE_BRANCH}"
        log INFO "拼接分支参数后BMCLAPI地址：${FORGE_BMCLAPI_URL}"
    fi

    # 3. 构建官方源URL（完全对齐BAT逻辑）
    FORGE_OFFICIAL_URL="https://files.minecraftforge.net/maven/net/minecraftforge/forge/${FORGE_MINECRAFT_VERSION}-${FORGE_VERSION}/forge-${FORGE_MINECRAFT_VERSION}-${FORGE_VERSION}-installer.jar"

    # 4. 定义安装器文件名（对齐BAT的FORGE_INSTALLER_NAME）
    FORGE_INSTALLER_NAME="forge-${FORGE_MINECRAFT_VERSION}-${FORGE_VERSION}-installer.jar"
    
    # 校验核心配置项（不能为空）
    if [ -z "${FORGE_MINECRAFT_VERSION}" ] || [ -z "${FORGE_VERSION}" ] || [ -z "${TARGET_CORE}" ]; then
        log ERROR "核心配置项（FORGE_MINECRAFT_VERSION/FORGE_VERSION/TARGET_CORE）不能为空"
        return 1
    fi

    # 打印关键配置（高可见）
    log INFO "=== 核心配置信息 ==="
    log INFO "Minecraft版本：${FORGE_MINECRAFT_VERSION}"
    log INFO "Forge版本：${FORGE_VERSION}"
    log INFO "目标核心：${TARGET_CORE}"
    log INFO "安装器文件名：${FORGE_INSTALLER_NAME}"
    log INFO "BMCLAPI下载地址：${FORGE_BMCLAPI_URL}"
    log INFO "官方源下载地址：${FORGE_OFFICIAL_URL}"
    log INFO "===================="

    export BMCLAPI_DOMAIN BMCLAPI_API_URL FORGE_BMCLAPI_URL FORGE_OFFICIAL_URL FORGE_INSTALLER_NAME
    return 0
}

# ======================== 模块2：校验核心匹配（兼容大小写） ========================
check_core_match() {
    # 兼容大小写（BAT中用了/i参数）
    local target_core_lower=$(echo "${TARGET_CORE}" | tr '[:upper:]' '[:lower:]')
    if [ "${target_core_lower}" != "forge" ]; then
        log ERROR "脚本与配置文件指定核心不匹配（当前：${TARGET_CORE}，需要：forge）"
        return 1
    fi
    log INFO "核心匹配校验通过（目标核心：forge）"
    return 0
}

# ======================== 模块3：检测核心是否已存在（对齐BAT逻辑） ========================
check_core_exists() {
    if [ "${CHECK_CORE_EXIST}" = "false" ]; then
        log INFO "跳过核心存在检测（CHECK_CORE_EXIST=false）"
        return 1
    fi
    UNIVERSAL_JAR="forge-${FORGE_MINECRAFT_VERSION}-${FORGE_VERSION}-universal.jar"
    if [ -f "${UNIVERSAL_JAR}" ] && [ -s "${UNIVERSAL_JAR}" ]; then
        log SUCCESS "Forge核心已存在：${UNIVERSAL_JAR}，跳过下载流程"
        return 0
    else
        log INFO "Forge核心不存在：${UNIVERSAL_JAR}，将执行下载&安装"
        return 1
    fi
}

# ======================== 模块4：下载Forge安装器（高兼容+对齐BAT逻辑+高可见日志） ========================
download_forge_installer() {
    log INFO "开始从BMCLAPI获取Forge真实下载地址..."
    REAL_URL=""

    # 获取BMCLAPI重定向地址（兼容curl/wget，对齐BAT的PowerShell逻辑）
    if command -v curl >/dev/null 2>&1; then
        # 获取最终重定向地址（兼容macOS/Linux curl）
        log INFO "使用curl获取BMCLAPI重定向地址..."
        REAL_URL=$(safe_curl -I -o /dev/null -w "%{url_effective}" "${FORGE_BMCLAPI_URL}" || true)
    elif command -v wget >/dev/null 2>&1; then
        # wget获取重定向地址（兼容低版本wget）
        log INFO "使用wget获取BMCLAPI重定向地址..."
        REAL_URL=$(wget --server-response --max-redirect=0 "${FORGE_BMCLAPI_URL}" 2>&1 | grep -i '^Location:' | awk -F': ' '{print $2}' | tail -n1 | tr -d '\r' || true)
        # 处理相对路径（对齐BAT的if ($realUrl -match '^/')逻辑）
        if [ -n "${REAL_URL}" ] && [ "${REAL_URL:0:1}" = "/" ]; then
            REAL_URL="${BMCLAPI_DOMAIN}${REAL_URL}"
            log INFO "修正相对路径后重定向地址：${REAL_URL}"
        fi
    else
        log ERROR "缺少curl/wget，无法下载文件"
        return 1
    fi

    # 替换失效域名（对齐BAT的mirrors.ppuc.lol → bmclapi2.bangbang93.com）
    if [ -n "${REAL_URL}" ]; then
        REAL_URL=$(echo "${REAL_URL}" | sed 's/mirrors.ppuc.lol/bmclapi2.bangbang93.com/g')
        log INFO "BMCLAPI真实下载地址（已替换失效域名）：${REAL_URL}"
    else
        log WARN "未获取到BMCLAPI重定向地址，可能是接口异常"
    fi

    # 下载安装器（优先curl，兜底wget）
    DOWNLOAD_SUCCESS=0
    log INFO "开始从BMCLAPI下载安装器：${FORGE_INSTALLER_NAME}"
    if command -v curl >/dev/null 2>&1; then
        safe_curl -o "${FORGE_INSTALLER_NAME}" "${REAL_URL}" >> "$TEMP_LOG" 2>&1 || DOWNLOAD_SUCCESS=1
    elif command -v wget >/dev/null 2>&1; then
        safe_wget -O "${FORGE_INSTALLER_NAME}" "${REAL_URL}" >> "$TEMP_LOG" 2>&1 || DOWNLOAD_SUCCESS=1
    else
        DOWNLOAD_SUCCESS=1
    fi

    # 检查BMCLAPI下载结果
    if [ "${DOWNLOAD_SUCCESS}" -eq 0 ] && [ -f "${FORGE_INSTALLER_NAME}" ] && [ -s "${FORGE_INSTALLER_NAME}" ]; then
        log SUCCESS "BMCLAPI下载完成，文件：${FORGE_INSTALLER_NAME}（大小：$(du -h "${FORGE_INSTALLER_NAME}" | awk '{print $1}')）"
        return 0
    else
        log WARN "BMCLAPI下载失败，错误日志：$(cat "$TEMP_LOG" | tail -5)"
    fi

    # BMCLAPI失败，尝试官方源（对齐BAT逻辑）
    log INFO "切换到官方源下载安装器..."
    rm -f "${FORGE_INSTALLER_NAME}" 2>/dev/null
    DOWNLOAD_SUCCESS=0
    if command -v curl >/dev/null 2>&1; then
        safe_curl -o "${FORGE_INSTALLER_NAME}" "${FORGE_OFFICIAL_URL}" >> "$TEMP_LOG" 2>&1 || DOWNLOAD_SUCCESS=1
    elif command -v wget >/dev/null 2>&1; then
        safe_wget -O "${FORGE_INSTALLER_NAME}" "${FORGE_OFFICIAL_URL}" >> "$TEMP_LOG" 2>&1 || DOWNLOAD_SUCCESS=1
    else
        DOWNLOAD_SUCCESS=1
    fi

    # 最终检查
    if [ "${DOWNLOAD_SUCCESS}" -eq 0 ] && [ -f "${FORGE_INSTALLER_NAME}" ] && [ -s "${FORGE_INSTALLER_NAME}" ]; then
        log SUCCESS "官方源下载完成，文件：${FORGE_INSTALLER_NAME}（大小：$(du -h "${FORGE_INSTALLER_NAME}" | awk '{print $1}')）"
        return 0
    else
        log ERROR "所有源均下载失败！详细日志：$(cat "$TEMP_LOG")"
        return 1
    fi
}

# ======================== 模块5：安装Forge核心（对齐BAT逻辑+错误处理+高可见） ========================
install_forge_core() {
    log INFO "开始安装Forge核心..."
    # 检查java是否存在
    if ! command -v java >/dev/null 2>&1; then
        log ERROR "未找到Java环境，请先安装Java并配置到PATH"
        return 1
    fi
    # 打印Java版本（高可见）
    JAVA_VERSION=$(java -version 2>&1 | head -1 | sed -e 's/"/ /g' | awk '{print $3}')
    log INFO "当前Java版本：${JAVA_VERSION}"
    
    # 执行安装（保留退出码，对齐BAT的ERRORLEVEL）
    java -jar "${FORGE_INSTALLER_NAME}" --installServer >> "$TEMP_LOG" 2>&1
    INSTALL_EXIT_CODE=$?
    if [ "${INSTALL_EXIT_CODE}" -ne 0 ]; then
        log ERROR "Forge安装失败，退出码：${INSTALL_EXIT_CODE}，详细日志：$(cat "$TEMP_LOG" | tail -10)"
        return "${INSTALL_EXIT_CODE}"
    fi
    
    # 【按需保留】删除安装器（如需保留，注释下面2行）
    # rm -f "${FORGE_INSTALLER_NAME}" 2>/dev/null
    # log INFO "Forge安装器已清理"
    log SUCCESS "Forge核心安装完成（退出码：0）"
    return 0
}

# ======================== 模块6：自动运行服务器（兼容参数空格+高可见） ========================
run_server() {
    UNIVERSAL_JAR="forge-${FORGE_MINECRAFT_VERSION}-${FORGE_VERSION}-universal.jar"
    log SUCCESS "开始启动Forge服务器..."
    log INFO "服务器启动参数：java ${FORGE_JAVA_ARGS} -jar ${UNIVERSAL_JAR} nogui"
    # 兼容Java参数中的空格（用引号包裹）
    sh ./run.sh
    RUN_EXIT_CODE=$?
    if [ "${RUN_EXIT_CODE}" -ne 0 ]; then
        log ERROR "服务器启动失败，退出码：${RUN_EXIT_CODE}"
        return "${RUN_EXIT_CODE}"
    fi
    return 0
}

# ======================== 主流程（容错+兼容+新增容器检测+高可见日志） ========================
main() {
    log INFO "===== Forge下载&安装脚本启动 ====="
    # 步骤1：加载配置
    if ! load_config; then
        log ERROR "加载配置失败，终止脚本"
        exit 1
    fi

    # 步骤2：校验核心匹配（核心不匹配则退出）
    if ! check_core_match; then
        log ERROR "核心匹配校验失败，终止脚本"
        exit 1
    fi
    
    # 步骤3：检测核心是否存在（存在则跳过下载）
    if check_core_exists; then
        if [ "${AUTO_RUN_SERVER}" = "true" ]; then
            run_server
        fi
        log SUCCESS "脚本执行完成（核心已存在）"
        exit 0
    fi

    # ====== 新增步骤：容器环境检测（下载逻辑前执行） ======
    check_container_env || {
        log WARN "容器环境检测失败（非致命错误，继续执行）"
    }

    # 步骤4：下载Forge安装器（新增容器检测后执行）
    if ! download_forge_installer; then
        log ERROR "Forge安装器下载失败，终止脚本"
        exit 1
    fi

    # 步骤5：安装Forge核心
    if ! install_forge_core; then
        log ERROR "Forge核心安装失败，终止脚本"
        exit 1
    fi
    
    # 步骤6：自动运行服务器（配置为true则执行）
    if [ "${AUTO_RUN_SERVER}" = "true" ]; then
        run_server
    fi

    log SUCCESS "===== Forge下载&安装脚本执行完成 ====="
    exit 0
}

# 启动主流程（兼容sh的脚本执行方式）
main "$@"
