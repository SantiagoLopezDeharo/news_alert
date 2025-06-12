package api

import (
	"encoding/json"
	"io/ioutil"
	"net/http"
)

func StartServer() {
	http.HandleFunc("/update-list", updateListHandler)
	http.HandleFunc("/update-token", updateTokenHandler)
	http.HandleFunc("/get-list", getListHandler)
	http.ListenAndServe(":8080", nil)
}

func updateListHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST allowed", http.StatusMethodNotAllowed)
		return
	}
	var list []string
	if err := json.NewDecoder(r.Body).Decode(&list); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}
	if err := ioutil.WriteFile("list.json", mustJSON(list), 0644); err != nil {
		http.Error(w, "Failed to write list.json", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func updateTokenHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST allowed", http.StatusMethodNotAllowed)
		return
	}
	type Token struct {
		Token string `json:"token"`
	}
	var t Token
	if err := json.NewDecoder(r.Body).Decode(&t); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}
	if err := ioutil.WriteFile("fcm_token.txt", []byte(t.Token), 0644); err != nil {
		http.Error(w, "Failed to write fcm_token.txt", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func getListHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Only GET allowed", http.StatusMethodNotAllowed)
		return
	}
	data, err := ioutil.ReadFile("list.json")
	if err != nil {
		http.Error(w, "Failed to read list.json", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(data)
}

func mustJSON(v interface{}) []byte {
	b, _ := json.MarshalIndent(v, "", "  ")
	return b
}
