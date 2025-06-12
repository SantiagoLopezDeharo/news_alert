package fetcher

import (
	"context"
	"fmt"
	"io/ioutil"
	"net/http"
	"news_alert_backend/internal/notifier"
	"news_alert_backend/internal/utils"
	"regexp"
	"strings"
	"sync"
	"time"

	"firebase.google.com/go/v4/messaging"
)

func splitIntoChunks[T any](input []T, chunkSize int) [][]T {
	var chunks [][]T
	for i := 0; i < len(input); i += chunkSize {
		end := i + chunkSize
		if end > len(input) {
			end = len(input)
		}
		chunks = append(chunks, input[i:end])
	}
	return chunks
}

func generateMessages(matches [][]string, cl []string, prefix string, token string) []*messaging.Message {

	ret := []*messaging.Message{}
	if len(matches) == 0 {
		return ret
	}

	for _, match := range matches {
		if len(match) > 2 && utils.AnyContains(match, cl) {
			title := match[2]
			link := match[1]
			if !strings.Contains(link, prefix) {
				link = prefix + link
			}

			// fmt.Println(title + " --> " + link)
			// fmt.Println()
			ret = append(ret, notifier.GenerateMessage(title, link, token))
		}
	}

	return ret
}

func Scan(listFile string, ctx context.Context, client *messaging.Client) {
	cl, _ := utils.LoadList(listFile)

	var wg sync.WaitGroup
	wg.Add(5)

	var bbc_r, tg, nyt, abcl, az [][]string

	go func() { defer wg.Done(); bbc_r = <-bbc() }()
	go func() { defer wg.Done(); tg = <-theguardian() }()
	go func() { defer wg.Done(); nyt = <-nytimes() }()
	go func() { defer wg.Done(); abcl = <-abc() }()
	go func() { defer wg.Done(); az = <-alijazeera() }()

	wg.Wait()

	tokenBytes, err := ioutil.ReadFile("fcm_token.txt")
	if err != nil {
		fmt.Println("Error reading FCM token:", err)
		return
	}

	token := string(tokenBytes)

	msgs := []*messaging.Message{}

	msgs = append(msgs, generateMessages(bbc_r, cl, "https://www.bbc.com", token)...)
	msgs = append(msgs, generateMessages(tg, cl, "https://www.theguardian.com", token)...)
	msgs = append(msgs, generateMessages(nyt, cl, "https://www.nytimes.com", token)...)
	msgs = append(msgs, generateMessages(abcl, cl, "https://abcnews.go.com", token)...)
	msgs = append(msgs, generateMessages(az, cl, "https://www.aljazeera.com", token)...)

	chunks := splitIntoChunks(msgs, 500) // Relisticly for this use case there will never be more than 500 messages at a time, but this is a good practice anyways since Firebase won't admit to send a batch larger than 500 messages at once and it doesn't hurt performance.

	wg.Add(len(chunks))

	for _, chunk := range chunks {
		if len(chunk) == 0 {
			wg.Done()
			continue
		}
		go func(c []*messaging.Message) {
			defer wg.Done()
			notifier.SendNotifications(ctx, client, c)
		}(chunk)
	}

	wg.Wait()
	fmt.Println("Scan completed at ", time.Now())
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
