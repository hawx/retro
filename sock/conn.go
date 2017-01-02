package sock

import (
	"encoding/json"

	"golang.org/x/net/websocket"
)

type Conn struct {
	Name string
	Err  error
	hub  *hub
	ws   *websocket.Conn
}

func (c *Conn) Send(msg Msg) error {
	return websocket.JSON.Send(c.ws, msg)
}

func (c *Conn) Send2(id, op string, v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return err
	}

	return c.Send(Msg{
		Id:   id,
		Op:   op,
		Data: string(data),
	})
}

func (c *Conn) Broadcast(msg Msg) {
	c.hub.broadcast(msg)
}

func (c *Conn) Broadcast2(id, op string, v interface{}) {
	data, err := json.Marshal(v)
	if err != nil {
		return
	}

	c.Broadcast(Msg{
		Id:   id,
		Op:   op,
		Data: string(data),
	})
}
