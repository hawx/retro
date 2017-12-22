package sock

import (
	"errors"
	"log"

	"golang.org/x/net/websocket"
)

type Handler func(conn *Conn, data []byte)
type OnConnectHandler func(conn *Conn)
type Authenticator func(MsgAuth) bool

type mux struct {
	// I'm trusting you not to insert handlers once Serve is called...
	handlers map[string]Handler

	onConnect    *OnConnectHandler
	authenticate Authenticator
}

func newMux() *mux {
	return &mux{
		handlers: map[string]Handler{},
	}
}

func (m *mux) handle(op string, handler Handler) {
	m.handlers[op] = handler
}

func (m *mux) serve(conn *Conn) error {
	if m.onConnect != nil {
		(*m.onConnect)(conn)
	}

	for {
		var msg Msg
		if err := websocket.JSON.Receive(conn.ws, &msg); err != nil {
			return err
		}

		if msg.Auth == nil || !m.authenticate(*msg.Auth) {
			conn.Send("", "error", errorData{"bad_auth"})
			return errors.New("BadAuth")
		}

		conn.Name = msg.Auth.Username

		handler, ok := m.handlers[msg.Op]
		if !ok {
			log.Println("unhandled msg:", msg.Op)
			continue
		}

		handler(conn, []byte(msg.Data))
		if conn.Err != nil {
			return conn.Err
		}
	}
}

type errorData struct {
	Error string `json:"error"`
}
