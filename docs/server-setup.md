# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

- Гипервизор: Oracle VirtualBox 7.x
- Операционная система: Ubuntu Server 24.04.5 LTS
- Имя виртуальной машины: devops-vm
- Оперативная память: 2048 МБ
- Количество ядер процессора: 2
- Размер виртуального диска: 25 ГБ, динамически расширяемый
- Графический интерфейс: отсутствует

## 2. Сетевые интерфейсы

| Интерфейс | Тип адаптера | IP-адрес | Назначение |
|---|---|---|---|
| enp0s3 | NAT | 10.0.2.15 | Доступ Ubuntu в Интернет |
| enp0s8 | Host-only | 192.168.56.103 | Соединение Windows с Ubuntu |

Оба интерфейса настроены в VirtualBox. NAT обеспечивает загрузку обновлений и пакетов. Host-only обеспечивает взаимодействие с основной операционной системой Windows.

## 3. Правило проброса портов

Правило SSH для адаптера NAT:

- Имя правила: ssh
- Протокол: TCP
- IP хостовой системы: 127.0.0.1
- Порт хостовой системы: 2222
- IP гостевой системы: не задан
- Порт гостевой системы: 2222

После настройки подключение к серверу выполняется из Windows командой `ssh devops`.

## 4. Учётные записи

**gvriti**
- UID: 1000
- Первоначальная учётная запись Ubuntu
- Использовалась для первичной настройки сервера

**devops**
- UID: 1001
- Входит в группы devops, sudo, users
- Используется для удалённого администрирования
- SSH-аутентификация выполняется по ключу ED25519

Открытый ключ размещён в `/home/devops/.ssh/authorized_keys`.

Права доступа:
- Каталог `.ssh`: 700
- Файл `authorized_keys`: 600

Закрытый ключ `devops_vm` хранится на Windows и не передаётся серверу.

## 5. Служба SSH

Служба OpenSSH Server установлена и включена.

Основной файл конфигурации: `/etc/ssh/sshd_config`.

Файл дополнительных параметров: `/etc/ssh/sshd_config.d/99-hardening.conf`.

Применённые параметры:

```text
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
```

Активация через `ssh.socket` отключена, используется `ssh.service`.

На Windows в `~/.ssh/config` настроен псевдоним `devops` с адресом `127.0.0.1`, портом `2222` и ключом `~/.ssh/devops_vm`.

Проверка конфигурации:

```bash
sudo sshd -t
sudo sshd -T
sudo ss -tlnp | grep sshd
```

Для применения настроек:

```bash
sudo systemctl restart ssh
```

Перед перезапуском необходимо проверить синтаксис и сохранить действующую SSH-сессию.

Полное доменное имя сервера: `devops-vm.devops.local`.

В Windows в файл `hosts` добавлена запись:

```text
192.168.56.103 devops.local
```

## 6. Правила межсетевого экрана

Используется UFW.

Политики по умолчанию:
- Входящий трафик: deny
- Исходящий трафик: allow

Разрешённые подключения:

| Порт | Действие | Назначение |
|---|---|---|
| 2222/tcp | LIMIT | SSH, ограничение частоты подключений |
| 80/tcp | ALLOW | HTTP |
| 443/tcp | ALLOW | HTTPS |

Аналогичные правила действуют для IPv6.

Команды восстановления:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw limit 2222/tcp comment 'SSH rate-limited'
sudo ufw enable
sudo ufw logging medium
```

Разрешающее правило SSH обязательно добавляется до активации межсетевого экрана.

Проверка:

```bash
sudo ufw status verbose
```

Блокировка подключения к порту 8080 подтверждена записями `[UFW BLOCK]` с полями SRC, DST, PROTO и DPT.

## 7. Снимки состояния

| Название | Состояние |
|---|---|
| 01-clean-install | Ubuntu установлена, сеть и исходный SSH настроены |
| 02-keys-configured | Создан пользователь devops, настроена ключевая аутентификация |
| 03-ssh-hardened | Настроена защита SSH, запрещён парольный вход, изменён порт |

Снимки созданы средствами VirtualBox и позволяют восстанавливать состояние машины.

## 8. Контроль конфигурации

Скрипт расположен в `scripts/audit.sh`.

Он проверяет:
- Запрет входа root
- Отключение парольной аутентификации
- Нестандартный порт SSH
- Значение MaxAuthTries = 3
- Активность UFW
- Политику deny incoming

При правильной конфигурации все 6 проверок успешно проходят, код завершения — 0.

При временном изменении MaxAuthTries на 10 скрипт обнаруживает нарушение: 5 проверок успешно, 1 проверка с ошибкой.

После тестирования значение MaxAuthTries восстановлено до 3.

## 8. Веб-сервер

### 8.1. Установка Nginx

На сервере установлен веб-сервер Nginx.

Команда установки:

sudo apt update && sudo apt install -y nginx

Проверка состояния службы:

systemctl status nginx

Проверка конфигурации:

sudo nginx -t

Применение изменений:

sudo systemctl reload nginx

### 8.2. Расположение файлов

Конфигурация сайта:
/etc/nginx/sites-available/devops-site

Активная конфигурация:
/etc/nginx/sites-enabled/devops-site

Каталог сайта:
/var/www/devops-site

Владелец каталога: devops:devops.

Права каталогов: 755.
Права HTML-файлов: 644.

Стандартный сайт Nginx отключён.

### 8.3. Настройка HTTPS

Сайт доступен по адресу:

https://devops.local

HTTP-запросы перенаправляются на HTTPS
с использованием кода 301.

Сертификат:
/etc/ssl/certs/devops.crt

Закрытый ключ:
/etc/ssl/private/devops.key

Владелец закрытого ключа: root:root.
Права закрытого ключа: 600.
Права сертификата: 644.

Срок действия сертификата:
13.10.2026 — 13.10.2027.

Команда создания сертификата:

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key \
  -out /etc/ssl/certs/devops.crt \
  -subj "/CN=devops.local" \
  -addext "subjectAltName=DNS:devops.local"

### 8.4. Доставка содержимого

Содержимое сайта хранится в каталоге site/
Git-репозитория devops-course-2026.

Доставка выполняется сценарием:

bash scripts/deploy.sh

Пробный запуск:

bash scripts/deploy.sh --dry-run

Сценарий использует rsync через SSH,
проверяет чистоту репозитория и наличие
главной страницы, устанавливает права
755/644 и проверяет доступность HTTPS.

### 8.5. Проверка работы

Проверка HTTP-перенаправления:

curl -I http://devops.local

Ожидаемый результат: 301.

Проверка HTTPS из WSL:

curl --cacert ~/devops.crt -I https://devops.local

Ожидаемый результат: 200 OK.

Проверка прав на сервере:

ls -la /var/www/devops-site/

Проверка небезопасных файлов:

find /var/www/devops-site -perm -o+w

## 9. Контейнеризация

### 9.1. Установка Docker Engine

На сервере Ubuntu Server 24.04 LTS установлен Docker Engine версии **29.9.0** из официального репозитория Docker.

Для проверки установки используются команды:

```bash
docker version
docker compose version
sudo systemctl status docker
```

Служба Docker запускается автоматически при загрузке сервера.

### 9.2. Пользователи и разграничение прав

В группу `docker` включён пользователь `devops`, который может выполнять команды Docker без использования `sudo`.

Проверка состава группы:

```bash
getent group docker
```

Результат:

```text
docker:x:988:devops
```

Поскольку участники группы `docker` фактически получают привилегированный доступ к серверу, членство в ней разрешается только доверенным пользователям, имеющим административные полномочия.

Само Flask-приложение внутри контейнера запускается от непривилегированного пользователя `app`, а не от `root`.

### 9.3. Расположение проекта

Исходный код хранится в репозитории `devops-course-2026` в каталоге `app/`.

На сервере приложение размещено по пути:

```text
/home/devops/app/
```

Основные файлы проекта:

- `app.py` — Flask-приложение со счётчиком посещений.
- `requirements.txt` — зависимости Python.
- `Dockerfile` — инструкции сборки Docker-образа.
- `.dockerignore` — исключения из контекста сборки.
- `docker-compose.yml` — конфигурация Flask и PostgreSQL.
- `.env.example` — шаблон переменных окружения.
- `.env` — действительные переменные окружения и пароль PostgreSQL.

### 9.4. Переменные окружения и защита секретов

На сервере файл переменных окружения расположен по пути:

```text
/home/devops/app/.env
```

Права доступа установлены в `600`: чтение и запись разрешены только владельцу файла.

Проверка:

```bash
stat -c '%a' ~/app/.env
```

Результат:

```text
600
```

Файл `.env` исключён из Git и контекста Docker-сборки. Он не копируется на рабочую станцию.

Пароль PostgreSQL создаётся с помощью `openssl rand -hex 16`.

### 9.5. Сервисы Docker Compose

Приложение состоит из двух сервисов:

**app — Flask-приложение**

- Docker-образ: `devops-app:1.0`.
- Веб-сервер: Gunicorn.
- Внутренний порт: `5000`.
- Опубликованный адрес: `127.0.0.1:5000`.
- Запуск от имени пользователя `app`.

**db — PostgreSQL**

- Docker-образ: `postgres:16-alpine`.
- Внутренний порт: `5432`.
- Порт не публикуется на хостовой системе.
- Готовность проверяется через `pg_isready`.
- Запуск Flask зависит от состояния `service_healthy`.

Контейнеры взаимодействуют через пользовательскую сеть Docker `app_backend`. Приложение подключается к PostgreSQL по DNS-имени `db`.

### 9.6. Постоянное хранение данных

Для PostgreSQL используется именованный том:

```text
app_db_data
```

Он монтируется в каталог контейнера:

```text
/var/lib/postgresql/data
```

Команда `docker compose down` удаляет контейнеры и сеть, но сохраняет том.

Команда `docker compose down -v` дополнительно удаляет том и содержащиеся в нём данные.

В ходе практической работы подтверждено:

- До пересоздания контейнеров: `Visits: 4`.
- После `docker compose down` и повторного запуска: `Visits: 5`.
- После `docker compose down -v` и повторного запуска: `Visits: 1`.

Таким образом подтверждено независимое хранение данных от жизненного цикла контейнеров.

### 9.7. Публикация через Nginx

Доступ к приложению реализован через Nginx по HTTPS:

```text
https://devops.local/app/
```

Конфигурационный файл Nginx:

```text
/etc/nginx/sites-available/devops-site
```

В HTTPS-блоке используется следующая конфигурация:

```nginx
location /app/ {
    proxy_pass http://127.0.0.1:5000/;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

Nginx принимает HTTPS-запросы и перенаправляет их на локальный порт Flask.

Статический ресурс `https://devops.local/` сохраняется и продолжает возвращать `200 OK`.

Для проверки используется сертификат `devops.crt`.

### 9.8. Запуск и проверка работоспособности

Для запуска приложения выполняются:

```bash
cd ~/app
docker compose up -d --build
```

Проверка состояния контейнеров:

```bash
docker compose ps
```

Проверка Flask:

```bash
curl http://127.0.0.1:5000/health
```

Проверка DNS:

```bash
docker compose exec app getent hosts db
```

Проверка портов:

```bash
sudo ss -tlnp | grep -E ':(5000|5432)\b'
```

Проверка работы приложения от непривилегированного пользователя:

```bash
docker compose exec app id
```

Для просмотра журналов:

```bash
docker compose logs app
docker compose logs db
```

### 9.9. Остановка и восстановление

Остановка отдельного сервиса:

```bash
docker compose stop app
```

Повторный запуск:

```bash
docker compose start app
```

Остановка и удаление контейнеров с сохранением данных:

```bash
docker compose down
```

При недоступности Flask Nginx возвращает `502 Bad Gateway`. Для диагностики используются:

```bash
docker compose ps
docker compose logs app
sudo tail -n 20 /var/log/nginx/devops-site.error.log
```

При проверке отказа была обнаружена ошибка `connect() failed (111: Connection refused) while connecting to upstream`, вызванная остановкой контейнера приложения.

Для сохранения конфигурации виртуальной машины создан снимок состояния `05-docker-compose`.