package notifier

import (
	"context"
	"log"

	"firebase.google.com/go/messaging"
)

func SendNotification(ctx context.Context, client *messaging.Client, title string, link string, token string) {
	message := &messaging.Message{
		Token: token,
		Notification: &messaging.Notification{
			Title: title,
			Body:  link,
		},
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				ClickAction: "FLUTTER_NOTIFICATION_CLICK",
			},
		},
		Data: map[string]string{
			"link": link,
		},
	}

	_, err := client.Send(ctx, message)
	if err != nil {
		log.Fatalf("error sending push notification: %v", err)
	}

	//fmt.Printf("Successfully sent message: %s\n", response)
}
