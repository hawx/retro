package main

import (
	"log"
	"net/http"

	"github.com/google/uuid"
	"golang.org/x/net/websocket"
)

type msg struct {
	Id   string   `json:"id"`
	Op   string   `json:"op"`
	Args []string `json:"args"`
}

type Retro struct {
	cards []string
	conns map[string]*websocket.Conn
}

func (r *Retro) broadcast(data msg) {
	for _, conn := range r.conns {
		websocket.JSON.Send(conn, data)
	}
}

func (r *Retro) websocketHandler(ws *websocket.Conn) {
	id, err := uuid.NewRandom()
	if err != nil {
		log.Println(err)
		return
	}
	ids := id.String()

	r.conns[ids] = ws
	websocket.JSON.Send(ws, msg{Id: ids, Op: "init", Args: r.cards})

	for {
		var data msg
		if err := websocket.JSON.Receive(ws, &data); err != nil {
			log.Println(err)
			return
		}

		switch data.Op {
		case "add":
			r.cards = append(r.cards, data.Args[0])
			r.broadcast(msg{Id: ids, Op: "add", Args: []string{data.Args[0]}})
		}
	}
}

func main() {
	retro := &Retro{
		cards: []string{"what"},
		conns: map[string]*websocket.Conn{},
	}

	http.Handle("/ws", websocket.Handler(retro.websocketHandler))

	log.Println("listening on :8080")
	http.ListenAndServe(":8080", nil)
}
