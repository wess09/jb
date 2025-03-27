# ��������ַ����ĺ���
function Generate-RandomString {
    param(
        [int]$length
    )
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $chars.length }
    $private:ofs=""
    return [String]$chars[$random]
}

# һ������ nekro-agent ����ű�

# ����Ƿ��Թ���ԱȨ������
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "���Թ���ԱȨ�����д˽ű���" -ForegroundColor Red
    exit 1
}

# ��� Docker ��װ���
try {
    docker --version | Out-Null
} catch {
    $answer = Read-Host "Docker δ��װ���Ƿ�װ��[Y/n]"
    if ($answer -eq "" -or $answer -eq "y" -or $answer -eq "Y") {
        Write-Host "����� https://www.docker.com/products/docker-desktop ���ز���װ Docker Desktop for Windows"
        Write-Host "��װ��ɺ��������д˽ű�"
        exit 1
    } else {
        Write-Host "Error: Docker δ��װ�����Ȱ�װ Docker �������иýű���" -ForegroundColor Red
        exit 1
    }
}

# ��� Docker Compose ��װ���
try {
    docker-compose --version | Out-Null
} catch {
    Write-Host "Docker Compose δ��װ�����ڰ�װ..."
    Write-Host "Docker Desktop for Windows �Ѱ��� Docker Compose����ȷ����ȷ��װ Docker Desktop"
    exit 1
}

# ����Ӧ��Ŀ¼·��Ϊ�ű�����Ŀ¼
if (-not $env:NEKRO_ENV_DIR) {
    $env:NEKRO_ENV_DIR = "$PSScriptRoot"
}


if (-not $env:NEKRO_DATA_DIR) {
    $env:NEKRO_DATA_DIR = "$(wsl --exec wslpath $env:USERPROFILE)/nekro_agent_data"
}

if (-not $env:NEKRO_DATA_DIR_WIN) {
    $env:NEKRO_DATA_DIR_WIN = "$env:USERPROFILE\nekro_agent_data"
}

Write-Host "WSL·�� NEKRO_DATA_DIR: $env:NEKRO_DATA_DIR"

# ����Ӧ��Ŀ¼
try {
    New-Item -ItemType Directory -Force -Path $PSScriptRoot | Out-Null
} catch {
    Write-Host "Error: �޷�����Ӧ��Ŀ¼ $PSScriptRoot����������Ȩ�����á�" -ForegroundColor Red
    exit 1
}

# ����Ӧ��Ŀ¼
Set-Location $PSScriptRoot

# �����ǰĿ¼û�� .env �ļ����Ӳֿ��ȡ.env.example ���޸� .env �ļ�
if (-not (Test-Path ".env")) {
    Write-Host "δ�ҵ�.env�ļ������ڴӲֿ��ȡ.env.example..."
    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KroMiose/nekro-agent/main/docker/.env.example" -OutFile "$env:NEKRO_ENV_DIR\.env.temp"
    } catch {
        Write-Host "Error: �޷���ȡ.env.example�ļ��������������ӻ��ֶ�����.env�ļ���" -ForegroundColor Red
        exit 1
    }

# �����ļ�·��
$configFile = "$env:NEKRO_ENV_DIR\.env.temp"

# ������� OneBot Token��32 λ����ַ�����
$oneBotToken = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})

# ������� Admin ���루16 λ����ַ�����
$adminPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object {[char]$_})

# ��ȡ�����ļ�����
$configContent = Get-Content $configFile

$configContent = $configContent -replace "^(NEKRO_DATA_DIR=).*", "`$1$env:NEKRO_DATA_DIR"

$configContent = $configContent -replace "^(NEKRO_DATA_DIR_WIN=).*", "`$1$env:NEKRO_DATA_DIR_WIN"

# �滻 OneBot Token
$configContent = $configContent -replace "^(ONEBOT_ACCESS_TOKEN=).*", "`$1$oneBotToken"

# �滻 Admin ����
$configContent = $configContent -replace "^(NEKRO_ADMIN_PASSWORD=).*", "`$1$adminPassword"

# д�������ļ�
$configContent | Set-Content $configFile

# ������
Write-Host "OneBot Token: $oneBotToken"
Write-Host "Admin Password: $adminPassword"
Write-Host "�����ļ��Ѹ��£�"


# ��.env�ļ����ػ�������
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $key = $matches[1]
            $value = $matches[2]
            [Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Process)
        }
    }

    # ȷ����Ҫ�Ļ�����������
    if (-not $env:NEKRO_EXPOSE_PORT) {
        Write-Host "Error: NEKRO_EXPOSE_PORT δ�� .env �ļ�������" -ForegroundColor Red
        exit 1
    }
    if (-not $env:NAPCAT_EXPOSE_PORT) {
        Write-Host "Error: NAPCAT_EXPOSE_PORT δ�� .env �ļ�������" -ForegroundColor Red
        exit 1
    }
}

$answer = Read-Host "���鲢�����޸�.env�ļ��е����ã�δ�޸�����Ĭ�����ð�װ��ȷ���Ƿ������װ��[Y/n]"
if ($answer -eq "n" -or $answer -eq "N") {
    Write-Host "��װ��ȡ��"
    exit 0
}

# ��ȡ docker-compose.yml �ļ�
Write-Host "������ȡ docker-compose.yml �ļ�..."
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KroMiose/nekro-agent/main/docker/docker-compose-x-napcat.yml" -OutFile "$PSScriptRoot\docker-compose.yml"
    
} catch {
    Write-Host "Error: �޷���ȡ docker-compose.yml �ļ������������������ӡ�" -ForegroundColor Red
    exit 1
}

# ��������
if (Test-Path ".env") {
    Write-Host "ʹ��ʵ������: $env:INSTANCE_NAME"
    Write-Host "������������..."
    try {
        docker-compose --env-file .env up -d
    } catch {
        Write-Host "Error: �޷��������������� Docker Compose ���á�" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Error: .env �ļ�������" -ForegroundColor Red
    exit 1
}

# ��ȡɳ�о���
Write-Host "��ȡɳ�о���..."
try {
    docker pull kromiose/nekro-agent-sandbox
} catch {
    Write-Host "Error: �޷���ȡɳ�о������������������ӡ�" -ForegroundColor Red
    exit 1
}

# ���÷���ǽ����
Write-Host "`n�������÷���ǽ..."
Write-Host "���� NekroAgent ������˿� $($env:NEKRO_EXPOSE_PORT)..."
try {
    New-NetFirewallRule -DisplayName "NekroAgent" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $env:NEKRO_EXPOSE_PORT | Out-Null
} catch {
    Write-Host "Warning: �޷����÷���ǽ���������������ޣ����ֶ����÷���ǽ��" -ForegroundColor Yellow
}

Write-Host "���� NapCat ����˿� $($env:NAPCAT_EXPOSE_PORT)..."
try {
    New-NetFirewallRule -DisplayName "NapCat" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $env:NAPCAT_EXPOSE_PORT | Out-Null
} catch {
    Write-Host "Warning: �޷����÷���ǽ���������������ޣ����ֶ����÷���ǽ��" -ForegroundColor Yellow
}

Write-Host "`n=== ������ɣ�===" -ForegroundColor Green
Write-Host "�����ͨ����������鿴������־��"
if (-not $env:INSTANCE_NAME) {
    Write-Host "  NekroAgent: 'docker logs -f nekro_agent'"
    Write-Host "  NapCat: 'docker logs -f napcat'"
} else {
    Write-Host "  NekroAgent: 'docker logs -f $($env:INSTANCE_NAME)nekro_agent'"
    Write-Host "  NapCat: 'docker logs -f $($env:INSTANCE_NAME)napcat'"
}

# ��ʾ��Ҫ��������Ϣ
Write-Host "`n=== ��Ҫ������Ϣ ===" -ForegroundColor Cyan
$envContent = Get-Content ".env" -Raw
Write-Host "OneBot ��������: $ONEBOT_ACCESS_TOKEN"
Write-Host "����Ա�˺�: admin | ����: $NEKRO_ADMIN_PASSWORD"

Write-Host "`n=== ���������Ϣ ===" -ForegroundColor Cyan
Write-Host "NekroAgent ������˿�: $env:NEKRO_EXPOSE_PORT"
Write-Host "NapCat ����˿�: $env:NAPCAT_EXPOSE_PORT"
Write-Host "NekroAgent Web ���ʵ�ַ: http://127.0.0.1:$env:NEKRO_EXPOSE_PORT"

Write-Host "`n=== ע������ ===" -ForegroundColor Yellow
Write-Host "1. �����ʹ�õ����Ʒ������������Ʒ����̿���̨�İ�ȫ���з������¶˿ڣ�"
Write-Host "   - $($env:NEKRO_EXPOSE_PORT)/tcp (NekroAgent ������)"
Write-Host "   - $($env:NAPCAT_EXPOSE_PORT)/tcp (NapCat ����)"
Write-Host "2. �����Ҫ���ⲿ���ʣ��뽫������ַ�е� 127.0.0.1 �滻Ϊ���ķ���������IP"
if (-not $env:INSTANCE_NAME) {
    Write-Host "3. ��ʹ�� 'docker logs napcat' �鿴������ QQ �˺Ŷ�ά����е�¼"
} else {
    Write-Host "3. ��ʹ�� 'docker logs $($env:INSTANCE_NAME)napcat' �鿴������ QQ �˺Ŷ�ά����е�¼"
}

# ��ʾ�û��޸������ļ�
Write-Host "`n=== �����ļ� ===" -ForegroundColor Cyan
$CONFIG_FILE = Join-Path $env:NEKRO_DATA_DIR "configs\nekro-agent.yaml"
Write-Host "�����ļ�·��: $CONFIG_FILE"
Write-Host "�༭���ú��ͨ������������������"
if (-not $env:INSTANCE_NAME) {
    Write-Host "  'docker restart nekro_agent'"
} else {
    Write-Host "  'docker restart $($env:INSTANCE_NAME)nekro_agent'"
}

Write-Host "`n��װ��ɣ�ף��ʹ����죡" -ForegroundColor Green