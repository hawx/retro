package room

import (
	"errors"
	"net/http"
	"sync"
	"time"

	"github.com/SermoDigital/jose/crypto"
	"github.com/SermoDigital/jose/jws"
	"github.com/SermoDigital/jose/jwt"
	"github.com/google/uuid"
	"hawx.me/code/retro/database"
	"hawx.me/code/retro/sock"
)

type Room struct {
	Server *sock.Server
	db     *database.Database

	mu    sync.RWMutex
	users map[string]string
}

type Config struct {
	HasGitHub    bool
	HasOffice365 bool
}

func New(config Config, db *database.Database) *Room {
	room := &Room{
		db:     db,
		Server: sock.NewServer(),
	}

	registerHandlers(config, room, room.Server)

	return room
}

func (r *Room) AddUser(username string) (string, error) {
	r.db.EnsureUser(username, strId())
	user, err := r.db.GetUser(username)
	if err != nil {
		return "", err
	}

	token, err := tokenForUser(user.Username, user.Secret)
	if err != nil {
		return "", err
	}
	return string(token), err
}

func (r *Room) IsUser(user, token string) bool {
	found, err := r.db.GetUser(user)

	parsedToken, err := jws.ParseJWT([]byte(token))
	if err != nil {
		return false
	}

	return verifyTokenIsForUser(user, found.Secret, parsedToken)
}

func (room *Room) AuthCallback(w http.ResponseWriter, r *http.Request, allowed bool, user string) {
	if allowed {
		idToken, err := room.AddUser(user)
		if err != nil {
			http.Redirect(w, r, "/?error=could_not_create_user", http.StatusFound)
		} else {
			http.Redirect(w, r, "/?token="+idToken, http.StatusFound)
		}
	} else {
		http.Redirect(w, r, "/?error=not_in_org", http.StatusFound)
	}
}

func verifyTokenIsForUser(username, secret string, token jwt.JWT) bool {
	validator := jwt.Validator{}
	validator.SetAudience("retro.hawx.me")
	validator.SetSubject(username)
	validator.Fn = jwt.ValidateFunc(func(claims jwt.Claims) error {
		if exp, ok := claims.Expiration(); !ok || time.Now().After(exp) {
			return errors.New("token expired")
		}
		return nil
	})

	return validator.Validate(token) == nil
}

func tokenForUser(username, secret string) ([]byte, error) {
	claims := jws.Claims{}
	claims.SetAudience("retro.hawx.me")
	claims.SetSubject(username)
	claims.SetExpiration(time.Now().Add(24 * time.Hour))

	return jws.NewJWT(claims, crypto.SigningMethodHS256).Serialize([]byte(secret))
}

func strId() string {
	id, _ := uuid.NewRandom()
	return id.String()
}
