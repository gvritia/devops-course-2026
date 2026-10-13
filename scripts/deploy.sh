#!/usr/bin/env bash
# Автоматическая доставка статического сайта на Ubuntu VM

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

# Определяем корень репозитория независимо от текущего каталога
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${REPO_ROOT}/site/"

# 1. Проверка аргументов
DRY_RUN=false

if [[ $# -gt 1 ]]; then
    echo "Ошибка: слишком много аргументов" >&2
    exit 1
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" == "--dry-run" ]]; then
        DRY_RUN=true
    else
        echo "Использование: scripts/deploy.sh [--dry-run]" >&2
        exit 1
    fi
fi

# 2. Проверка наличия главной страницы
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: site/index.html не найден" >&2
    exit 1
fi

# 3. Проверка состояния Git
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения" >&2
    exit 1
fi

# 4. Подготовка параметров rsync
RSYNC_ARGS=(-avz --delete --chmod=D755,F644)

if [[ "$DRY_RUN" == true ]]; then
    RSYNC_ARGS+=(--dry-run)
    echo "Пробный запуск деплоя"
else
    echo "Начинаем деплой сайта..."
fi

# 5. Передача файлов (одно SSH-соединение)
rsync "${RSYNC_ARGS[@]}" \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
    "$LOCAL_DIR" \
    "${REMOTE}:${REMOTE_DIR}/"

# 6. Пробный запуск завершается без HTTP-проверки
if [[ "$DRY_RUN" == true ]]; then
    echo "Пробный запуск завершён"
    exit 0
fi

# 7. Проверка HTTPS с сертификатом
if ! curl -fsS --connect-timeout 5 \
    --cacert "$CA_CERT" \
    "$SITE_URL" > /dev/null; then
    echo "Ошибка: сайт недоступен по HTTPS" >&2
    exit 1
fi

# 8. Вывод хеша доставленного коммита
COMMIT_HASH="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"

echo "Деплой успешно завершён!"
echo "Коммит: $COMMIT_HASH"

exit 0
