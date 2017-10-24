package auth

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"golang.org/x/oauth2"
)

func Office365(authCallback AuthCallback, clientID, clientSecret, domain string) (login, callback http.HandlerFunc) {
	ctx := context.Background()
	conf := &oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Scopes:       []string{"user.read"},
		Endpoint: oauth2.Endpoint{
			AuthURL:  "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
			TokenURL: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
		},
	}

	login = func(w http.ResponseWriter, r *http.Request) {
		url := conf.AuthCodeURL("state", oauth2.AccessTypeOnline)

		http.Redirect(w, r, url, http.StatusFound)
	}

	callback = func(w http.ResponseWriter, r *http.Request) {
		code := r.FormValue("code")

		tok, err := conf.Exchange(ctx, code)
		if err != nil {
			log.Println(err)
			return
		}

		client := conf.Client(ctx, tok)

		user, err := getOfficeUser(client)
		if err != nil {
			log.Println(err)
			return
		}

		authCallback(w, r, isInDomain(user, domain), user)
	}

	return login, callback
}

func getOfficeUser(client *http.Client) (string, error) {
	resp, err := client.Get("https://graph.microsoft.com/v1.0/me/")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var data struct {
		Mail string `json:"mail"`
	}
	if err = json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return "", err
	}

	return data.Mail, nil
}

func isInDomain(mail, domain string) bool {
	return strings.HasSuffix(mail, domain)
}
