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
	userMap map[string]string
	columns map[string]*Column
	conns   map[string]*websocket.Conn
}

func NewRetro() *Retro {
	return &Retro{
		userMap: map[string]string{},
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

	for {
		var data msg
		if err := websocket.JSON.Receive(ws, &data); err != nil {
			if err != io.EOF {
				log.Println(err)
			}
			return
		}

		log.Println(data)

		switch data.Op {
		case "init":
			if len(data.Args) == 0 {
				userId := data.Id
				if userId == "" {
					userId = strId()
				}

				r.userMap[connId] = userId

				r.initOp(ws, userId)
			}

		case "add":
			if len(data.Args) == 2 {
				columnId, cardText := data.Args[0], data.Args[1]
				userId := r.userMap[connId]

				r.addOp(ws, userId, columnId, cardText)
			}

		case "move":
			if len(data.Args) == 3 {
				columnFrom, columnTo, cardId := data.Args[0], data.Args[1], data.Args[2]
				userId := r.userMap[connId]

				r.moveOp(ws, userId, columnFrom, columnTo, cardId)
			}

		case "stage":
			if len(data.Args) == 1 {
				stage := data.Args[0]
				userId := r.userMap[connId]

				r.stageOp(ws, userId, stage)
			}

		case "reveal":
			if len(data.Args) == 2 {
				// this really shouldn't take columnId...
				columnId, cardId := data.Args[0], data.Args[1]
				userId := r.userMap[connId]

				r.revealOp(ws, userId, columnId, cardId)
			}
		}
	}
}

func (r *Retro) initOp(ws *websocket.Conn, userId string) {
	websocket.JSON.Send(ws, msg{
		Id:   "",
		Op:   "init",
		Args: []string{userId},
	})

	if r.stage != "" {
		websocket.JSON.Send(ws, msg{
			Id:   "",
			Op:   "stage",
			Args: []string{r.stage},
		})
	}

	for columnId, column := range r.columns {
		websocket.JSON.Send(ws, msg{
			Id:   "",
			Op:   "column",
			Args: []string{columnId, column.name},
		})

		for cardId, card := range column.cards {
			websocket.JSON.Send(ws, msg{
				Id:   card.author,
				Op:   "add",
				Args: []string{columnId, cardId, card.text, boolToString(card.revealed)},
			})
		}
	}
}

func (r *Retro) addOp(ws *websocket.Conn, userId, columnId, cardText string) {
	cardId := r.columns[columnId].AddCard(&Card{
		text:     cardText,
		author:   userId,
		revealed: false,
	})

	r.broadcast(msg{
		Id:   userId,
		Op:   "add",
		Args: []string{columnId, cardId, cardText, boolToString(false)},
	})
}

func (r *Retro) moveOp(ws *websocket.Conn, userId, columnFrom, columnTo, cardId string) {
	r.columns[columnTo].cards[cardId] = r.columns[columnFrom].cards[cardId]
	delete(r.columns[columnFrom].cards, cardId)

	r.broadcast(msg{
		Id:   userId,
		Op:   "move",
		Args: []string{columnFrom, columnTo, cardId},
	})
}

func (r *Retro) stageOp(ws *websocket.Conn, userId, stage string) {
	r.stage = stage

	r.broadcast(msg{
		Id:   userId,
		Op:   "stage",
		Args: []string{stage},
	})
}

func (r *Retro) revealOp(ws *websocket.Conn, userId, columnId, cardId string) {
	r.columns[columnId].cards[cardId].revealed = true

	r.broadcast(msg{
		Id:   userId,
		Op:   "reveal",
		Args: []string{columnId, cardId},
	})
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
