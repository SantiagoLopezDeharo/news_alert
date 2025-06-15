package api

import (
	"encoding/json"
	"net/http"
	"news_alert_backend/internal/utils"
)

func StartServer() {
	http.HandleFunc("/users", usersHandler)
	http.HandleFunc("/set-topics", setTopicsHandler)
	http.HandleFunc("/set-token", setTokenHandler)
	http.ListenAndServe(":8080", nil)
}

func usersHandler(w http.ResponseWriter, r *http.Request) {
	const usersFile = "users.json"

	switch r.Method {
	case http.MethodGet:
		userID := r.URL.Query().Get("id")
		if userID == "" {
			http.Error(w, "Missing id parameter", http.StatusBadRequest)
			return
		}
		users, err := utils.LoadUsers(usersFile)
		if err != nil {
			http.Error(w, "Failed to load users", http.StatusInternalServerError)
			return
		}
		for _, u := range users {
			if u.ID == userID {
				w.Header().Set("Content-Type", "application/json")
				json.NewEncoder(w).Encode(struct {
					Topics []string `json:"topics"`
					Token  string   `json:"token"`
				}{u.Topics, u.Token})
				return
			}
		}
		http.Error(w, "User not found", http.StatusNotFound)
		return
	default:
		http.Error(w, "Only GET allowed", http.StatusMethodNotAllowed)
	}
}

func setTopicsHandler(w http.ResponseWriter, r *http.Request) {
	const usersFile = "users.json"
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		ID     string   `json:"id"`
		Topics []string `json:"topics"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}
	if req.ID == "" {
		http.Error(w, "User ID required", http.StatusBadRequest)
		return
	}
	users, _ := utils.LoadUsers(usersFile)
	found := false
	for i, u := range users {
		if u.ID == req.ID {
			users[i].Topics = req.Topics
			found = true
			break
		}
	}
	if !found {
		users = append(users, utils.User{ID: req.ID, Topics: req.Topics})
	}
	if err := utils.SaveUsers(usersFile, users); err != nil {
		http.Error(w, "Failed to save users", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func setTokenHandler(w http.ResponseWriter, r *http.Request) {
	const usersFile = "users.json"
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		ID    string `json:"id"`
		Token string `json:"token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}
	if req.ID == "" {
		http.Error(w, "User ID required", http.StatusBadRequest)
		return
	}
	users, _ := utils.LoadUsers(usersFile)
	found := false
	for i, u := range users {
		if u.ID == req.ID {
			users[i].Token = req.Token
			found = true
			break
		}
	}
	if !found {
		users = append(users, utils.User{ID: req.ID, Token: req.Token})
	}
	if err := utils.SaveUsers(usersFile, users); err != nil {
		http.Error(w, "Failed to save users", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
}
