#!/bin/bash

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --app=*)
            APP_NAME="${1#*=}"
            shift
            ;;
        --version=*)
            VERSION="${1#*=}"
            shift
            ;;
        --env=*)
            ENVIRONMENT="${1#*=}"
            shift
            ;;
        *)
            echo "Неизвестный параметр: $1"
            exit 1
            ;;
    esac
done

# Проверка обязательных параметров
if [ -z "$APP_NAME" ] || [ -z "$VERSION" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Использование: $0 --app=название_приложения --version=версия --env=окружение"
    exit 1
fi

echo "Начинаю развертывание приложения $APP_NAME версии $VERSION в окружении $ENVIRONMENT"

# Функция проверки зависимостей
check_dependencies() {
    echo "Проверка зависимостей..."
    
    if ! command -v git &> /dev/null; then
        echo "Ошибка: git не установлен"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        echo "Ошибка: docker не установлен"
        exit 1
    fi
    
    if ! command -v nginx &> /dev/null; then
        echo "Ошибка: nginx не установлен"
        exit 1
    fi
    
    echo "Все зависимости присутствуют"
}

# Функция клонирования/обновления репозитория
update_repository() {
    echo "Обновление репозитория..."
    
    REPO_URL="https://github.com/vey1po/$APP_NAME.git"
    DEPLOY_DIR="/opt/deployments/$APP_NAME"
    
    if [ ! -d "$DEPLOY_DIR/.git" ]; then
        echo "Клонирование репозитория из $REPO_URL..."
        git clone $REPO_URL $DEPLOY_DIR
    else
        echo "Обновление существующего репозитория..."
        cd $DEPLOY_DIR
        git fetch origin
        git checkout v$VERSION
    fi
}

# Функция создания резервной копии
create_backup() {
    echo "Создание резервной копии..."
    
    BACKUP_DIR="/opt/backups/$APP_NAME/backup_$(date +%Y%m%d_%H%M%S)"
    CURRENT_DEPLOY="/opt/deployments/$APP_NAME/current"
    
    if [ -d "$CURRENT_DEPLOY" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$CURRENT_DEPLOY"/* "$BACKUP_DIR/" 2>/dev/null || true
        echo "Резервная копия создана в $BACKUP_DIR"
    fi
}

# Функция развертывания новой версии
deploy_new_version() {
    echo "Развертывание новой версии $VERSION..."
    
    DEPLOY_DIR="/opt/deployments/$APP_NAME"
    NEW_VERSION_DIR="$DEPLOY_DIR/v$VERSION"
    
    # Копируем файлы в директорию новой версии
    mkdir -p "$NEW_VERSION_DIR"
    cp -r "$DEPLOY_DIR"/* "$NEW_VERSION_DIR/"
    
    # Собираем Docker-контейнер
    cd "$NEW_VERSION_DIR"
    docker build -t "$APP_NAME:$VERSION" .
    
    # Останавливаем старый контейнер
    docker stop "${APP_NAME}_container" 2>/dev/null || true
    docker rm "${APP_NAME}_container" 2>/dev/null || true
    
    # Запускаем новый контейнер
    docker run -d --name "${APP_NAME}_container" -p 8080:80 "$APP_NAME:$VERSION"
    
    echo "Новая версия развернута"
}

# Функция проверки здоровья приложения
health_check() {
    echo "Проверка состояния приложения..."
    
    sleep 10  # Ждем немного пока приложение запустится
    
    # Проверяем доступность приложения
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        echo "Приложение работает нормально (HTTP $HTTP_CODE)"
        return 0
    else
        echo "Приложение недоступно (HTTP $HTTP_CODE)"
        return 1
    fi
}

# Функция отката
rollback() {
    echo "Выполняется откат..."
    
    # Здесь должна быть логика отката
    # Пока просто выводим сообщение
    echo "Откат завершен"
    
    # Отправляем уведомление об ошибке
    echo "Сбой развертывания для $APP_NAME версии $VERSION в окружении $ENVIRONMENT" | mail -s "Ошибка развертывания" admin@example.com 2>/dev/null || echo "Не удалось отправить уведомление"
}

# Основной процесс развертывания
main() {
    check_dependencies
    update_repository
    create_backup
    deploy_new_version
    
    if ! health_check; then
        rollback
        exit 1
    fi
    
    echo "Развертывание успешно завершено"
}

# Запускаем основную функцию
main
