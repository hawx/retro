package main

import (
	"io"
	"log"
	"net/http"

	"hawx.me/code/retro/sock"

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
	hub   *sock.Hub
	// mu, pls
	columns map[string]*Column
}

func NewRetro() *Retro {
	return &Retro{
		hub:     sock.NewHub(),
		columns: map[string]*Column{},
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

func boolToString(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

func (r *Retro) websocketHandler(ws *websocket.Conn) {
	connId := r.hub.AddConnection(ws)

	for {
		var data msg
		if err := websocket.JSON.Receive(ws, &data); err != nil {
			if err != io.EOF {
				log.Println(err)
			}
			return
		}

		switch data.Op {
		case "init":
			if len(data.Args) == 0 {
				userId := data.Id
				if userId == "" {
					userId = strId()
				}

				r.hub.NameConnection(connId, userId)

				r.initOp(r.hub.Get(connId))
			}

		case "add":
			if len(data.Args) == 2 {
				columnId, cardText := data.Args[0], data.Args[1]

				r.addOp(r.hub.Get(connId), columnId, cardText)
			}

		case "move":
			if len(data.Args) == 3 {
				columnFrom, columnTo, cardId := data.Args[0], data.Args[1], data.Args[2]

				r.moveOp(r.hub.Get(connId), columnFrom, columnTo, cardId)
			}

		case "stage":
			if len(data.Args) == 1 {
				stage := data.Args[0]

				r.stageOp(r.hub.Get(connId), stage)
			}

		case "reveal":
			if len(data.Args) == 2 {
				// this really shouldn't take columnId...
				columnId, cardId := data.Args[0], data.Args[1]

				r.revealOp(r.hub.Get(connId), columnId, cardId)
			}
		}
	}
}

func (r *Retro) initOp(conn *sock.Conn) {
	if r.stage != "" {
		conn.Send(sock.Msg{
			Id:   "",
			Op:   "stage",
			Args: []string{r.stage},
		})
	}

	for columnId, column := range r.columns {
		conn.Send(sock.Msg{
			Id:   "",
			Op:   "column",
			Args: []string{columnId, column.name},
		})

		for cardId, card := range column.cards {
			conn.Send(sock.Msg{
				Id:   card.author,
				Op:   "add",
				Args: []string{columnId, cardId, card.text, boolToString(card.revealed)},
			})
		}
	}
}

func (r *Retro) addOp(conn *sock.Conn, columnId, cardText string) {
	cardId := r.columns[columnId].AddCard(&Card{
		text:     cardText,
		author:   conn.Name,
		revealed: false,
	})

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "add",
		Args: []string{columnId, cardId, cardText, boolToString(false)},
	})
}

func (r *Retro) moveOp(conn *sock.Conn, columnFrom, columnTo, cardId string) {
	r.columns[columnTo].cards[cardId] = r.columns[columnFrom].cards[cardId]
	delete(r.columns[columnFrom].cards, cardId)

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "move",
		Args: []string{columnFrom, columnTo, cardId},
	})
}

func (r *Retro) stageOp(conn *sock.Conn, stage string) {
	r.stage = stage

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "stage",
		Args: []string{stage},
	})
}

func (r *Retro) revealOp(conn *sock.Conn, columnId, cardId string) {
	r.columns[columnId].cards[cardId].revealed = true

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
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
