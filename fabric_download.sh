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
    FABRIC_BMCLAPI_URL=${FABRIC_BMCLAPI_URL//%MINECRAFT_VERSION%/$FABRIC_MINECRAFT_VERSION}
    FABRIC_BMCLAPI_URL=${FABRIC_BMCLAPI_URL//%LOADER_VERSION%/$FABRIC_LOADER_VERSION}
    FABRIC_BMCLAPI_URL=${FABRIC_BMCLAPI_URL//%LAUNCHER_VERSION%/$FABRIC_LAUNCHER_VERSION}
    FABRIC_OFFICIAL_URL=${FABRIC_OFFICIAL_URL//%MINECRAFT_VERSION%/$FABRIC_MINECRAFT_VERSION}
    FABRIC_OFFICIAL_URL=${FABRIC_OFFICIAL_URL//%LOADER_VERSION%/$FABRIC_LOADER_VERSION}
    FABRIC_OFFICIAL_URL=${FABRIC_OFFICIAL_URL//%LAUNCHER_VERSION%/$FABRIC_LAUNCHER_VERSION}
    
    # 定义核心文件名
    export FABRIC_JAR_NAME="fabric-server-mc.${FABRIC_MINECRAFT_VERSION}-loader.${FABRIC_LOADER_VERSION}-launcher.${FABRIC_LAUNCHER_VERSION}.jar"
}

# ======================== 模块2：校验核心匹配 ========================
check_core_match() {
    if [[ "$TARGET_CORE" != "fabric" ]]; then
        return 1
    fi
    return 0
}

# ======================== 模块3：检测核心是否已存在 ========================
check_core_exists() {
    if [[ "$CHECK_CORE_EXIST" == "false" ]]; then
        return 1
    fi
    if [[ -f "$FABRIC_JAR_NAME" ]]; then
        return 0
    fi
    return 1
}

# ======================== 模块4：下载Fabric核心 ========================
download_fabric_core() {
    # 优先BMCLAPI下载
    echo "[INFO] 从BMCLAPI下载Fabric核心..."
    if command -v curl >/dev/null 2>&1; then
        curl -# -L -OJ "$FABRIC_BMCLAPI_URL" || true
    elif command -v wget >/dev/null 2>&1; then
        wget --show-progress -O "$FABRIC_JAR_NAME" "$FABRIC_BMCLAPI_URL" || true
    else
        echo "[ERROR] 缺少curl/wget，无法下载文件"
        return 1
    fi

    # 校验下载结果
    if [[ -s "$FABRIC_JAR_NAME" ]]; then
        return 0
    fi

    # 兜底官方源
    echo "[INFO] BMCLAPI下载失败，尝试官方源..."
    if command -v curl >/dev/null 2>&1; then
        curl -# -L -OJ "$FABRIC_OFFICIAL_URL" || true
    elif command -v wget >/dev/null 2>&1; then
        wget --show-progress -O "$FABRIC_JAR_NAME" "$FABRIC_OFFICIAL_URL" || true
    else
        return 1
    fi

    if [[ -s "$FABRIC_JAR_NAME" ]]; then
        return 0
    fi
    return 1
}

# ======================== 模块5：自动运行服务器 ========================
run_server() {
    echo "[INFO] 启动Fabric服务器..."
    java $FABRIC_JAVA_ARGS -jar "$FABRIC_JAR_NAME" nogui
    return 0
}

# ======================== 主流程 ========================
main() {
    load_config || { echo "[ERROR] 加载配置失败"; exit 1; }
    check_core_match || { echo "[ERROR] 核心不匹配"; exit 1; }
    
    if check_core_exists; then
        echo "[INFO] Fabric核心已存在，跳过下载"
        if [[ "$AUTO_RUN_SERVER" == "true" ]]; then
            run_server
        fi
        exit 0
    fi

    download_fabric_core || { echo "[ERROR] 下载失败"; exit 1; }
    
    if [[ "$AUTO_RUN_SERVER" == "true" ]]; then
        run_server
    fi

    echo "[INFO] Fabric核心下载完成"
    exit 0
}

main
