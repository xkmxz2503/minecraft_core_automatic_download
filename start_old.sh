#!/usr/bin/env bash
############################################许可证#################################################
# Copyright (C) 2024  Griefed
#
# 本脚本是自由软件；您可以重新分发它和/或
# 根据GNU Lesser General Public许可证的条款进行修改
# 许可证版本2.1或(由您选择)任何更新版本.
#
# 此库的分发希望它能有用,但无任何担保；
# 甚至没有隐含的适销性或特定用途适用性的担保.详见GNU
#  Lesser General Public许可证了解更多详情.
#
# 您应该已收到GNU Lesser General Public许可证的副本
# 随此库一起；如果没有,请写信给Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
#
# 完整许可证可在https:github.com/Griefed/ServerPackCreator/blob/main/LICENSE查看
############################################描述#################################################
#
# 用于轻松运行您的服务器包的启动脚本.为了更方便地运行此脚本,可以运行随服务器包一同提供的start.bat文件.
#
# 此启动脚本支持Forge、NeoForge、Fabric、Quilt和LegacyFabric以及它们所支持的Minecraft版本.
#
# 此脚本会根据随服务器包提供的variables.txt中的设置下载并安装模组加载器服务器.
# 如果未找到合适的Java安装,且您的$JAVA变量设置为"java",则会下载并提供合适的Java安装供此服务器包使用.
#
# 您可以通过在variables.txt中设置RESTART为true来让服务器自动重启.有关该文件中各种设置的更多信息,
# 请查看该文件.
############################################注意事项#################################################
#
# 启动脚本由ServerPackCreator 8.0.3生成.
# 用于生成此脚本的模板可在以下位置找到:
#   https://github.com/Griefed/ServerPackCreator/blob/8.0.3/serverpackcreator-api/src/main/resources/de/griefed/resources/server_files/default_template.sh
#
# Linux脚本旨在使用bash运行(由顶部的`#!/usr/bin/env bash`指示),
# 即只需调用`./start.sh`或`bash start.sh`.
# 使用其他方法可能可行,但也可能导致意外行为.
# 开发者未在MacOS上测试过Linux脚本,但有人曾在MacOS上运行过.
# 结果可能不同,不提供保证.
#
# 根据所设置的模组加载器,会运行不同的检查以确保服务器能够正常启动.
# 如果模组加载器检查和设置通过,将运行Minecraft和EULA检查.
# 如果一切正常,服务器将启动.
#
# 根据Minecraft版本,您需要不同的Java版本来运行服务器.
#   1.16.5及更早版本需要Java 8(Java 11会运行得更好,且与99%的模组兼容,不妨一试)
#     Linux:
#       您可以在此处获取Java 8安装:https://adoptium.net/temurin/releases/?variant=openjdk8&version=8&package=jdk&arch=x64&os=linux
#       您可以在此处获取Java 11安装:https://adoptium.net/temurin/releases/?variant=openjdk11&version=11&package=jdk&arch=x64&os=linux
#     macOS:
#       您可以在此处获取Java 8安装:https://adoptium.net/temurin/releases/?variant=openjdk8&version=8&package=jdk&arch=x64&os=mac
#       您可以在此处获取Java 11安装:https://adoptium.net/temurin/releases/?variant=openjdk11&version=11&package=jdk&arch=x64&os=mac
#   1.18.2及更新版本需要Java 17(Java 18会运行得更好,且与99%的模组兼容,不妨一试)
#     Linux:
#       您可以在此处获取Java 17安装:https://adoptium.net/temurin/releases/?variant=openjdk17&version=17&package=jdk&arch=x64&os=linux
#       您可以在此处获取Java 18安装:https://adoptium.net/temurin/releases/?variant=openjdk18&version=18&package=jdk&arch=x64&os=linux
#     macOS:
#       您可以在此处获取Java 17安装:https://adoptium.net/temurin/releases/?variant=openjdk17&version=17&package=jdk&arch=x64&os=mac
#       您可以在此处获取Java 18安装:https://adoptium.net/temurin/releases/?variant=openjdk18&version=18&package=jdk&arch=x64&os=mac
#   1.20.5及更新版本需要Java 21
#     Linux:
#       您可以在此处获取Java 21安装:https://adoptium.net/temurin/releases/?variant=openjdk21&version=21&package=jdk&arch=x64&os=linux
#     macOS:
#       您可以在此处获取Java 21安装:https://adoptium.net/temurin/releases/?variant=openjdk21&version=21&package=jdk&arch=x64&os=mac

# pause
# 暂停脚本执行.需要用户按任意键才能继续执行.
pause() {
  read -n 1 -s -r -p "按任意键继续"
}

# crashServer(reason)
# 以退出代码1终止脚本执行.在控制台打印$1.
crashServer() {
  echo "${1}"
  pause
  exit 1
}

# commandAvailable(command)
# 检查命令$1是否可用于执行.可在if语句中使用.
commandAvailable() {
  command -v "$1" > /dev/null 2>&1
}

# getJavaVersion
# 通过使用-fullversion检查$JAVA来设置$JAVA_VERSION.仅存储主版本,例如8、11、17、21.
getJavaVersion() {
  JAVA_VERSION=$("${JAVA}" -fullversion 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
  if [[ "$JAVA_VERSION" -eq 1 ]];then
    JAVA_VERSION=$("${JAVA}" -fullversion 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f2)
  fi
}

# installJava
# 运行配套脚本"install_java.sh"以安装此模组化Minecraft服务器所需的Java版本.
installJava() {
  echo "未在您的系统上找到合适的Java安装.开始进行Java安装."
  . install_java.sh || crashServer "Java安装脚本失败.请手动安装Java $RECOMMENDED_JAVA_VERSION 或在variables.txt中编辑JAVA以指向该版本的Java安装."
  if ! commandAvailable "$JAVA";then
    crashServer "Java安装失败.找不到 $JAVA."
  fi
}

# downloadIfNotExist(fileToCheck,fileToDownload,downloadURL)
# 检查文件$1是否存在.如果不存在,则从$3下载并存储为$2.可在if语句中使用.
downloadIfNotExist() {
  if [[ ! -s "${1}" ]]; then

    echo "${1} 未找到." >&2
    echo "正在下载 ${2}" >&2
    echo "来源 ${3}" >&2

    if commandAvailable curl ; then
      curl -# -L -o "./${2}" "${3}"
    elif commandAvailable wget ; then
      wget --show-progress -O "./${2}" "${3}"
    else
      crashServer "[错误] 需要wget或curl来下载文件."
    fi

    if [[ -s "${2}" ]]; then
      echo "下载完成." >&2
      echo "true"
    else
      echo "false"
    fi

  else
    echo "${1} 已存在." >&2
    echo "false"
  fi
}

# runJavaCommand(command)
# 使用$JAVA中设置的Java安装运行命令$1.
runJavaCommand() {
  # shellcheck disable=SC2086
  "$JAVA" ${1}
}

# refreshServerJar
# 刷新用于运行Forge和NeoForge服务器的ServerStarterJar.
# 根据variables.txt中的SERVERSTARTERJAR_FORCE_FETCH值,强制刷新server.jar.
# 含义:如果为true,将删除server.jar然后重新下载.
# 根据variables.txt中的SERVERSTARTERJAR_VERSION值获取不同版本.有关此值的更多信息,请参见variables.txt
refreshServerJar() {
  if [[ "${SERVERSTARTERJAR_FORCE_FETCH}" == "true" ]]; then
    rm -f server.jar
  fi

  if [[ "${SERVERSTARTERJAR_VERSION}" == "latest" ]]; then
    SERVERSTARTERJAR_DOWNLOAD_URL="https://github.com/neoforged/ServerStarterJar/releases/latest/download/server.jar"
  else
    SERVERSTARTERJAR_DOWNLOAD_URL="https://github.com/neoforged/ServerStarterJar/releases/download/${SERVERSTARTERJAR_VERSION}/server.jar"
  fi

  downloadIfNotExist "server.jar" "server.jar" "${SERVERSTARTERJAR_DOWNLOAD_URL}" >/dev/null
}

# cleanServerFiles
# 清理安装程序或模组加载器服务器创建的文件,但保留服务器包文件.
# 允许更改和重新安装模组加载器、Minecraft和模组加载器版本.
cleanServerFiles() {
  FILES_TO_REMOVE=(
    "libraries"
    "run.sh"
    "run.bat"
    "*installer.jar"
    "*installer.jar.log"
    "server.jar"
    ".mixin.out"
    "ldlib"
    "local"
    "fabric-server-launcher.jar"
    "fabric-server-launch.jar"
    ".fabric-installer"
    "fabric-installer.jar"
    "legacyfabric-installer.jar"
    ".fabric"
    "versions"
  )

  for FILE_TO_REMOVE in "${FILES_TO_REMOVE[@]}"
  do
    rm -r -v \
      "$FILE_TO_REMOVE" 2> /dev/null \
      && echo "已删除 $FILE_TO_REMOVE"
  done
}

# setupForge
#  为$MODLOADER_VERSION下载并安装Forge服务器.对于Minecraft 1.17及更新版本,将使用NeoForge组的ServerStarterJar.
# 这有助于使此服务器包与大多数托管公司兼容.
setupForge() {
  echo ""
  echo "正在运行Forge检查和设置..."
  FORGE_INSTALLER_URL="https://files.minecraftforge.net/maven/net/minecraftforge/forge/${MINECRAFT_VERSION}-${MODLOADER_VERSION}/forge-${MINECRAFT_VERSION}-${MODLOADER_VERSION}-installer.jar"
  FORGE_JAR_LOCATION="do_not_manually_edit"

  if [[ ${SEMANTICS[1]} -le 16 ]]; then
    FORGE_JAR_LOCATION="forge.jar"
    LAUNCHER_JAR_LOCATION="forge.jar"
    SERVER_RUN_COMMAND="${JAVA_ARGS} -jar ${LAUNCHER_JAR_LOCATION} nogui"

    if [[ $(downloadIfNotExist "${FORGE_JAR_LOCATION}" "forge-installer.jar" "${FORGE_INSTALLER_URL}") == "true" ]]; then

        echo "Forge安装程序已下载.正在安装..."
        runJavaCommand "-jar forge-installer.jar --installServer"

        echo "将 forge-${MINECRAFT_VERSION}-${MODLOADER_VERSION}.jar 重命名为 forge.jar"
        mv forge-"${MINECRAFT_VERSION}"-"${MODLOADER_VERSION}".jar forge.jar
        mv forge-"${MINECRAFT_VERSION}"-"${MODLOADER_VERSION}-universal".jar forge.jar

        if [[ -s "${FORGE_JAR_LOCATION}" ]]; then
          rm -f forge-installer.jar
          echo "安装完成.已删除forge-installer.jar."
        else
          rm -f forge-installer.jar
          crashServer "服务器安装过程中出现问题.请几分钟后重试,并检查您的互联网连接."
        fi

      fi
  else
    if [[ "${USE_SSJ}" == "false" ]]; then
      FORGE_JAR_LOCATION="libraries/net/minecraftforge/forge/${MINECRAFT_VERSION}-${MODLOADER_VERSION}/forge-${MINECRAFT_VERSION}-${MODLOADER_VERSION}-server.jar"
      SERVER_RUN_COMMAND="@user_jvm_args.txt @libraries/net/minecraftforge/forge/${MINECRAFT_VERSION}-${MODLOADER_VERSION}/unix_args.txt nogui"
      if [[ $(downloadIfNotExist "${FORGE_JAR_LOCATION}" "forge-installer.jar" "${FORGE_INSTALLER_URL}") == "true" ]]; then
        echo "Forge安装程序已下载.正在安装..."
        runJavaCommand "-jar forge-installer.jar --installServer"
      fi
    else
      SERVER_RUN_COMMAND="@user_jvm_args.txt -Djava.security.manager=allow -jar server.jar --installer-force --installer ${FORGE_INSTALLER_URL} nogui"
      # Download ServerStarterJar to server.jar
      refreshServerJar
    fi

    echo "从变量生成user_jvm_args.txt..."
    echo "在variables.txt中编辑JAVA_ARGS.不要直接编辑user_jvm_args.txt!"
    echo "对user_jvm_args.txt的手动修改将会丢失!"
    rm -f user_jvm_args.txt
    {
      echo "# Xmx和Xms分别设置最大和最小RAM使用量."
      echo "# 它们可以是任何数字,后跟M或G."
      echo "# M表示兆字节,G表示千兆字节."
      echo "# 例如,将最大值设置为3GB:-Xmx3G"
      echo "# 将最小值设置为2.5GB:-Xms2500M"
      echo "# 模组化服务器的一个不错的默认值是4GB."
      echo "# 取消下一行的注释进行设置."
      echo "# -Xmx4G"
      echo "${JAVA_ARGS}"
    } >>user_jvm_args.txt
  fi
}

# setupNeoForge
# 为$MODLOADER_VERSION下载并安装NeoForge服务器.使用NeoForge组的ServerStarterJar.
# 这有助于使此服务器包与大多数托管公司兼容.
setupNeoForge() {
  echo ""
  echo "正在运行NeoForge检查和设置..."
  echo "从变量生成user_jvm_args.txt..."
  echo "在variables.txt中编辑JAVA_ARGS.不要直接编辑user_jvm_args.txt!"
  echo "对user_jvm_args.txt的手动修改将会丢失!"
  rm -f user_jvm_args.txt
  {
    echo "# Xmx和Xms分别设置最大和最小RAM使用量."
    echo "# 它们可以是任何数字,后跟M或G."
    echo "# M表示兆字节,G表示千兆字节."
    echo "# 例如,将最大值设置为3GB:-Xmx3G"
    echo "# 将最小值设置为2.5GB:-Xms2500M"
    echo "# 模组化服务器的一个不错的默认值是4GB."
    echo "# 取消下一行的注释进行设置."
    echo "# -Xmx4G"
    echo "${JAVA_ARGS}"
  } >>user_jvm_args.txt

  if [[ ${SEMANTICS[1]} -eq 20 ]] && [[ ${#SEMANTICS[@]} -eq 2 || ${SEMANTICS[2]} -eq 1 ]]; then
    SERVER_RUN_COMMAND="@user_jvm_args.txt -jar server.jar --installer-force --installer https://maven.neoforged.net/releases/net/neoforged/forge/${MINECRAFT_VERSION}-${MODLOADER_VERSION}/forge-${MINECRAFT_VERSION}-${MODLOADER_VERSION}-installer.jar nogui"
  else
    SERVER_RUN_COMMAND="@user_jvm_args.txt -jar server.jar --installer-force --installer ${MODLOADER_VERSION} nogui"
  fi

  refreshServerJar
}

# setupFabric
# 为$MODLOADER_VERSION下载并安装Fabric服务器.如果Fabric启动器适用于$MINECRAFT_VERSION和$MODLOADER_VERSION,
# 则会下载并使用它,否则将下载并使用常规的Fabric安装程序.
# 还会检查Fabric是否适用于$MINECRAFT_VERSION和$MODLOADER_VERSION.
setupFabric() {
  echo ""
  echo "正在运行Fabric检查和设置..."

  FABRIC_INSTALLER_URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_INSTALLER_VERSION}/fabric-installer-${FABRIC_INSTALLER_VERSION}.jar"
  FABRIC_CHECK_URL="https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${MODLOADER_VERSION}/server/json"
  IMPROVED_FABRIC_LAUNCHER_URL="https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${MODLOADER_VERSION}/${FABRIC_INSTALLER_VERSION}/server/jar"

  if commandAvailable curl ; then
    FABRIC_AVAILABLE="$(curl -LI ${FABRIC_CHECK_URL} -o /dev/null -w '%{http_code}\n' -s)"
  elif commandAvailable wget ; then
    FABRIC_AVAILABLE="$(wget --server-response ${FABRIC_CHECK_URL}  2>&1 | awk '/^  HTTP/{print $2}')"
  fi
  if commandAvailable curl ; then
    IMPROVED_FABRIC_LAUNCHER_AVAILABLE="$(curl -LI ${IMPROVED_FABRIC_LAUNCHER_URL} -o /dev/null -w '%{http_code}\n' -s)"
  elif commandAvailable wget ; then
    IMPROVED_FABRIC_LAUNCHER_AVAILABLE="$(wget --server-response ${IMPROVED_FABRIC_LAUNCHER_URL}  2>&1 | awk '/^  HTTP/{print $2}')"
  fi

  if [[ "$IMPROVED_FABRIC_LAUNCHER_AVAILABLE" == "200" ]]; then
    echo "改进的Fabric服务器启动器可用..."
    echo "将使用改进的启动器来运行此Fabric服务器."
    LAUNCHER_JAR_LOCATION="fabric-server-launcher.jar"
    downloadIfNotExist "fabric-server-launcher.jar" "fabric-server-launcher.jar" "${IMPROVED_FABRIC_LAUNCHER_URL}" >/dev/null
  elif [[ "${FABRIC_AVAILABLE}" != "200" ]]; then
    crashServer "Fabric不适用于 Minecraft ${MINECRAFT_VERSION}, Fabric ${MODLOADER_VERSION}."
  elif [[ $(downloadIfNotExist "fabric-server-launch.jar" "fabric-installer.jar" "${FABRIC_INSTALLER_URL}") == "true" ]]; then

    echo "安装程序已下载..."
    LAUNCHER_JAR_LOCATION="fabric-server-launch.jar"
    runJavaCommand "-jar fabric-installer.jar server -mcversion ${MINECRAFT_VERSION} -loader ${MODLOADER_VERSION} -downloadMinecraft"

    if [[ -s "fabric-server-launch.jar" ]]; then
      rm -rf .fabric-installer
      rm -f fabric-installer.jar
      echo "安装完成.已删除fabric-installer.jar."
    else
      rm -f fabric-installer.jar
      crashServer "未找到fabric-server-launch.jar.可能是Fabric服务器出现问题.请几分钟后重试,并检查您的互联网连接."
    fi

  else
    echo "fabric-server-launch.jar已存在.继续..."
    LAUNCHER_JAR_LOCATION="fabric-server-launch.jar"
  fi

  SERVER_RUN_COMMAND="${JAVA_ARGS} -jar ${LAUNCHER_JAR_LOCATION} nogui"
}

# setupQuilt
# 为$MODLOADER_VERSION下载并安装Quilt服务器.
# 还会检查Quilt是否适用于$MINECRAFT_VERSION..
setupQuilt() {
  echo ""
  echo "正在运行Quilt检查和设置..."

  QUILT_INSTALLER_URL="https://maven.quiltmc.org/repository/release/org/quiltmc/quilt-installer/${QUILT_INSTALLER_VERSION}/quilt-installer-${QUILT_INSTALLER_VERSION}.jar"
  QUILT_CHECK_URL="https://meta.fabricmc.net/v2/versions/intermediary/${MINECRAFT_VERSION}"
  if commandAvailable curl ; then
    QUILT_AVAILABLE="$(curl -LI ${QUILT_CHECK_URL} -o /dev/null -w '%{http_code}\n' -s)"
  elif commandAvailable wget ; then
    QUILT_AVAILABLE="$(wget --server-response ${QUILT_CHECK_URL}  2>&1 | awk '/^  HTTP/{print $2}')"
  fi

  if [[ "${#QUILT_AVAILABLE}" -eq "2" ]]; then
    crashServer "Quilt不适用于 Minecraft ${MINECRAFT_VERSION}, Quilt ${MODLOADER_VERSION}."
  elif [[ $(downloadIfNotExist "quilt-server-launch.jar" "quilt-installer.jar" "${QUILT_INSTALLER_URL}") == "true" ]]; then
    echo "安装程序已下载.正在安装..."
    runJavaCommand "-jar quilt-installer.jar install server ${MINECRAFT_VERSION} --download-server --install-dir=."

    if [[ -s "quilt-server-launch.jar" ]]; then
      rm quilt-installer.jar
      echo "安装完成.已删除quilt-installer.jar."
    else
      rm -f quilt-installer.jar
      crashServer "未找到quilt-server-launch.jar.可能是Quilt服务器出现问题.请几分钟后重试,并检查您的互联网连接."
    fi

  fi

  LAUNCHER_JAR_LOCATION="quilt-server-launch.jar"
  SERVER_RUN_COMMAND="${JAVA_ARGS} -jar ${LAUNCHER_JAR_LOCATION} nogui"
}

# setupLegacyFabric
# 为$MODLOADER_VERSION下载并安装LegacyFabric服务器.
# 还会检查LegacyFabric是否适用于$MINECRAFT_VERSION.
setupLegacyFabric() {
  echo ""
  echo "正在运行LegacyFabric检查和设置..."

  LEGACYFABRIC_INSTALLER_URL="https://maven.legacyfabric.net/net/legacyfabric/fabric-installer/${LEGACYFABRIC_INSTALLER_VERSION}/fabric-installer-${LEGACYFABRIC_INSTALLER_VERSION}.jar"
  LEGACYFABRIC_CHECK_URL="https://meta.legacyfabric.net/v2/versions/loader/${MINECRAFT_VERSION}"
  if commandAvailable curl ; then
    LEGACYFABRIC_AVAILABLE="$(curl -LI ${LEGACYFABRIC_CHECK_URL} -o /dev/null -w '%{http_code}\n' -s)"
  elif commandAvailable wget ; then
    IMPROVED_FABRIC_LAUNCHER_AVAILABLE="$(wget --server-response ${LEGACYFABRIC_CHECK_URL}  2>&1 | awk '/^  HTTP/{print $2}')"
  fi

  if [[ "${#LEGACYFABRIC_AVAILABLE}" -eq "2" ]]; then
    crashServer "LegacyFabric不适用于 Minecraft ${MINECRAFT_VERSION}, LegacyFabric ${MODLOADER_VERSION}."
  elif [[ $(downloadIfNotExist "fabric-server-launch.jar" "legacyfabric-installer.jar" "${LEGACYFABRIC_INSTALLER_URL}") == "true" ]]; then
    echo "安装程序已下载.正在安装..."
    runJavaCommand "-jar legacyfabric-installer.jar server -mcversion ${MINECRAFT_VERSION} -loader ${MODLOADER_VERSION} -downloadMinecraft"

    if [[ -s "fabric-server-launch.jar" ]]; then
      rm legacyfabric-installer.jar
      echo "安装完成.已删除legacyfabric-installer.jar.."
    else
      rm -f legacyfabric-installer.jar
      crashServer "未找到fabric-server-launch.jar.可能是LegacyFabric服务器出现问题.请几分钟后重试,并检查您的互联网连接."
    fi

  fi

  LAUNCHER_JAR_LOCATION="fabric-server-launch.jar"
  SERVER_RUN_COMMAND="${JAVA_ARGS} -jar ${LAUNCHER_JAR_LOCATION} nogui"
}

echo "Start script generated by ServerPackCreator 8.0.3."
echo "To change the launch settings of this server, such as JVM args / flags, Minecraft version, modloader version etc., edit the variables.txt-file."

# 感谢StackOverflow的帮助:https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script/246128#246128
# 这段代码确保我们在包含此脚本的目录中工作.
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # 解析$SOURCE直到文件不再是符号链接
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # 如果$SOURCE是相对符号链接,我们需要相对于符号链接文件所在的路径解析它
done
DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
cd "${DIR}" >/dev/null 2>&1 || exit

# 检查此目录的路径是否包含空格.路径中的空格容易导致问题.
if [[ "${DIR}" == *" "*  ]]; then

    echo "警告!此脚本的当前位置包含空格.这可能导致服务器崩溃!"
    echo "强烈建议将此服务器包移动到路径中不包含空格的位置!"
    echo ""
    echo "当前路径:"
    echo "${PWD}"
    echo ""
    echo -n "您确定要继续吗？(yes/no): "
    read -r WHY

    if [[ "${WHY}" == "Yes" ]]; then
        echo "好吧.准备好面对未知的后果吧,弗里曼先生..."
    else
        crashServer "用户不希望在路径包含空格的目录中运行服务器."
    fi
fi

# 不建议使用root用户运行服务器,因为这会给您的系统带来安全风险.
# 使用普通用户即可.
if [[ "$(id -u)" == "0" ]]; then
  echo "警告!不建议使用管理员权限运行."
fi

if [[ ! -s "variables.txt" ]]; then
  crashServer "错误!variables.txt不存在.没有它,服务器无法安装、配置或启动."
fi

source "./variables.txt"

LAUNCHER_JAR_LOCATION="do_not_manually_edit"
SERVER_RUN_COMMAND="do_not_manually_edit"
JAVA_VERSION="do_not_manually_edit"
IFS="." read -ra SEMANTICS <<<"${MINECRAFT_VERSION}"

#如果需要进行Java检查,则会将可用的Java版本与Minecraft服务器所需的版本进行比较.
# 如果未找到Java,或可用版本不正确,则通过运行installJava安装所需版本..
if [[ "${SKIP_JAVA_CHECK}" == "true" ]]; then
  echo "跳过Java版本检查."
else
  if [[ "$JAVA" == "java" ]];then
    if ! commandAvailable "$JAVA" ; then
      installJava
    else
      getJavaVersion
      if [[ "$JAVA_VERSION" =~ [0-9]+ ]];then
        if [[ "$JAVA_VERSION" != "$RECOMMENDED_JAVA_VERSION" ]];then
          installJava
        fi
      else
        installJava
      fi
    fi
  else
    getJavaVersion
    echo "检测到 ${SEMANTICS[0]}.${SEMANTICS[1]}.${SEMANTICS[2]} - Java ${JAVA_VERSION}"
    if [[ "$JAVA_VERSION" != "$RECOMMENDED_JAVA_VERSION" ]];then
      JAVA="java"
      installJava
    fi
  fi
fi

# 检查并警告用户是否使用32位Java安装.实际上,这种情况越来越少,
# 但偶尔还是会发生.最好向用户发出警告.
"$JAVA" "-version" 2>&1 | grep -i "32-Bit" && echo "警告!检测到32位Java!强烈建议使用64位Java版本!"

if [[ "$1" == "--cleanup" ]]; then
  echo "正在运行清理..."
  cleanServerFiles
elif [[ -f "./.previousrun" ]]; then
  source "./.previousrun"
  if [[ "$PREVIOUS_MINECRAFT_VERSION" != "$MINECRAFT_VERSION" || \
        "$PREVIOUS_MODLOADER" != "$MODLOADER" || \
        "$PREVIOUS_MODLOADER_VERSION" != "$MODLOADER_VERSION" ]]; then
    echo "Minecraft版本、模组加载器或模组加载器版本已更改.正在清理..."
    cleanServerFiles
  fi
fi

echo "PREVIOUS_MINECRAFT_VERSION=${MINECRAFT_VERSION}" >"./.previousrun"
echo "PREVIOUS_MODLOADER=${MODLOADER}" >>"./.previousrun"
echo "PREVIOUS_MODLOADER_VERSION=${MODLOADER_VERSION}" >>"./.previousrun"

case ${MODLOADER} in
  "Forge")
    setupForge
    ;;
  "NeoForge")
    setupNeoForge
    ;;
  "Fabric")
    setupFabric
    ;;
  "Quilt")
    setupQuilt
    ;;
  "LegacyFabric")
    setupLegacyFabric
    ;;
  *)
    crashServer "指定的模组加载器不正确: ${MODLOADER}"
esac

echo ""
if [[ ! -s "eula.txt" ]]; then

  echo "尚未接受Mojang的EULA.要运行Minecraft服务器,您必须接受Mojang的EULA."
  echo "Mojang的EULA可在https://aka.ms/MinecraftEULA查看"
  echo "如果您同意Mojang的EULA,请输入'I agree'"
  echo -n "Response: "
  read -r ANSWER

  if [[ "${ANSWER}" == "I agree" ]]; then
    echo "用户同意Mojang的EULA."
    echo "#通过将以下设置更改为TRUE,您表示同意我们的EULA(https://aka.ms/MinecraftEULA)." >eula.txt
    echo "eula=true" >>eula.txt
  else
    crashServer "用户未同意Mojang的EULA.输入内容:${ANSWER}.除非您同意Mojang的EULA,否则无法运行Minecraft服务器."
  fi

fi

echo ""
echo "正在启动服务器..."
echo "Minecraft版本:              ${MINECRAFT_VERSION}"
echo "模组加载器:                  ${MODLOADER}"
echo "模组加载器版本:              ${MODLOADER_VERSION}"
echo "LegacyFabric安装程序版本:${LEGACYFABRIC_INSTALLER_VERSION}"
echo "Fabric安装程序版本:       ${FABRIC_INSTALLER_VERSION}"
echo "Quilt安装程序版本:        ${QUILT_INSTALLER_VERSION}"
echo "Java参数:                      ${JAVA_ARGS}"
echo "附加参数:                ${ADDITIONAL_ARGS}"
echo "Java路径:                      ${JAVA}"
echo "等待用户输入:            ${WAIT_FOR_USER_INPUT}"
if [[ "${LAUNCHER_JAR_LOCATION}" != "do_not_manually_edit" ]];then
    echo "启动器JAR:                   ${LAUNCHER_JAR_LOCATION}"
fi
echo "运行命令:       ${JAVA} ${ADDITIONAL_ARGS} ${SERVER_RUN_COMMAND}"
echo "Java版本:"
"${JAVA}" -version
echo ""

# 根据$RESTART,服务器会在循环中运行,以确保崩溃后能立即重启.可以通过多次按CTRL+C强制退出.
# 服务器运行之间不会重新加载变量.如果希望重新加载变量,请退出脚本并重新运行.
while true
do
  runJavaCommand "${ADDITIONAL_ARGS} ${SERVER_RUN_COMMAND}"
  if [[ "${SKIP_JAVA_CHECK}" == "true" ]]; then
    echo "已跳过Java版本检查.服务器是否因Java版本不匹配而停止或崩溃?"
    echo "检测到 ${SEMANTICS[0]}.${SEMANTICS[1]}.${SEMANTICS[2]} - Java ${JAVA_VERSION}, 推荐版本为 $RECOMMENDED_JAVA_VERSION."
  fi
  if [[ "${RESTART}" != "true" ]]; then
    echo "正在退出..."
      if [[ "${WAIT_FOR_USER_INPUT}" == "true" ]]; then
        pause
      fi
    exit 0
  fi
  echo "服务器将在5秒后自动重启.按CTRL + C中止并退出."
  sleep 5
done

echo ""
