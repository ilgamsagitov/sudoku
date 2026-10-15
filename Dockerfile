FROM golang:1.26.9-alpine AS builder

WORKDIR /src

COPY go.mod ./
RUN go mod download

COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags="-s -w" \
    -o /out/sudoku .

FROM alpine:3.22

RUN apk add --no-cache ca-certificates \
    && addgroup -S app \
    && adduser -S -G app app

WORKDIR /app

COPY --from=builder /out/sudoku ./sudoku
COPY --chown=app:app static ./static

USER app

ENV ADDR=:8080

EXPOSE 8080

CMD ["./sudoku"]
