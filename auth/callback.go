package auth

import "net/http"

type AuthCallback func(w http.ResponseWriter, r *http.Request, allowed bool, user string)
