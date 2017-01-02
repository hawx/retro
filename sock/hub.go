// Package sock handles the connection of websocket client connections and the
// sending of messages to them.
package sock

import (
	"sync"

	"golang.org/x/net/websocket"
)

type hub struct {
	mu          sync.RWMutex
	connections map[*Conn]struct{}
}

func newHub() *hub {
	return &hub{
		connections: map[*Conn]struct{}{},
	}
}

// AddConnection adds a new connection to the hub, and returns the connection.
func (h *hub) addConnection(ws *websocket.Conn) *Conn {
	conn := &Conn{
		Name: "",
		Err:  nil,
		ws:   ws,
		hub:  h,
	}

	h.mu.Lock()
	h.connections[conn] = struct{}{}
	h.mu.Unlock()

	return conn
}

func (h *hub) removeConnection(conn *Conn) {
	h.mu.Lock()
	delete(h.connections, conn)
	h.mu.Unlock()
}

func (h *hub) broadcast(msg Msg) {
	h.mu.Lock()
	defer h.mu.Unlock()

	for conn, _ := range h.connections {
		conn.Send(msg)
	}
}
