# Stage 1: Build Go binary
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum first for better layer caching
COPY api/go.mod api/go.sum ./
RUN go mod download && go mod verify

# Copy source code
COPY api/ ./

# Build arguments for versioning
ARG BUILD_VERSION=dev
ARG GIT_COMMIT=unknown
ARG BUILD_DATE=unknown

# Build optimized static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.Version=${BUILD_VERSION} -X main.GitCommit=${GIT_COMMIT} -X main.BuildDate=${BUILD_DATE}" \
    -trimpath \
    -o clients-api \
    main.go

# Stage 2: Minimal runtime image
FROM alpine:3.19

# Create non-root user
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -S appuser -G appgroup

WORKDIR /app

# Copy binary with proper ownership
COPY --from=builder --chown=appuser:appgroup /app/clients-api .

# Switch to non-root user
USER appuser

# Run the application
CMD ["./clients-api"]