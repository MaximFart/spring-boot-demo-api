#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для проверки JSON ответа
is_json() {
    jq -e . >/dev/null 2>&1 <<<"$1"
}

# 1. Проверка доступности Keycloak
echo -e "\n${YELLOW}=== 1. Проверка доступности Keycloak ===${NC}"
KC_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" http://localhost:8080/auth/realms/test-realm)
HTTP_STATUS=$(echo "$KC_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
KC_JSON=$(echo "$KC_RESPONSE" | grep -v "HTTP_STATUS")

if [ "$HTTP_STATUS" -eq 200 ]; then
    if is_json "$KC_JSON"; then
        REALM=$(echo "$KC_JSON" | jq -r '.realm')
        echo -e "${GREEN}Keycloak доступен. Realm: $REALM${NC}"
    else
        echo -e "${RED}Ошибка: Keycloak вернул невалидный JSON${NC}"
        exit 1
    fi
else
    echo -e "${RED}Ошибка: Keycloak недоступен (HTTP $HTTP_STATUS)${NC}"
    exit 1
fi

# 2. Получение access_token
echo -e "\n${YELLOW}=== 2. Получение токена ===${NC}"
TOKEN_RESPONSE=$(curl -s -X POST \
  http://localhost:8080/auth/realms/test-realm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=spring-boot-demo-api&client_secret=Bi0wmZL2ykaI4lnWthyRMDYHvxV8UkCM&username=test-user&password=test123&grant_type=password")

if is_json "$TOKEN_RESPONSE"; then
    TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
    if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        echo -e "${GREEN}Токен получен успешно!${NC}"
        echo "Токен (первые 50 символов): ${TOKEN:0:50}..."
    else
        ERROR=$(echo "$TOKEN_RESPONSE" | jq -r '.error_description')
        echo -e "${RED}Ошибка получения токена: ${ERROR}${NC}"
        exit 1
    fi
else
    echo -e "${RED}Ошибка: Keycloak вернул невалидный JSON${NC}"
    echo "Ответ: $TOKEN_RESPONSE"
    exit 1
fi

# 3. Доступ к защищенному эндпоинту
echo -e "\n${YELLOW}=== 3. Тест защищенного /hello ===${NC}"
HELLO_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET \
  http://localhost:8081/hello \
  -H "Authorization: Bearer $TOKEN")
HTTP_STATUS=$(echo "$HELLO_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
HELLO_CONTENT=$(echo "$HELLO_RESPONSE" | grep -v "HTTP_STATUS")

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo -e "${GREEN}Успешный доступ к защищенному эндпоинту${NC}"
    echo "Ответ: $HELLO_CONTENT"
else
    echo -e "${RED}Ошибка доступа (HTTP $HTTP_STATUS)${NC}"
    echo "Ответ: $HELLO_CONTENT"
fi

# 4. Неверные учетные данные
echo -e "\n${YELLOW}=== 4. Негативный тест: неверный пароль ===${NC}"
ERROR_RESPONSE=$(curl -s -X POST \
  http://localhost:8080/auth/realms/test-realm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=spring-boot-demo-api&username=test-user&password=wrongpass&grant_type=password")

if is_json "$ERROR_RESPONSE"; then
    ERROR=$(echo "$ERROR_RESPONSE" | jq -r '.error')
    echo -e "${RED}Ожидаемая ошибка: $ERROR${NC}"
else
    echo -e "${RED}Ошибка: невалидный JSON ответ${NC}"
    echo "Ответ: $ERROR_RESPONSE"
fi

# 5. Проверка без токена
echo -e "\n${YELLOW}=== 5. Негативный тест: запрос без токена ===${NC}"
UNAUTH_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET http://localhost:8081/hello)
HTTP_STATUS=$(echo "$UNAUTH_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
UNAUTH_CONTENT=$(echo "$UNAUTH_RESPONSE" | grep -v "HTTP_STATUS")

if [ "$HTTP_STATUS" -eq 401 ]; then
    echo -e "${GREEN}Ожидаемая ошибка 401 (Unauthorized)${NC}"
else
    echo -e "${RED}Неожиданный статус: HTTP $HTTP_STATUS${NC}"
fi
echo "Ответ: $UNAUTH_CONTENT"