package main

import (
	"io"
	"log"
	"net/http"

	"github.com/google/uuid"
	"golang.org/x/net/websocket"
)

func strId() string {
	id, _ := uuid.NewRandom()
	return id.String()
}

type msg struct {
	Id   string   `json:"id"`
	Op   string   `json:"op"`
	Args []string `json:"args"`
}

type Retro struct {
	stage string
	// mu, pls
	columns map[string]*Column
	conns   map[string]*websocket.Conn
}

func NewRetro() *Retro {
	return &Retro{
		columns: map[string]*Column{},
		conns:   map[string]*websocket.Conn{},
	}
}

func (r *Retro) AddColumn(column *Column) string {
	id := strId()
	r.columns[id] = column
	return id
}

type Column struct {
	name string
	// mu pls
	cards map[string]*Card
}

func NewColumn(name string) *Column {
	return &Column{
		name:  name,
		cards: map[string]*Card{},
	}
}

func (c *Column) AddCard(card *Card) string {
	id := strId()
	c.cards[id] = card
	return id
}

type Card struct {
	text     string
	votes    int
	author   string
	revealed bool
}

func (r *Retro) broadcast(data msg) {
	for _, conn := range r.conns {
		websocket.JSON.Send(conn, data)
	}
}

func boolToString(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

func (r *Retro) websocketHandler(ws *websocket.Conn) {
	connId := strId()

	r.conns[connId] = ws

	log.Println("Connected to", connId)

	websocket.JSON.Send(ws, msg{
		Id:   connId,
		Op:   "init",
		Args: []string{},
	})

	if r.stage != "" {
		websocket.JSON.Send(ws, msg{
			Id:   connId,
			Op:   "stage",
			Args: []string{r.stage},
		})
	}

	for columnId, column := range r.columns {
		websocket.JSON.Send(ws, msg{
			Id:   connId,
			Op:   "column",
			Args: []string{columnId, column.name},
		})

		for cardId, card := range column.cards {
			websocket.JSON.Send(ws, msg{
				Id:   connId,
				Op:   "add",
				Args: []string{columnId, cardId, card.text, boolToString(card.revealed)},
			})
		}
	}

	for {
		var data msg
		if err := websocket.JSON.Receive(ws, &data); err != nil {
			if err != io.EOF {
				log.Println(err)
			}
			return
		}

		switch data.Op {
		case "add":
			columnId, cardText := data.Args[0], data.Args[1]

			cardId := r.columns[columnId].AddCard(&Card{
				text:     cardText,
				author:   connId,
				revealed: false,
			})

			r.broadcast(msg{
				Id:   connId,
				Op:   "add",
				Args: []string{columnId, cardId, cardText, boolToString(false)},
			})

		case "move":
			columnFrom, columnTo, cardId := data.Args[0], data.Args[1], data.Args[2]

			r.columns[columnTo].cards[cardId] = r.columns[columnFrom].cards[cardId]
			delete(r.columns[columnFrom].cards, cardId)

			r.broadcast(msg{
				Id:   connId,
				Op:   "move",
				Args: []string{columnFrom, columnTo, cardId},
			})

		case "stage":
			stage := data.Args[0]

			r.stage = stage

			r.broadcast(msg{
				Id:   connId,
				Op:   "stage",
				Args: []string{stage},
			})
		}
	}
}

func main() {
	retro := NewRetro()
	retro.AddColumn(NewColumn("Start"))
	retro.AddColumn(NewColumn("More"))
	retro.AddColumn(NewColumn("Keep"))
	retro.AddColumn(NewColumn("Less"))
	retro.AddColumn(NewColumn("Stop"))

	http.Handle("/ws", websocket.Handler(retro.websocketHandler))

	log.Println("listening on :8080")
	http.ListenAndServe(":8080", nil)
}
