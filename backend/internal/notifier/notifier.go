package notifier

import (
	"context"
	"fmt"

	"firebase.google.com/go/v4/messaging"
)

func GenerateMessage(title string, link string, token string) *messaging.Message {
	return &messaging.Message{
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
}

func SendNotifications(ctx context.Context, client *messaging.Client, chunk []*messaging.Message) {
	if client == nil {
		fmt.Println("Firebase messaging client is nil")
		return
	}
	response, err := client.SendEach(ctx, chunk)
	if err != nil {
		fmt.Println("Error sending messages:", err)
		return
	}
	for _, res := range response.Responses {
		if res.Error != nil {
			fmt.Println("Error in response:", res.Error)
		}
	}
}
