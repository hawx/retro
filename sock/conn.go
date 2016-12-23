package sock

import "golang.org/x/net/websocket"

type Conn struct {
	Name string
	Err  error
	hub  *Hub
	ws   *websocket.Conn
}

func (c *Conn) Send(msg Msg) {
	websocket.JSON.Send(c.ws, msg)
}

func (c *Conn) Broadcast(msg Msg) {
	c.hub.broadcast(msg)
}
