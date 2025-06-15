package utils

import (
	"encoding/json"
	"io/ioutil"
	"os"
	"strings"
)

func AnyContains(s []string, cl []string) bool {
	for _, c := range cl {
		if strings.Contains(strings.ToLower(s[2]), c) {
			return true
		}
	}
	return false
}

type User struct {
	ID           string   `json:"id"`    // Stable user identifier (e.g., UUID or account ID)
	Token        string   `json:"token"` // FCM token (can change)
	Topics       []string `json:"topics"`
	LinksHistory []string `json:"links_history"` // History of links sent to the user
}

func LoadUsers(filename string) ([]User, error) {
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		if os.IsNotExist(err) {
			empty := []User{}
			emptyData, _ := json.Marshal(empty)
			err = ioutil.WriteFile(filename, emptyData, 0644)
			if err != nil {
				return nil, err
			}
			return empty, nil
		}
		return nil, err
	}
	var users []User
	err = json.Unmarshal(data, &users)
	return users, err
}

func SaveUsers(filename string, users []User) error {
	data, err := json.MarshalIndent(users, "", "  ")
	if err != nil {
		return err
	}
	return ioutil.WriteFile(filename, data, 0644)
}
