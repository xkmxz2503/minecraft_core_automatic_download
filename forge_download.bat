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
    :: 1. 读取配置文件
    for /f "tokens=1,2 delims== eol=#" %%a in (script_config.txt) do (
        set "%%a=%%b"
    )

    :: 2. BMCLAPI配置
    set "BMCLAPI_DOMAIN=https://bmclapi2.bangbang93.com"
    set "BMCLAPI_API_URL=!BMCLAPI_DOMAIN!/forge/download"
    set "FORGE_BMCLAPI_URL=!BMCLAPI_API_URL!?mcversion=!FORGE_MINECRAFT_VERSION!&version=!FORGE_VERSION!&category=installer&format=jar"
    if defined FORGE_BRANCH set "FORGE_BMCLAPI_URL=!FORGE_BMCLAPI_URL!&branch=!FORGE_BRANCH!"

    :: 3. 官方源URL
    set "FORGE_OFFICIAL_URL=https://files.minecraftforge.net/maven/net/minecraftforge/forge/!FORGE_MINECRAFT_VERSION!-!FORGE_VERSION!/forge-!FORGE_MINECRAFT_VERSION!-!FORGE_VERSION!-installer.jar"

    :: 4. 安装器文件名
    set "FORGE_INSTALLER_NAME=forge-!FORGE_MINECRAFT_VERSION!-!FORGE_VERSION!-installer.jar"
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
    echo [INFO] 从BMCLAPI获取Forge真实下载地址...
    :: ========== 修复1：PowerShell输出重定向到nul，仅保留错误码传递 ==========
    powershell -Command "$ErrorActionPreference='Stop'; try { $req = [System.Net.HttpWebRequest]::Create('!FORGE_BMCLAPI_URL!'); $req.AllowAutoRedirect = $false; $req.UserAgent = 'Mozilla/5.0'; $res = $req.GetResponse(); $realUrl = $res.GetResponseHeader('Location'); $res.Close(); if ($realUrl -match '^/') { $realUrl = '!BMCLAPI_DOMAIN!' + $realUrl; } $realUrl = $realUrl -replace 'mirrors.ppuc.lol', 'bmclapi2.bangbang93.com'; [Console]::WriteLine('[INFO] BMCLAPI真实下载地址：' + $realUrl); Invoke-WebRequest -Uri $realUrl -OutFile '!FORGE_INSTALLER_NAME!' -UserAgent 'Mozilla/5.0' -TimeoutSec 30; [Console]::WriteLine('[SUCCESS] BMCLAPI下载完成：' + '!FORGE_INSTALLER_NAME!'); exit 0; } catch { [Console]::WriteLine('[ERROR] BMCLAPI调用失败：' + $_.Exception.Message); exit 1; }" > temp.log 2>&1
    
    :: 打印PowerShell日志（避免中文拆分）
    type temp.log
    del /f /q temp.log > nul 2>&1
    
    :: 检查BMCLAPI下载结果
    if exist "!FORGE_INSTALLER_NAME!" (
        echo [SUCCESS] BMCLAPI下载完成，文件：!FORGE_INSTALLER_NAME!
        exit /b 0
    )

    :: ========== 修复2：官方源同样处理输出，避免中文拆分 ==========
    echo [INFO] BMCLAPI下载失败，尝试官方源...
    powershell -Command "$ErrorActionPreference='Stop'; try { $req = [System.Net.HttpWebRequest]::Create('!FORGE_OFFICIAL_URL!'); $req.AllowAutoRedirect = $false; $res = $req.GetResponse(); $realUrl = $res.GetResponseHeader('Location'); [Console]::WriteLine('[INFO] 官方源真实地址：' + $realUrl); $wc = New-Object System.Net.WebClient; $wc.DownloadFile($realUrl, '!FORGE_INSTALLER_NAME!'); exit 0; } catch { [Console]::WriteLine('[ERROR] 官方源下载失败：' + $_.Exception.Message); exit 1; }" > temp.log 2>&1
    
    :: 打印官方源日志
    type temp.log
    del /f /q temp.log > nul 2>&1
    
    :: 最终检查
    if exist "!FORGE_INSTALLER_NAME!" (
        echo [SUCCESS] 官方源下载完成，文件：!FORGE_INSTALLER_NAME!
        exit /b 0
    )

    echo [ERROR] 所有源均下载失败
    exit /b 1

:install_forge_core
    echo [INFO] 安装Forge核心...
    java -jar !FORGE_INSTALLER_NAME! --installServer
    if !ERRORLEVEL! neq 0 exit /b 1
    del /f /q !FORGE_INSTALLER_NAME!
    exit /b 0

:run_server
    echo [INFO] 启动Forge服务器...
    java !FORGE_JAVA_ARGS! -jar forge-!FORGE_MINECRAFT_VERSION!-!FORGE_VERSION!-universal.jar nogui
    exit /b 0
