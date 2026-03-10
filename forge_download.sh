#!/usr/bin/env bash
set -euo pipefail
export LANG=zh_CN.UTF-8

# ======================== 模块1：加载配置文件 ========================
load_config() {
    # 读取配置文件
    while IFS='=' read -r key value; do
        if [[ ! -z "$key" && ! "$key" =~ ^# ]]; then
            export "$key=$value"
        fi
    done < script_config.txt

    # 替换变量占位符
    FORGE_BMCLAPI_URL=${FORGE_BMCLAPI_URL//%MINECRAFT_VERSION%/$FORGE_MINECRAFT_VERSION}
    FORGE_BMCLAPI_URL=${FORGE_BMCLAPI_URL//%FORGE_VERSION%/$FORGE_VERSION}
    FORGE_OFFICIAL_URL=${FORGE_OFFICIAL_URL//%MINECRAFT_VERSION%/$FORGE_MINECRAFT_VERSION}
    FORGE_OFFICIAL_URL=${FORGE_OFFICIAL_URL//%FORGE_VERSION%/$FORGE_VERSION}
}

# ======================== 模块2：校验核心匹配 ========================
check_core_match() {
    if [[ "$TARGET_CORE" != "forge" ]]; then
        return 1
    fi
    return 0
}

# ======================== 模块3：检测核心是否已存在 ========================
check_core_exists() {
    if [[ "$CHECK_CORE_EXIST" == "false" ]]; then
        return 1
    fi
    if [[ -f "forge-${FORGE_MINECRAFT_VERSION}-${FORGE_VERSION}-universal.jar" ]]; then
        return 0
    fi
    return 1
}

# ======================== 模块4：下载Forge安装器 ========================
download_forge_installer() {
    # 优先BMCLAPI下载
    echo "[INFO] 从BMCLAPI下载Forge安装器..."
    if command -v curl >/dev/null 2>&1; then
        curl -# -L -o "forge-installer.jar" "$FORGE_BMCLAPI_URL" || true
    elif command -v wget >/dev/null 2>&1; then
        wget --show-progress -O "forge-installer.jar" "$FORGE_BMCLAPI_URL" || true
    else
        echo "[ERROR] 缺少curl/wget，无法下载文件"
        return 1
    fi

    # 校验下载结果
    if [[ -s "forge-installer.jar" ]]; then
        return 0
    fi

    # 兜底官方源
    echo "[INFO] BMCLAPI下载失败，尝试官方源..."
    if command -v curl >/dev/null 2>&1; then
        curl -# -L -o "forge-installer.jar" "$FORGE_OFFICIAL_URL" || true
    elif command -v wget >/dev/null 2>&1; then
        wget --show-progress -O "forge-installer.jar" "$FORGE_OFFICIAL_URL" || true
    else
        return 1
    fi

    if [[ -s "forge-installer.jar" ]]; then
        return 0
    fi
    return 1
}

# ======================== 模块5：安装Forge核心 ========================
install_forge_core() {
    echo "[INFO] 安装Forge核心..."
    java -jar forge-installer.jar --installServer
    # 删除安装器
    rm -f forge-installer.jar
    return 0
}

# ======================== 模块6：自动运行服务器 ========================
run_server() {
    echo "[INFO] 启动Forge服务器..."
    java $FORGE_JAVA_ARGS -jar forge-${FORGE_MINECRAFT_VERSION}-${FORGE_VERSION}-universal.jar nogui
    return 0
}

# ======================== 主流程 ========================
main() {
    load_config || { echo "[ERROR] 加载配置失败"; exit 1; }
    check_core_match || { echo "[ERROR] 核心不匹配"; exit 1; }
    
    if check_core_exists; then
        echo "[INFO] Forge核心已存在，跳过下载"
        if [[ "$AUTO_RUN_SERVER" == "true" ]]; then
            run_server
        fi
        exit 0
    fi

    download_forge_installer || { echo "[ERROR] 下载失败"; exit 1; }
    install_forge_core || { echo "[ERROR] 安装失败"; exit 1; }
    
    if [[ "$AUTO_RUN_SERVER" == "true" ]]; then
        run_server
    fi

    echo "[INFO] Forge核心下载&安装完成"
    exit 0
}

main
