package auth

import "net/http"

func Test(authCallback AuthCallback) (login, callback http.HandlerFunc) {
	login = func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "http://localhost:8080/oauth/test/callback", http.StatusFound)
	}

	callback = func(w http.ResponseWriter, r *http.Request) {
		authCallback(w, r, true, "test@example.com")
	}

	return login, callback
}
