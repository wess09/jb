# 生成随机字符串的函数
function Generate-RandomString {
    param(
        [int]$length
    )
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $chars.length }
    $private:ofs=""
    return [String]$chars[$random]
}

# 一键部署 nekro-agent 插件脚本

# 检查是否以管理员权限运行
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "请以管理员权限运行此脚本！" -ForegroundColor Red
    exit 1
}

# 检查 Docker 安装情况
try {
    docker --version | Out-Null
} catch {
    $answer = Read-Host "Docker 未安装，是否安装？[Y/n]"
    if ($answer -eq "" -or $answer -eq "y" -or $answer -eq "Y") {
        Write-Host "请访问 https://www.docker.com/products/docker-desktop 下载并安装 Docker Desktop for Windows"
        Write-Host "安装完成后重新运行此脚本"
        exit 1
    } else {
        Write-Host "Error: Docker 未安装。请先安装 Docker 后再运行该脚本。" -ForegroundColor Red
        exit 1
    }
}

# 检查 Docker Compose 安装情况
try {
    docker-compose --version | Out-Null
} catch {
    Write-Host "Docker Compose 未安装，正在安装..."
    Write-Host "Docker Desktop for Windows 已包含 Docker Compose，请确保正确安装 Docker Desktop"
    exit 1
}

# 设置应用目录路径为脚本所在目录
if (-not $env:NEKRO_ENV_DIR) {
    $env:NEKRO_ENV_DIR = "$PSScriptRoot"
}

# 设置WSL内部路径
# 如果环境变量 NEKRO_DATA_DIR 未设置，则需要将 Windows 路径转换为 WSL 路径格式
if (-not $env:NEKRO_DATA_DIR) {
    $env:NEKRO_DATA_DIR = "/mnt/wsl/docker-desktop/nekro_agent_data/"
}

Write-Host "WSL路径 NEKRO_DATA_DIR: $env:NEKRO_DATA_DIR"

# 创建应用目录
try {
    New-Item -ItemType Directory -Force -Path $PSScriptRoot | Out-Null
} catch {
    Write-Host "Error: 无法创建应用目录 $PSScriptRoot，请检查您的权限配置。" -ForegroundColor Red
    exit 1
}

# 进入应用目录
Set-Location $PSScriptRoot

# 如果当前目录没有 .env 文件，从仓库获取.env.example 并修改 .env 文件
if (-not (Test-Path ".env")) {
    Write-Host "未找到.env文件，正在从仓库获取.env.example..."
    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KroMiose/nekro-agent/main/docker/.env.example" -OutFile "$env:NEKRO_ENV_DIR\.env.temp"
    } catch {
        Write-Host "Error: 无法获取.env.example文件，请检查网络连接或手动创建.env文件。" -ForegroundColor Red
        exit 1
    }

    # 替换或添加 NEKRO_DATA_DIR
    $envContent = Get-Content ".env.temp" -Raw
    if ($envContent -match "^NEKRO_DATA_DIR=") {
        $envContent = $envContent -replace "^NEKRO_DATA_DIR=.*", "NEKRO_DATA_DIR=$($env:NEKRO_DATA_DIR -replace '\\', '/')"
    # 移除重复的驱动器字母
    $envContent = $envContent -replace '([A-Za-z]):/+([A-Za-z]):', '$1:/'
    } else {
        $envContent += "`nNEKRO_DATA_DIR=$($env:NEKRO_DATA_DIR -replace "\\", "/")"
    }

    # 生成随机的 ONEBOT_ACCESS_TOKEN 和 NEKRO_ADMIN_PASSWORD（如果它们为空）
    if ($envContent -notmatch "ONEBOT_ACCESS_TOKEN=") {
        $ONEBOT_ACCESS_TOKEN = Generate-RandomString -length 32
        $envContent += "`nONEBOT_ACCESS_TOKEN=$ONEBOT_ACCESS_TOKEN"
    } elseif ($envContent -match "ONEBOT_ACCESS_TOKEN=\s*$") {
        $ONEBOT_ACCESS_TOKEN = Generate-RandomString -length 32
        $envContent = $envContent -replace "ONEBOT_ACCESS_TOKEN=\s*$", "ONEBOT_ACCESS_TOKEN=$ONEBOT_ACCESS_TOKEN"
    }

    if ($envContent -notmatch "NEKRO_ADMIN_PASSWORD=") {
        $NEKRO_ADMIN_PASSWORD = Generate-RandomString -length 16
        $envContent += "`nNEKRO_ADMIN_PASSWORD=$NEKRO_ADMIN_PASSWORD"
    } elseif ($envContent -match "NEKRO_ADMIN_PASSWORD=\s*$") {
        $NEKRO_ADMIN_PASSWORD = Generate-RandomString -length 16
        $envContent = $envContent -replace "NEKRO_ADMIN_PASSWORD=\s*$", "NEKRO_ADMIN_PASSWORD=$NEKRO_ADMIN_PASSWORD"
    }

    # 将修改后的内容写入 .env 文件
    $envContent | Set-Content "$PSScriptRoot\.env" -NoNewline
    Remove-Item "$PSScriptRoot\.env.temp" -Force
    Write-Host "已获取并修改 .env 模板。"
} else {
    # 如果已存在 .env 文件，检查并更新密钥
    $envContent = Get-Content ".env" -Raw
    if ($envContent -notmatch "ONEBOT_ACCESS_TOKEN=") {
        $ONEBOT_ACCESS_TOKEN = Generate-RandomString -length 32
        $envContent += "`nONEBOT_ACCESS_TOKEN=$ONEBOT_ACCESS_TOKEN"
        $envContent | Set-Content ".env" -NoNewline
    } elseif ($envContent -match "ONEBOT_ACCESS_TOKEN=\s*$" -or $envContent -match "ONEBOT_ACCESS_TOKEN=$") {
        $ONEBOT_ACCESS_TOKEN = Generate-RandomString -length 32
        $envContent = $envContent -replace "^ONEBOT_ACCESS_TOKEN=\s*$|^ONEBOT_ACCESS_TOKEN=$", "ONEBOT_ACCESS_TOKEN=$ONEBOT_ACCESS_TOKEN"
        $envContent | Set-Content ".env" -NoNewline
    }

    if ($envContent -notmatch "NEKRO_ADMIN_PASSWORD=") {
        $NEKRO_ADMIN_PASSWORD = Generate-RandomString -length 16
        $envContent += "`nNEKRO_ADMIN_PASSWORD=$NEKRO_ADMIN_PASSWORD"
        $envContent | Set-Content ".env" -NoNewline
    } elseif ($envContent -match "NEKRO_ADMIN_PASSWORD=\s*$|NEKRO_ADMIN_PASSWORD=$") {
        $NEKRO_ADMIN_PASSWORD = Generate-RandomString -length 16
        $envContent = $envContent -replace "^NEKRO_ADMIN_PASSWORD=\s*$|^NEKRO_ADMIN_PASSWORD=$", "NEKRO_ADMIN_PASSWORD=$NEKRO_ADMIN_PASSWORD"
        $envContent | Set-Content ".env" -NoNewline
    }
}

# 从.env文件加载环境变量
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $key = $matches[1]
            $value = $matches[2]
            [Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Process)
        }
    }

    # 确保必要的环境变量存在
    if (-not $env:NEKRO_EXPOSE_PORT) {
        Write-Host "Error: NEKRO_EXPOSE_PORT 未在 .env 文件中设置" -ForegroundColor Red
        exit 1
    }
    if (-not $env:NAPCAT_EXPOSE_PORT) {
        Write-Host "Error: NAPCAT_EXPOSE_PORT 未在 .env 文件中设置" -ForegroundColor Red
        exit 1
    }
}

$answer = Read-Host "请检查并按需修改.env文件中的配置，未修改则按照默认配置安装，确认是否继续安装？[Y/n]"
if ($answer -eq "n" -or $answer -eq "N") {
    Write-Host "安装已取消"
    exit 0
}

# 拉取 docker-compose.yml 文件
Write-Host "正在拉取 docker-compose.yml 文件..."
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KroMiose/nekro-agent/main/docker/docker-compose-x-napcat.yml" -OutFile "$PSScriptRoot\docker-compose.yml"
    
} catch {
    Write-Host "Error: 无法拉取 docker-compose.yml 文件，请检查您的网络连接。" -ForegroundColor Red
    exit 1
}

# 启动服务
if (Test-Path ".env") {
    Write-Host "使用实例名称: $env:INSTANCE_NAME"
    Write-Host "启动主服务中..."
    try {
        docker-compose --env-file .env up -d
    } catch {
        Write-Host "Error: 无法启动主服务，请检查 Docker Compose 配置。" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Error: .env 文件不存在" -ForegroundColor Red
    exit 1
}

# 拉取沙盒镜像
Write-Host "拉取沙盒镜像..."
try {
    docker pull kromiose/nekro-agent-sandbox
} catch {
    Write-Host "Error: 无法拉取沙盒镜像，请检查您的网络连接。" -ForegroundColor Red
    exit 1
}

# 配置防火墙规则
Write-Host "`n正在配置防火墙..."
Write-Host "放行 NekroAgent 主服务端口 $($env:NEKRO_EXPOSE_PORT)..."
try {
    New-NetFirewallRule -DisplayName "NekroAgent" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $env:NEKRO_EXPOSE_PORT | Out-Null
} catch {
    Write-Host "Warning: 无法配置防火墙规则，如服务访问受限，请手动配置防火墙。" -ForegroundColor Yellow
}

Write-Host "放行 NapCat 服务端口 $($env:NAPCAT_EXPOSE_PORT)..."
try {
    New-NetFirewallRule -DisplayName "NapCat" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $env:NAPCAT_EXPOSE_PORT | Out-Null
} catch {
    Write-Host "Warning: 无法配置防火墙规则，如服务访问受限，请手动配置防火墙。" -ForegroundColor Yellow
}

Write-Host "`n=== 部署完成！===" -ForegroundColor Green
Write-Host "你可以通过以下命令查看服务日志："
if (-not $env:INSTANCE_NAME) {
    Write-Host "  NekroAgent: 'docker logs -f nekro_agent'"
    Write-Host "  NapCat: 'docker logs -f napcat'"
} else {
    Write-Host "  NekroAgent: 'docker logs -f $($env:INSTANCE_NAME)nekro_agent'"
    Write-Host "  NapCat: 'docker logs -f $($env:INSTANCE_NAME)napcat'"
}

# 显示重要的配置信息
Write-Host "`n=== 重要配置信息 ===" -ForegroundColor Cyan
$envContent = Get-Content ".env" -Raw
$ONEBOT_ACCESS_TOKEN = ([regex]"^ONEBOT_ACCESS_TOKEN=([^\r\n]*)").Match($envContent).Groups[1].Value
$NEKRO_ADMIN_PASSWORD = ([regex]"^NEKRO_ADMIN_PASSWORD=([^\r\n]*)").Match($envContent).Groups[1].Value
Write-Host "OneBot 访问令牌: $ONEBOT_ACCESS_TOKEN"
Write-Host "管理员账号: admin | 密码: $NEKRO_ADMIN_PASSWORD"

Write-Host "`n=== 服务访问信息 ===" -ForegroundColor Cyan
Write-Host "NekroAgent 主服务端口: $env:NEKRO_EXPOSE_PORT"
Write-Host "NapCat 服务端口: $env:NAPCAT_EXPOSE_PORT"
Write-Host "NekroAgent Web 访问地址: http://127.0.0.1:$env:NEKRO_EXPOSE_PORT"

Write-Host "`n=== 注意事项 ===" -ForegroundColor Yellow
Write-Host "1. 如果您使用的是云服务器，请在云服务商控制台的安全组中放行以下端口："
Write-Host "   - $($env:NEKRO_EXPOSE_PORT)/tcp (NekroAgent 主服务)"
Write-Host "   - $($env:NAPCAT_EXPOSE_PORT)/tcp (NapCat 服务)"
Write-Host "2. 如果需要从外部访问，请将上述地址中的 127.0.0.1 替换为您的服务器公网IP"
if (-not $env:INSTANCE_NAME) {
    Write-Host "3. 请使用 'docker logs napcat' 查看机器人 QQ 账号二维码进行登录"
} else {
    Write-Host "3. 请使用 'docker logs $($env:INSTANCE_NAME)napcat' 查看机器人 QQ 账号二维码进行登录"
}

# 提示用户修改配置文件
Write-Host "`n=== 配置文件 ===" -ForegroundColor Cyan
$CONFIG_FILE = Join-Path $env:NEKRO_DATA_DIR "configs\nekro-agent.yaml"
Write-Host "配置文件路径: $CONFIG_FILE"
Write-Host "编辑配置后可通过以下命令重启服务："
if (-not $env:INSTANCE_NAME) {
    Write-Host "  'docker restart nekro_agent'"
} else {
    Write-Host "  'docker restart $($env:INSTANCE_NAME)nekro_agent'"
}

Write-Host "`n安装完成！祝您使用愉快！" -ForegroundColor Green