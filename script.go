package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"regexp"
	"strings"
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

func bbc() [][]string {
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

	re := regexp.MustCompile(`<a.*?href="([^"]*)".*?>.*?<h2 data-testid="card-headline".*?>(.*?)</h2>`)

	return re.FindAllStringSubmatch(string(body), -1)

}

func theguardian() [][]string {
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

	re := regexp.MustCompile(`<a href="([^"]*)".*?aria-label="(.*?)".*?></a>`)
	return re.FindAllStringSubmatch(string(body), -1)
}

func nytimes() [][]string {
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

	re := regexp.MustCompile(`<div class="css-cfnhvx"><a.*?href="([^"]*)"><div.*?><p.*?>([A-Za-z0-9 ]+)</p></div></a></div>`)
	return re.FindAllStringSubmatch(string(body), -1)
}

func main() {
	cl, _ := loadList("list.json")

	bbc_r := bbc()

	for _, match := range bbc_r {
		if len(match) > 2 && any_contains(match, cl) {
			fmt.Println(match[2] + " -->  www.bbc.com" + match[1])
			fmt.Println()
		}
	}

	tg := theguardian()

	for _, match := range tg {
		if len(match) > 2 && any_contains(match, cl) {
			fmt.Println(match[2] + " -->  www.theguardian.com" + match[1])
			fmt.Println()
		}
	}

	nyt := nytimes()

	for _, match := range nyt {
		if len(match) > 2 {
			fmt.Println(match[2] + " --> " + match[1])
			fmt.Println()
		}
	}

}
