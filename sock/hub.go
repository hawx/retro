// Package sock handles the connection of websocket client connections and the
// sending of messages to them.
package sock

import (
	"sync"

	"github.com/google/uuid"

	"golang.org/x/net/websocket"
)

func strId() string {
	id, _ := uuid.NewRandom()
	return id.String()
}

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
	mu sync.RWMutex

	// The current list of open connections keyed by connectionId
	connections map[string]*websocket.Conn

	// A map between connectionId->userId. Since a connection may reconnect for
	// the same user outside of the scope of this package we need to maintain the
	// illusion of a constant connection, hence constant id, this map maps from
	// the changing id to the constant id. I hate it. It can probably be removed
	// when I think up a better way to uniquely identify connections/users.
	idMap map[string]string
}

func NewHub() *Hub {
	return &Hub{
		connections: map[string]*websocket.Conn{},
		idMap:       map[string]string{},
	}
}

// AddConnection adds a new connection to the hub, and returns the connectionId.
func (h *Hub) AddConnection(conn *websocket.Conn) string {
	connId := strId()

	h.mu.Lock()
	h.connections[connId] = conn
	h.mu.Unlock()

	return connId
}

// NameConnection sets the "name" (userId) for a particular connection.
func (h *Hub) NameConnection(connId, name string) {
	h.mu.Lock()
	h.idMap[connId] = name
	h.mu.Unlock()
}

func (h *Hub) Get(connId string) *Conn {
	h.mu.RLock()
	name := h.idMap[connId]
	ws := h.connections[connId]
	h.mu.RUnlock()

	return &Conn{
		Name: name,
		hub:  h,
		ws:   ws,
	}
}

func (h *Hub) broadcast(msg Msg) {
	h.mu.Lock()
	defer h.mu.Unlock()

	for _, conn := range h.connections {
		websocket.JSON.Send(conn, msg)
	}
}
