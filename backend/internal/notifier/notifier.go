package notifier

import (
	"context"
	"fmt"
	"log"

	"firebase.google.com/go/messaging"
)

func SendNotification(ctx context.Context, client *messaging.Client, title string, link string) {
	message := &messaging.Message{
		Token: "f3_HeTyeRf6ziBgSSouUfN:APA91bGnLAgKDprvB1f8sCWYwyKKdXFVRllDbNtZp8oGDXDTwy-QqeKuqR12t3HnlI20tj2uUQs7CnwFZnzhd1RUDukgv3d_9hGLgBA-kcU3SanPVqqmtfw",
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

	response, err := client.Send(ctx, message)
	if err != nil {
		log.Fatalf("error sending push notification: %v", err)
	}

	fmt.Printf("Successfully sent message: %s\n", response)
}
