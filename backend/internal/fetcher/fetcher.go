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
	"github.com/PuerkitoBio/goquery"
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

func Scan(usersFile string, ctx context.Context, client *messaging.Client) {
	users, _ := utils.LoadUsers(usersFile)

	var wg sync.WaitGroup
	wg.Add(6)

	var bbc_r, tg, nyt, abcl, az, mvdn [][]string

	go func() {
		defer wg.Done()
		bbc_r = <-fetchNews("https://www.bbc.com", "/news", `<a.*?href="([^"]*)".*?>.*?<h2 data-testid="card-headline".*?>([^</]*?)</h2>`)
	}()
	go func() {
		defer wg.Done()
		tg = <-fetchNews("https://www.theguardian.com", "/international", `<a href="([^"]*)".*?aria-label="([^"]*)".*?></a>`)
	}()
	go func() {
		defer wg.Done()
		nyt = <-fetchNews("https://www.nytimes.com", "/international", `<div class="css-cfnhvx"><a.*?href="([^"]*)"><div.*?><p.*?>([^</]*?)</p></div></a></div>`)
	}()
	go func() {
		defer wg.Done()
		abcl = <-fetchNews("https://abcnews.go.com", "/International", `<h2><a.*?href="([^"]*)".*?>.*?([^</]*?)</a></h2>`)
	}()
	go func() {
		defer wg.Done()
		az = <-fetchNews("https://www.aljazeera.com", "", `<a.*?href="([^"]*)".*?>.*?<span>([^</]*?)</span></a>`)
	}()
	go func() {
		defer wg.Done()
		mvdn = <-mvd()
	}()

	wg.Wait()

	allNews := []struct {
		Matches [][]string
		Prefix  string
	}{
		{bbc_r, "https://www.bbc.com"},
		{tg, "https://www.theguardian.com"},
		{nyt, "https://www.nytimes.com"},
		{abcl, "https://abcnews.go.com"},
		{az, "https://www.aljazeera.com"},
		{mvdn, "https://www.montevideo.com.uy"},
	}

	userWg := sync.WaitGroup{}
	for ui, user := range users {
		if user.Token == "" {
			continue // skip users without a valid FCM token
		}
		userWg.Add(1)
		go func(ui int, user utils.User) {
			defer userWg.Done()
			msgs := []*messaging.Message{}
			userLinks := make(map[string]struct{})
			newLinks := []string{}
			for _, l := range user.LinksHistory {
				userLinks[l] = struct{}{}
			}
			for _, news := range allNews {
				for _, match := range news.Matches {
					if len(match) > 1 {
						link := match[1]
						if !strings.Contains(link, news.Prefix) {
							link = news.Prefix + link
						}
						hash := utils.HashLink(link)
						if _, sent := userLinks[hash]; sent {
							continue // skip already sent links
						}
						if len(match) > 2 && utils.AnyContains(match, user.Topics) {
							title := match[2]
							msgs = append(msgs, notifier.GenerateMessage(title, link, user.Token))
							newLinks = append(newLinks, hash)
						}
					}
				}
			}
			chunks := splitIntoChunks(msgs, 500)
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
			if len(newLinks) > 0 {
				users[ui].LinksHistory = append(users[ui].LinksHistory, newLinks...)
				if len(users[ui].LinksHistory) > utils.MaxLinksHistory {
					users[ui].LinksHistory = users[ui].LinksHistory[len(users[ui].LinksHistory)-utils.MaxLinksHistory:]
				}
			}
		}(ui, user)
	}
	userWg.Wait()
	_ = utils.SaveUsers(usersFile, users)
	wg.Wait()
	fmt.Println("Scan completed at ", time.Now())
}

func fetchNews(url string, path string, reg string) chan [][]string {
	ret := make(chan [][]string)

	go func() {
		resp, err := http.Get(url + path)
		if err != nil {
			panic(err)
		}
		defer resp.Body.Close()

		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			panic(err)
		}

		re := regexp.MustCompile(reg)
		ret <- re.FindAllStringSubmatch(string(body), -1)
		close(ret)
	}()

	return ret
}

func mvd() chan [][]string {
	ret := make(chan [][]string)
	go func() {
		defer close(ret)
		url := "https://www.montevideo.com.uy"
		headers := map[string]string{
			"User-Agent":      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
			"Accept-Language": "es-ES,es;q=0.9",
		}
		client := &http.Client{}
		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			ret <- [][]string{}
			return
		}
		for k, v := range headers {
			req.Header.Add(k, v)
		}
		res, err := client.Do(req)
		if err != nil {
			ret <- [][]string{}
			return
		}
		defer res.Body.Close()

		if res.StatusCode != 200 {
			ret <- [][]string{}
			return
		}
		doc, err := goquery.NewDocumentFromReader(res.Body)
		if err != nil {
			ret <- [][]string{}
			return
		}
		var resultados [][]string
		urlsVistas := make(map[string]bool)
		doc.Find("article").Each(func(i int, s *goquery.Selection) {
			clases, _ := s.Attr("class")
			if !strings.Contains(clases, "noticia") {
				return
			}

			enlace := s.Find("a")
			titulo := s.Find("h2, h3, h4").First()

			if enlace.Length() == 0 || titulo.Length() == 0 {
				return
			}

			href, exists := enlace.Attr("href")
			if !exists {
				return
			}

			urlNoticia := href
			if !strings.HasPrefix(urlNoticia, "http") {
				urlNoticia = "https://www.montevideo.com.uy" + href
			}

			if urlsVistas[urlNoticia] {
				return
			}
			urlsVistas[urlNoticia] = true

			resultados = append(resultados, []string{
				"",            // Padding
				urlNoticia,    // URL
				titulo.Text(), // title
			})
		})
		ret <- resultados
	}()

	return ret
}
