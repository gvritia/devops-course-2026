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

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1