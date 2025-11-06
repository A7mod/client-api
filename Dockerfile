# Stage 1: Build Go binary
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum from api folder
COPY api/go.mod api/go.sum ./
RUN go mod download

# Copy the rest of the Go code
COPY api/ ./

# Build Go binary
RUN go build -o clients-api main.go

# Stage 2: Lightweight runtime image
FROM alpine:latest

WORKDIR /app
COPY --from=builder /app/clients-api .

# Set environment variables
ENV PORT=8080
ENV MONGO_URI=mongodb://mongo:27017/clientsdb

EXPOSE 8080

CMD ["./clients-api"]