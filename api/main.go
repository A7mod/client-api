package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gofiber/fiber/v2"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var client *mongo.Client //Global

// connects to MongoDB and verifies connection
func connectMongo() {
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		log.Fatal("MONGO_URI not set")
	}

	// basic context with 10 sec timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// connect to mongoDB
	var err error
	client, err = mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Fatalf("Mongo connection error: %v", err)
	}

	// pinging to check connection/connectivity
	err = client.Ping(ctx, nil)
	if err != nil {
		log.Fatalf("Mongo ping failed: %v", err)
	}

	log.Println("✅ Connected to MongoDB")
}

func main() {
	app := fiber.New() // creates fiber app

	connectMongo() // initiates mongoDB connection

	// health and status code check
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.Status(http.StatusOK).JSON(fiber.Map{
			"status": "healthy",
		})
	})

	// Clients endpoint - returns number of clients

	app.Get("/clients", func(c *fiber.Ctx) error {
		collection := client.Database("clientsdb").Collection("clients")
		count, _ := collection.CountDocuments(context.Background(), fiber.Map{})
		return c.JSON(fiber.Map{"clients_count": count})
	})

	//server started on port 8080
	log.Fatal(app.Listen(":8080"))
}
