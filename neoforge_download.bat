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
    echo [INFO] NeoForge核心已存在，跳过下载
    if !AUTO_RUN_SERVER! equ true call :run_server
    pause
    exit /b 0
)

:: ======================== 模块4：下载NeoForge安装器 ========================
call :download_neoforge_installer
if !ERRORLEVEL! neq 0 (
    echo [ERROR] NeoForge安装器下载失败
    pause
    exit /b 1
)

:: ======================== 模块5：安装NeoForge核心 ========================
call :install_neoforge_core
if !ERRORLEVEL! neq 0 (
    echo [ERROR] NeoForge核心安装失败
    pause
    exit /b 1
)

:: ======================== 模块6：自动运行服务器 ========================
if !AUTO_RUN_SERVER! equ true call :run_server

echo [INFO] NeoForge核心下载&安装完成
pause
exit /b 0

:: ----------------------- 函数定义 -----------------------
:load_config
    :: 读取配置文件
    for /f "tokens=1,2 delims==" %%a in (script_config.txt) do (
        set "%%a=%%b"
    )
    :: 替换变量占位符
    set "NEOFORGE_BMCLAPI_URL=!NEOFORGE_BMCLAPI_URL:%MINECRAFT_VERSION%=%NEOFORGE_MINECRAFT_VERSION%!"
    set "NEOFORGE_BMCLAPI_URL=!NEOFORGE_BMCLAPI_URL:%NEOFORGE_VERSION%=%NEOFORGE_VERSION%!"
    set "NEOFORGE_OFFICIAL_URL=!NEOFORGE_OFFICIAL_URL:%MINECRAFT_VERSION%=%NEOFORGE_MINECRAFT_VERSION%!"
    set "NEOFORGE_OFFICIAL_URL=!NEOFORGE_OFFICIAL_URL:%NEOFORGE_VERSION%=%NEOFORGE_VERSION%!"
    exit /b 0

:check_core_match
    if /i not "!TARGET_CORE!"=="neoforge" (
        exit /b 1
    )
    exit /b 0

:check_core_exists
    if "!CHECK_CORE_EXIST!"=="false" exit /b 1
    if exist "neoforge-!NEOFORGE_MINECRAFT_VERSION!-!NEOFORGE_VERSION!-universal.jar" exit /b 0
    exit /b 1

:download_neoforge_installer
    :: 优先BMCLAPI下载
    echo [INFO] 从BMCLAPI下载NeoForge安装器...
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('!NEOFORGE_BMCLAPI_URL!', 'neoforge-installer.jar')"
    if exist "neoforge-installer.jar" exit /b 0

    :: 兜底官方源
    echo [INFO] BMCLAPI下载失败，尝试官方源...
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('!NEOFORGE_OFFICIAL_URL!', 'neoforge-installer.jar')"
    if exist "neoforge-installer.jar" exit /b 0
    exit /b 1

:install_neoforge_core
    echo [INFO] 安装NeoForge核心...
    java -jar neoforge-installer.jar --installServer
    :: 删除安装器
    del /f /q neoforge-installer.jar
    exit /b 0

:run_server
    echo [INFO] 启动NeoForge服务器...
    java !NEOFORGE_JAVA_ARGS! -jar neoforge-!NEOFORGE_MINECRAFT_VERSION!-!NEOFORGE_VERSION!-universal.jar nogui
    exit /b 0
