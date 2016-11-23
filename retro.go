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
	columns map[string][]Card
	conns   map[string]*websocket.Conn
}

type Card struct {
	text   string
	votes  int
	author string
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

	websocket.JSON.Send(ws, msg{Id: ids, Op: "init", Args: []string{}})
	for columnName, cards := range r.columns {
		websocket.JSON.Send(ws, msg{Id: ids, Op: "column", Args: []string{columnName}})
		for _, card := range cards {
			websocket.JSON.Send(ws, msg{Id: ids, Op: "add", Args: []string{columnName, card.text}})
		}
	}

	for {
		var data msg
		if err := websocket.JSON.Receive(ws, &data); err != nil {
			log.Println(err)
			return
		}

		switch data.Op {
		case "add":
			columnName, cardText := data.Args[0], data.Args[1]

			r.columns[columnName] = append(r.columns[columnName],
				Card{text: cardText, author: ids})

			r.broadcast(msg{Id: ids, Op: "add", Args: []string{columnName, cardText}})
		}
	}
}

func main() {
	retro := &Retro{
		columns: map[string][]Card{
			"Start": []Card{},
			"More":  []Card{},
			"Keep":  []Card{},
			"Less":  []Card{},
			"Stop":  []Card{},
		},
		conns: map[string]*websocket.Conn{},
	}

	http.Handle("/ws", websocket.Handler(retro.websocketHandler))

	log.Println("listening on :8080")
	http.ListenAndServe(":8080", nil)
}
