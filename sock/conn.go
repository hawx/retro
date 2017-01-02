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

func (c *Conn) send(msg Msg) error {
	return websocket.JSON.Send(c.ws, msg)
}

func (c *Conn) Send(id, op string, v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return err
	}

	return c.send(Msg{
		Id:   id,
		Op:   op,
		Data: string(data),
	})
}

func (c *Conn) Broadcast(id, op string, v interface{}) {
	data, err := json.Marshal(v)
	if err != nil {
		return
	}

	c.hub.broadcast(Msg{
		Id:   id,
		Op:   op,
		Data: string(data),
	})
}
