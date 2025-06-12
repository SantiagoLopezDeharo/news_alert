package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	firebase "firebase.google.com/go"
	"firebase.google.com/go/messaging"

	"io/ioutil"
	"net/http"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"

	"google.golang.org/api/option"
)

func saveList(filename string, list []string) error {
	data, err := json.MarshalIndent(list, "", "  ")
	if err != nil {
		return err
	}
	return ioutil.WriteFile(filename, data, 0644)
}

func loadList(filename string) ([]string, error) {
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		if os.IsNotExist(err) {
			// Create empty file with [] content
			emptyList := []string{}
			emptyData, _ := json.Marshal(emptyList)
			err = ioutil.WriteFile(filename, emptyData, 0644)
			if err != nil {
				return nil, err
			}
			return emptyList, nil
		}
		return nil, err
	}

	var list []string
	err = json.Unmarshal(data, &list)
	return list, err
}

func any_contains(s []string, cl []string) bool {
	flag := false

	for _, c := range cl {
		flag = strings.Contains(strings.ToLower(s[2]), c)
		if flag {
			return true
		}
	}

	return false
}

func bbc() <-chan [][]string {
	ret := make(chan [][]string)

	go func() {
		url := "https://www.bbc.com"
		resp, err := http.Get(url + "/news")
		if err != nil {
			panic(err)
		}
		defer resp.Body.Close()

		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			panic(err)
		}

		re := regexp.MustCompile(`<a.*?href="([^"]*)".*?>.*?<h2 data-testid="card-headline".*?>([^</]*?)</h2>`)

		ret <- re.FindAllStringSubmatch(string(body), -1)
		close(ret)
	}()

	return ret

}

func theguardian() chan [][]string {
	ret := make(chan [][]string)

	go func() {
		url := "https://www.theguardian.com"
		resp, err := http.Get(url + "/international")

		if err != nil {
			panic(err)
		}

		defer resp.Body.Close()

		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			panic(err)
		}

		re := regexp.MustCompile(`<a href="([^"]*)".*?aria-label="([^"]*)".*?></a>`)
		ret <- re.FindAllStringSubmatch(string(body), -1)
		close(ret)
	}()

	return ret
}

func nytimes() chan [][]string {
	ret := make(chan [][]string)

	go func() {
		url := "https://www.nytimes.com"
		resp, err := http.Get(url + "/international")

		if err != nil {
			panic(err)
		}

		defer resp.Body.Close()

		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			panic(err)
		}

		re := regexp.MustCompile(`<div class="css-cfnhvx"><a.*?href="([^"]*)"><div.*?><p.*?>([^</]*?)</p></div></a></div>`)
		ret <- re.FindAllStringSubmatch(string(body), -1)
		close(ret)
	}()

	return ret
}

func abc() <-chan [][]string {
	ret := make(chan [][]string)

	go func() {
		url := "https://abcnews.go.com"
		resp, err := http.Get(url + "/International")
		if err != nil {
			panic(err)
		}
		defer resp.Body.Close()

		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			panic(err)
		}

		re := regexp.MustCompile(`<h2><a.*?href="([^"]*)".*?>.*?([^</]*?)</a></h2>`)

		ret <- re.FindAllStringSubmatch(string(body), -1)
		close(ret)
	}()

	return ret

}

func alijazeera() <-chan [][]string {
	ret := make(chan [][]string)

	go func() {
		url := "https://www.aljazeera.com"
		resp, err := http.Get(url)
		if err != nil {
			panic(err)
		}
		defer resp.Body.Close()

		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			panic(err)
		}

		re := regexp.MustCompile(`<a.*?href="([^"]*)".*?>.*?<span>([^</]*?)</span></a>`)

		ret <- re.FindAllStringSubmatch(string(body), -1)
		close(ret)
	}()

	return ret

}

func scan() {
	cl, _ := loadList("list.json")

	var wg sync.WaitGroup
	wg.Add(5)

	var bbc_r, tg, nyt, abcl, az [][]string

	go func() {
		defer wg.Done()
		bbc_r = <-bbc()
	}()
	go func() {
		defer wg.Done()
		tg = <-theguardian()
	}()
	go func() {
		defer wg.Done()
		nyt = <-nytimes()
	}()
	go func() {
		defer wg.Done()
		abcl = <-abc()
	}()
	go func() {
		defer wg.Done()
		az = <-alijazeera()
	}()

	wg.Wait()

	for _, match := range bbc_r {
		if len(match) > 2 && any_contains(match, cl) {
			fmt.Println(match[2] + " -->  www.bbc.com" + match[1])
			fmt.Println()
		}
	}
	for _, match := range tg {
		if len(match) > 2 && any_contains(match, cl) {
			fmt.Println(match[2] + " -->  www.theguardian.com" + match[1])
			fmt.Println()
		}
	}
	for _, match := range nyt {
		if len(match) > 2 && any_contains(match, cl) {
			fmt.Println(match[2] + " --> " + match[1])
			fmt.Println()
		}
	}
	for _, match := range abcl {
		if len(match) > 2 && any_contains(match, cl) {
			fmt.Println(match[2] + " --> " + match[1])
			fmt.Println()
		}
	}
	for _, match := range az {
		if len(match) > 2 && any_contains(match, cl) {
			fmt.Println(match[2] + " --> https://www.aljazeera.com" + match[1])
			fmt.Println()
		}
	}

	fmt.Println("End.")
	time.Sleep(6 * time.Hour)
}

func sendNotification(ctx context.Context, client *messaging.Client, title string, link string) {
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

func main() {
	opt := option.WithCredentialsFile("news-alert-251e3-firebase-adminsdk-fbsvc-89b07f6e47.json")

	// Initialize Firebase app
	conf := &firebase.Config{ProjectID: "news-alert-251e3"}
	app, err := firebase.NewApp(context.Background(), conf, opt)
	if err != nil {
		log.Fatalf("error initializing Firebase app: %v", err)
	}

	// Initialize Messaging client
	ctx := context.Background()
	client, err := app.Messaging(ctx)
	if err != nil {
		log.Fatalf("error getting Messaging client: %v", err)
	}

	sendNotification(ctx, client, "Probando titulo", "https://www.twitch.com")

	for {
		scan()
	}
}
