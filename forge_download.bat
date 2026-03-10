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
    echo [INFO] Forge核心已存在，跳过下载
    if !AUTO_RUN_SERVER! equ true call :run_server
    pause
    exit /b 0
)

:: ======================== 模块4：下载Forge安装器 ========================
call :download_forge_installer
if !ERRORLEVEL! neq 0 (
    echo [ERROR] Forge安装器下载失败
    pause
    exit /b 1
)

:: ======================== 模块5：安装Forge核心 ========================
call :install_forge_core
if !ERRORLEVEL! neq 0 (
    echo [ERROR] Forge核心安装失败
    pause
    exit /b 1
)

:: ======================== 模块6：自动运行服务器 ========================
if !AUTO_RUN_SERVER! equ true call :run_server

echo [INFO] Forge核心下载&安装完成
pause
exit /b 0

:: ----------------------- 函数定义 -----------------------
:load_config
    :: 读取配置文件
    for /f "tokens=1,2 delims==" %%a in (script_config.txt) do (
        set "%%a=%%b"
    )
    :: 替换变量占位符
    set "FORGE_BMCLAPI_URL=!FORGE_BMCLAPI_URL:%MINECRAFT_VERSION%=%FORGE_MINECRAFT_VERSION%!"
    set "FORGE_BMCLAPI_URL=!FORGE_BMCLAPI_URL:%FORGE_VERSION%=%FORGE_VERSION%!"
    set "FORGE_OFFICIAL_URL=!FORGE_OFFICIAL_URL:%MINECRAFT_VERSION%=%FORGE_MINECRAFT_VERSION%!"
    set "FORGE_OFFICIAL_URL=!FORGE_OFFICIAL_URL:%FORGE_VERSION%=%FORGE_VERSION%!"
    exit /b 0

:check_core_match
    if /i not "!TARGET_CORE!"=="forge" (
        exit /b 1
    )
    exit /b 0

:check_core_exists
    if "!CHECK_CORE_EXIST!"=="false" exit /b 1
    if exist "forge-!FORGE_MINECRAFT_VERSION!-!FORGE_VERSION!-universal.jar" exit /b 0
    exit /b 1

:download_forge_installer
    :: 优先BMCLAPI下载
    echo [INFO] 从BMCLAPI下载Forge安装器...
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('!FORGE_BMCLAPI_URL!', 'forge-installer.jar')"
    if exist "forge-installer.jar" exit /b 0

    :: 兜底官方源
    echo [INFO] BMCLAPI下载失败，尝试官方源...
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('!FORGE_OFFICIAL_URL!', 'forge-installer.jar')"
    if exist "forge-installer.jar" exit /b 0
    exit /b 1

:install_forge_core
    echo [INFO] 安装Forge核心...
    java -jar forge-installer.jar --installServer
    if !ERRORLEVEL! neq 0 exit /b 1
    :: 删除安装器
    del /f /q forge-installer.jar
    exit /b 0

:run_server
    echo [INFO] 启动Forge服务器...
    java !FORGE_JAVA_ARGS! -jar forge-!FORGE_MINECRAFT_VERSION!-!FORGE_VERSION!-universal.jar nogui
    exit /b 0
