// Package sock handles the connection of websocket client connections and the
// sending of messages to them.
package sock

import (
	"sync"

	"golang.org/x/net/websocket"
)

type Hub struct {
	mu          sync.RWMutex
	connections map[*Conn]struct{}
}

func NewHub() *Hub {
	return &Hub{
		connections: map[*Conn]struct{}{},
	}
}

// AddConnection adds a new connection to the hub, and returns the connection.
func (h *Hub) AddConnection(ws *websocket.Conn) *Conn {
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

func (h *Hub) RemoveConnection(conn *Conn) {
	h.mu.Lock()
	delete(h.connections, conn)
	h.mu.Unlock()
}

func (h *Hub) broadcast(msg Msg) {
	h.mu.Lock()
	defer h.mu.Unlock()

	for conn, _ := range h.connections {
		websocket.JSON.Send(conn.ws, msg)
	}
}
