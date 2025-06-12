package main

import (
	"context"
	"log"
	"time"

	"news_alert_backend/internal/fetcher"
	"news_alert_backend/internal/notifier"

	firebase "firebase.google.com/go"
	"google.golang.org/api/option"
)

func main() {
	opt := option.WithCredentialsFile("news-alert-251e3-firebase-adminsdk-fbsvc-89b07f6e47.json")
	conf := &firebase.Config{ProjectID: "news-alert-251e3"}
	app, err := firebase.NewApp(context.Background(), conf, opt)
	if err != nil {
		log.Fatalf("error initializing Firebase app: %v", err)
	}

	ctx := context.Background()
	client, err := app.Messaging(ctx)
	if err != nil {
		log.Fatalf("error getting Messaging client: %v", err)
	}

	notifier.SendNotification(ctx, client, "Probando titulo", "https://www.twitch.com")

	for {
		fetcher.Scan("list.json")
		time.Sleep(6 * time.Hour)
	}
}
