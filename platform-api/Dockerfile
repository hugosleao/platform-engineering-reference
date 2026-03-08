FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o platform-operator ./cmd/operator

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/platform-operator /platform-operator
EXPOSE 8080 8081
ENTRYPOINT ["/platform-operator"]
