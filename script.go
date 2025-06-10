package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
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

	bbc_rF := bbc()
	tgF := theguardian()
	nytF := nytimes()
	abcF := abc()

	bbc_r := <-bbc_rF
	tg := <-tgF
	nyt := <-nytF
	abcl := <-abcF

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

	azF := alijazeera()
	az := <-azF

	for _, match := range az {
		if len(match) > 2 && any_contains(match, cl) {
			fmt.Println(match[2] + " --> https://www.aljazeera.com" + match[1])
			fmt.Println()
		}
	}

	time.Sleep(6 * time.Hour)

}

func main() {
	for {
		scan()
	}
}
