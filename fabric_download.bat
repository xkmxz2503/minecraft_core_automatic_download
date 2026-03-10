@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

:: ======================== 模块1：加载配置文件 ========================
call :load_config
if !ERRORLEVEL! neq 0 (
    echo [ERROR] 加载配置文件失败
    pause
    exit /b 1
)

:: ======================== 模块2：校验核心匹配 ========================
call :check_core_match
if !ERRORLEVEL! neq 0 (
    echo [ERROR] 脚本与配置文件指定核心不匹配
    pause
    exit /b 1
)

:: ======================== 模块3：检测核心是否已存在 ========================
call :check_core_exists
if !ERRORLEVEL! equ 0 (
    echo [INFO] Fabric核心已存在，跳过下载
    if !AUTO_RUN_SERVER! equ true call :run_server
    pause
    exit /b 0
)

:: ======================== 模块4：下载Fabric核心 ========================
call :download_fabric_core
if !ERRORLEVEL! neq 0 (
    echo [ERROR] Fabric核心下载失败
    pause
    exit /b 1
)

:: ======================== 模块5：自动运行服务器 ========================
if !AUTO_RUN_SERVER! equ true call :run_server

echo [INFO] Fabric核心下载完成
pause
exit /b 0

:: ----------------------- 函数定义 -----------------------
:load_config
    :: 读取配置文件
    for /f "tokens=1,2 delims==" %%a in (script_config.txt) do (
        set "%%a=%%b"
    )
    :: 替换变量占位符
    set "FABRIC_BMCLAPI_URL=!FABRIC_BMCLAPI_URL:%MINECRAFT_VERSION%=%FABRIC_MINECRAFT_VERSION%!"
    set "FABRIC_BMCLAPI_URL=!FABRIC_BMCLAPI_URL:%LOADER_VERSION%=%FABRIC_LOADER_VERSION%!"
    set "FABRIC_BMCLAPI_URL=!FABRIC_BMCLAPI_URL:%LAUNCHER_VERSION%=%FABRIC_LAUNCHER_VERSION%!"
    set "FABRIC_OFFICIAL_URL=!FABRIC_OFFICIAL_URL:%MINECRAFT_VERSION%=%FABRIC_MINECRAFT_VERSION%!"
    set "FABRIC_OFFICIAL_URL=!FABRIC_OFFICIAL_URL:%LOADER_VERSION%=%FABRIC_LOADER_VERSION%!"
    set "FABRIC_OFFICIAL_URL=!FABRIC_OFFICIAL_URL:%LAUNCHER_VERSION%=%FABRIC_LAUNCHER_VERSION%!"
    :: 定义核心文件名
    set "FABRIC_JAR_NAME=fabric-server-mc.!FABRIC_MINECRAFT_VERSION!-loader.!FABRIC_LOADER_VERSION!-launcher.!FABRIC_LAUNCHER_VERSION!.jar"
    exit /b 0

:check_core_match
    if /i not "!TARGET_CORE!"=="fabric" (
        exit /b 1
    )
    exit /b 0

:check_core_exists
    if "!CHECK_CORE_EXIST!"=="false" exit /b 1
    if exist "!FABRIC_JAR_NAME!" exit /b 0
    exit /b 1

:download_fabric_core
    :: 优先BMCLAPI下载
    echo [INFO] 从BMCLAPI下载Fabric核心...
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('!FABRIC_BMCLAPI_URL!', '!FABRIC_JAR_NAME!')"
    if exist "!FABRIC_JAR_NAME!" exit /b 0

    :: 兜底官方源
    echo [INFO] BMCLAPI下载失败，尝试官方源...
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('!FABRIC_OFFICIAL_URL!', '!FABRIC_JAR_NAME!')"
    if exist "!FABRIC_JAR_NAME!" exit /b 0
    exit /b 1

:run_server
    echo [INFO] 启动Fabric服务器...
    java !FABRIC_JAVA_ARGS! -jar !FABRIC_JAR_NAME! nogui
    exit /b 0
