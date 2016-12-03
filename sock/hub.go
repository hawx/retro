// Package sock handles the connection of websocket client connections and the
// sending of messages to them.
package sock

import (
	"sync"

	"golang.org/x/net/websocket"
)

// Msg is a standard message type that should work for all the use cases required.
type Msg struct {
	// Id is the name for the connection that the message originated from, or an
	// empty string if the message originated from the server.
	Id string `json:"id"`

	// Op is the name of the operation being carried out.
	Op string `json:"op"`

	// Args is a list of arguments for the operation.
	Args []string `json:"args"`
}

type Conn struct {
	Name string
	hub  *Hub
	ws   *websocket.Conn
}

func (c *Conn) Send(msg Msg) {
	websocket.JSON.Send(c.ws, msg)
}

func (c *Conn) Broadcast(msg Msg) {
	c.hub.broadcast(msg)
}

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
