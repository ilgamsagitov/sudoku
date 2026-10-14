# Руководство по настройке CI/CD для веб-приложения "Судоку" на Go

Создание CI/CD для веб-приложения "Судоку" на Go включает настройку бэкенда на Go (который отдает статичные файлы фронтенда и обрабатывает логику игры) и автоматизацию сборки с помощью **GitHub Actions**.

---

## 1. Структура проекта

Рекомендуемая структура каталогов для корректной работы пайплайна:

```text
sudoku-go/
├── cmd/
│   └── server/
│       └── main.go        # Точка входа в приложение
├── internal/              # Бизнес-логика (генерация и проверка судоку)
├── static/                # HTML, CSS, JS файлы веб-интерфейса
├── go.mod
├── Dockerfile             # Инструкция для сборки контейнера
└── .github/
    └── workflows/
        └── ci-cd.yml      # Конфигурация CI/CD
```

---

## 2. Этапы CI/CD пайплайна

Пайплайн состоит из двух основных частей:
1. **Continuous Integration (CI):**
   * Проверка кода линтером (`golangci-lint`).
   * Запуск тестов (`go test`).
   * Сборка бинарного файла Go для проверки на ошибки компиляции.
2. **Continuous Deployment (CD):**
   * Сборка Docker-образа приложения.
   * Публикация образа в реестр (например, Docker Hub).
   * Автоматический деплой на удаленный сервер (опционально).

---

## 3. Конфигурация GitHub Actions (`.github/workflows/ci-cd.yml`)

```yaml
name: Sudoku CI/CD

on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]

jobs:
  build-and-test:
    name: CI - Test and Lint
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Install dependencies
        run: go mod download

      - name: Run golangci-lint
        uses: golangci/golangci-lint-action@v6
        with:
          version: v1.59.0

      - name: Run tests
        run: go test -v -race ./...

      - name: Build binary
        run: go build -v -o sudoku-app ./cmd/server/main.go

  deploy:
    name: CD - Docker Build and Push
    needs: build-and-test
    if: github.event_name == 'push' && (github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master')
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: your_dockerhub_username/sudoku-go:latest
```

---

## 4. Пример `Dockerfile`

Для многоэтапной сборки (multi-stage build), чтобы уменьшить размер готового образа:

```dockerfile
# Этап сборки
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /sudoku-app ./cmd/server/main.go

# Этап запуска
FROM alpine:latest
WORKDIR /root/
# Копируем бинарник и статические файлы фронтенда
COPY --from=builder /sudoku-app .
COPY --from=builder /app/static ./static

EXPOSE 8080
CMD ["./sudoku-app"]
```

---

## 5. Что нужно настроить перед запуском?

1. **Секреты в GitHub:** 
   Перейдите в репозитории в раздел `Settings` -> `Secrets and variables` -> `Actions` и добавьте:
   * `DOCKER_USERNAME` — ваше имя пользователя на Docker Hub.
   * `DOCKER_PASSWORD` — ваш токен доступа (Access Token) от Docker Hub.
2. **Пути:** 
   Замените `your_dockerhub_username/sudoku-go:latest` в YAML-файле на ваш актуальный репозиторий Docker Hub.
3. **Статические файлы:** 
   Убедитесь, что ваш бэкенд на Go корректно раздает файлы из папки `static`.