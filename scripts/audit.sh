#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo " [OK]   $desc"
        ((PASS+=1))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL+=1))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"

check "Вход от имени root запрещён" "no" \
    "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"

check "Парольная аутентификация отключена" "no" \
    "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

# TODO 1: порт SSH должен отличаться от 22
SSH_PORT=$(sudo sshd -T | awk '/^port/{print $2}')
if [[ -n "$SSH_PORT" && "$SSH_PORT" != "22" ]]; then
    echo " [OK]   SSH использует нестандартный порт ($SSH_PORT)"
    ((PASS+=1))
else
    echo " [FAIL] SSH использует стандартный порт 22 или порт не определён"
    ((FAIL+=1))
fi

# TODO 2: MaxAuthTries должен быть равен 3
check "MaxAuthTries равен 3" "3" \
    "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"

check "Межсетевой экран активен" "active" \
    "$(sudo ufw status | awk '/^Status:/{print $2}')"

# TODO 3: политика входящих соединений должна быть deny
INCOMING_POLICY=$(sudo ufw status verbose | grep '^Default:' | sed -n 's/.*Default: \([a-z]*\) (incoming).*/\1/p')

check "Политика входящих соединений deny" "deny" "$INCOMING_POLICY"

echo "[3] Учётные записи"

awk -F: '$3>=1000 && $3<65534 {printf "              %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"

# 4.1. Служба Nginx должна быть активна
check "Служба Nginx активна" "active" \
    "$(systemctl is-active nginx 2>/dev/null)"

# 4.2. Проверка синтаксиса конфигурации Nginx
if sudo nginx -t >/dev/null 2>&1; then
    NGINX_CONFIG="ok"
else
    NGINX_CONFIG="error"
fi

check "Конфигурация Nginx корректна" "ok" "$NGINX_CONFIG"

# 4.3. Сертификат должен действовать ещё минимум 30 дней
# 30 дней = 2592000 секунд
CERT_CHECK_SECONDS="${CERT_CHECK_SECONDS:-2592000}"

if openssl x509 -in /etc/ssl/certs/devops.crt \
    -checkend "$CERT_CHECK_SECONDS" -noout >/dev/null 2>&1; then
    CERT_STATUS="ok"
else
    CERT_STATUS="error"
fi

check "Сертификат действителен минимум 30 дней" "ok" "$CERT_STATUS"

# 4.4. Проверка прав доступа к файлам сайта и TLS-ключу
UNSAFE_FILES=$(find /var/www/devops-site -perm -o+w -print 2>/dev/null)
KEY_PERMISSIONS=$(sudo stat -c '%a' /etc/ssl/private/devops.key 2>/dev/null)

if [[ -z "$UNSAFE_FILES" && "$KEY_PERMISSIONS" == "600" ]]; then
    PERMISSIONS_STATUS="ok"
else
    PERMISSIONS_STATUS="error"
fi

check "Безопасные права файлов и TLS-ключа" "ok" "$PERMISSIONS_STATUS"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
