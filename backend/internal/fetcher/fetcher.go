package fetcher

import (
	"context"
	"fmt"
	"io/ioutil"
	"net/http"
	"news_alert_backend/internal/notifier"
	"news_alert_backend/internal/utils"
	"regexp"
	"sync"
	"time"

	"firebase.google.com/go/messaging"
)

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

	printMatches(bbc_r, cl, "www.bbc.com", ctx, client)
	printMatches(tg, cl, "www.theguardian.com", ctx, client)
	printMatches(nyt, cl, "", ctx, client)
	printMatches(abcl, cl, "", ctx, client)
	printMatches(az, cl, "https://www.aljazeera.com", ctx, client)

	fmt.Println("Scan Ended at ", time.Now())
}

func printMatches(matches [][]string, cl []string, prefix string, ctx context.Context, client *messaging.Client) {
	var wg sync.WaitGroup

	for _, match := range matches {
		if len(match) > 2 && utils.AnyContains(match, cl) {
			title := match[2]
			link := match[1]
			if prefix != "" {
				link = prefix + link
			}
			fmt.Println(title + " --> " + link)
			fmt.Println()

			wg.Add(1)
			go func(title, link string) {
				defer wg.Done()
				notifier.SendNotification(ctx, client, title, link)
			}(title, link)
		}
	}

	wg.Wait()
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
