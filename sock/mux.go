package sock

import "golang.org/x/net/websocket"

type Handler func(conn *Conn, args []string)

type Mux struct {
	// I'm trusting you not to insert handlers once Serve is called...
	handlers map[string]Handler
}

func NewMux() *Mux {
	return &Mux{
		handlers: map[string]Handler{},
	}
}

func (m *Mux) Handle(op string, handler Handler) {
	m.handlers[op] = handler
}

func (m *Mux) Serve(conn *Conn) error {
	for {
		var msg Msg
		if err := websocket.JSON.Receive(conn.ws, &msg); err != nil {
			return err
		}

		handler, ok := m.handlers[msg.Op]
		if !ok {
			continue
		}

		handler(conn, msg.Args)
	}
}
