package sock

import "golang.org/x/net/websocket"

type Handler func(conn *Conn, args []string)

type mux struct {
	// I'm trusting you not to insert handlers once Serve is called...
	handlers map[string]Handler
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
		if conn.Err != nil {
			return conn.Err
		}
	}
}
