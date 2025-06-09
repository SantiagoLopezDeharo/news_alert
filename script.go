package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"regexp"
	"strings"
)

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

	//fmt.Println(string(body))

	re := regexp.MustCompile(`<a.*?href="(.*?)".*?>.*?<h2 data-testid="card-headline".*?>(.*?)</h2>`)

	return re.FindAllStringSubmatch(string(body), -1)

}

func main() {
	cl := []string{"trump", "flowers", "nukes"}
	bbc_r := bbc()

	for _, match := range bbc_r {
		if len(match) > 2 && any_contains(match, cl) {
			fmt.Println(match[2] + " -->  www.bbc.com" + match[1])
			fmt.Println()
		}
	}
}
