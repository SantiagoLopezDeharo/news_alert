package utils

import (
	"encoding/json"
	"io/ioutil"
	"os"
	"strings"
)

func SaveList(filename string, list []string) error {
	data, err := json.MarshalIndent(list, "", "  ")
	if err != nil {
		return err
	}
	return ioutil.WriteFile(filename, data, 0644)
}

func LoadList(filename string) ([]string, error) {
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		if os.IsNotExist(err) {
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

func AnyContains(s []string, cl []string) bool {
	for _, c := range cl {
		if strings.Contains(strings.ToLower(s[2]), c) {
			return true
		}
	}
	return false
}
