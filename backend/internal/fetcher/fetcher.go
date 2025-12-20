package fetcher

import (
	"context"
	"fmt"
	"io"
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

var (
	bbcReg  = regexp.MustCompile(`<a.*?href="([^"]*)".*?>.*?<h2 data-testid="card-headline".*?>([^</]*?)</h2>`)
	tgReg   = regexp.MustCompile(`<a href="([^"]*)".*?aria-label="([^"]*)".*?></a>`)
	nytReg  = regexp.MustCompile(`<div class="css-cfnhvx"><a.*?href="([^"]*)"><div.*?><p.*?>([^</]*?)</p></div></a></div>`)
	abclReg = regexp.MustCompile(`<h2><a.*?href="([^"]*)".*?>.*?([^</]*?)</a></h2>`)
	azReg   = regexp.MustCompile(`<a.*?href="([^"]*)".*?>.*?<span>([^</]*?)</span></a>`)
)

var httpClient = &http.Client{
	Timeout: 30 * time.Second,
}

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
	users, err := utils.LoadUsers(usersFile)
	if err != nil {
		fmt.Printf("Error loading users: %v\n", err)
		return
	}

	var wg sync.WaitGroup
	wg.Add(6)

	var bbc_r, tg, nyt, abcl, az, mvdn [][]string

	go func() {
		defer wg.Done()
		bbc_r = fetchNews("https://www.bbc.com", "/news", bbcReg)
	}()
	go func() {
		defer wg.Done()
		tg = fetchNews("https://www.theguardian.com", "/international", tgReg)
	}()
	go func() {
		defer wg.Done()
		nyt = fetchNews("https://www.nytimes.com", "/international", nytReg)
	}()
	go func() {
		defer wg.Done()
		abcl = fetchNews("https://abcnews.go.com", "/International", abclReg)
	}()
	go func() {
		defer wg.Done()
		az = fetchNews("https://www.aljazeera.com", "", azReg)
	}()
	go func() {
		defer wg.Done()
		mvdn = mvd()
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

	type NewsItem struct {
		Link  string
		Hash  string
		Title string
	}
	var collectedNews []NewsItem

	for _, news := range allNews {
		if news.Matches == nil {
			continue
		}
		for _, match := range news.Matches {
			if len(match) > 1 {
				link := match[1]
				if !strings.Contains(link, news.Prefix) {
					link = news.Prefix + link
				}
				hash := utils.HashLink(link)
				title := ""
				if len(match) > 2 {
					title = match[2]
				}
				collectedNews = append(collectedNews, NewsItem{Link: link, Hash: hash, Title: title})
			}
		}
	}

	userWg := sync.WaitGroup{}
	for ui, user := range users {
		if user.Token == "" {
			continue
		}
		userWg.Add(1)
		go func(ui int, user utils.User) {
			defer userWg.Done()
			msgs := []*messaging.Message{}
			userLinks := make(map[string]struct{})
			newLinks := []string{}
			newLinksSet := make(map[string]struct{})
			for _, l := range user.LinksHistory {
				userLinks[l] = struct{}{}
			}

			for _, item := range collectedNews {
				if _, sent := userLinks[item.Hash]; sent {
					continue
				}
				if _, sent := newLinksSet[item.Hash]; sent {
					continue
				}

				if item.Title != "" && containsTopic(item.Title, user.Topics) {
					msgs = append(msgs, notifier.GenerateMessage(item.Title, item.Link, user.Token))
					newLinks = append(newLinks, item.Hash)
					newLinksSet[item.Hash] = struct{}{}
				}
			}

			chunks := splitIntoChunks(msgs, 500)
			chunkWg := sync.WaitGroup{}
			chunkWg.Add(len(chunks))
			for _, chunk := range chunks {
				if len(chunk) == 0 {
					chunkWg.Done()
					continue
				}
				go func(c []*messaging.Message) {
					defer chunkWg.Done()
					notifier.SendNotifications(ctx, client, c)
				}(chunk)
			}
			chunkWg.Wait()

			if len(newLinks) > 0 {
				users[ui].LinksHistory = append(users[ui].LinksHistory, newLinks...)
				if len(users[ui].LinksHistory) > utils.MaxLinksHistory {
					users[ui].LinksHistory = users[ui].LinksHistory[len(users[ui].LinksHistory)-utils.MaxLinksHistory:]
				}
			}
		}(ui, user)
	}
	userWg.Wait()
	if err := utils.SaveUsers(usersFile, users); err != nil {
		fmt.Printf("Error saving users: %v\n", err)
	}
	fmt.Println("Scan completed at ", time.Now())
}

func containsTopic(title string, topics []string) bool {
	titleLower := strings.ToLower(title)
	for _, topic := range topics {
		if strings.Contains(titleLower, strings.ToLower(topic)) {
			return true
		}
	}
	return false
}

func fetchNews(url string, path string, re *regexp.Regexp) [][]string {
	resp, err := httpClient.Get(url + path)
	if err != nil {
		fmt.Printf("Error fetching %s: %v\n", url, err)
		return nil
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Printf("Error reading body from %s: %v\n", url, err)
		return nil
	}

	return re.FindAllStringSubmatch(string(body), -1)
}

func mvd() [][]string {
	url := "https://www.montevideo.com.uy"
	headers := map[string]string{
		"User-Agent":      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
		"Accept-Language": "es-ES,es;q=0.9",
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		fmt.Printf("Error creating request for mvd: %v\n", err)
		return nil
	}
	for k, v := range headers {
		req.Header.Add(k, v)
	}
	res, err := httpClient.Do(req)
	if err != nil {
		fmt.Printf("Error fetching mvd: %v\n", err)
		return nil
	}
	defer res.Body.Close()

	if res.StatusCode != 200 {
		fmt.Printf("Error fetching mvd, status: %d\n", res.StatusCode)
		return nil
	}
	doc, err := goquery.NewDocumentFromReader(res.Body)
	if err != nil {
		fmt.Printf("Error parsing mvd: %v\n", err)
		return nil
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
	return resultados
}
