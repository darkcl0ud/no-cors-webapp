# Build stage
FROM golang:latest AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY .. .
RUN CGO_ENABLED=0 GOOS=linux go build cmd/api/main.go

# Runtime stage
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 80
RUN apk add --no-cache curl
CMD ["./main"]
