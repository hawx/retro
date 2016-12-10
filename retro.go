package main

import (
	"io"
	"log"
	"net/http"

	"github.com/google/uuid"

	"hawx.me/code/retro/models"
	"hawx.me/code/retro/sock"

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

type Room struct {
	stage string
	hub   *sock.Hub
	mux   *sock.Mux
	retro *models.Retro
}

func NewRoom() *Room {
	room := &Room{
		hub:   sock.NewHub(),
		retro: models.NewRetro(),
	}

	room.mux = retroMux(room)

	return room
}

func boolToString(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

func (r *Room) websocketHandler(ws *websocket.Conn) {
	conn := r.hub.AddConnection(ws)
	defer r.hub.RemoveConnection(conn)

	if err := r.mux.Serve(conn); err != io.EOF {
		log.Println(err)
	}
}

func retroMux(r *Room) *sock.Mux {
	mux := sock.NewMux()

	mux.Handle("init", func(conn *sock.Conn, args []string) {
		if len(args) == 1 {
			conn.Name = args[0]

			r.initOp(conn)
		}
	})

	mux.Handle("add", func(conn *sock.Conn, args []string) {
		if len(args) == 2 {
			columnId, cardText := args[0], args[1]

			r.addOp(conn, columnId, cardText)
		}
	})

	mux.Handle("move", func(conn *sock.Conn, args []string) {
		if len(args) == 3 {
			columnFrom, columnTo, cardId := args[0], args[1], args[2]

			r.moveOp(conn, columnFrom, columnTo, cardId)
		}
	})

	mux.Handle("stage", func(conn *sock.Conn, args []string) {
		if len(args) == 1 {
			stage := args[0]

			r.stageOp(conn, stage)
		}
	})

	mux.Handle("reveal", func(conn *sock.Conn, args []string) {
		if len(args) == 2 {
			// this really shouldn't take columnId...
			columnId, cardId := args[0], args[1]

			r.revealOp(conn, columnId, cardId)
		}
	})

	mux.Handle("group", func(conn *sock.Conn, args []string) {
		if len(args) == 4 {
			columnFrom, cardFrom, columnTo, cardTo := args[0], args[1], args[2], args[3]

			r.groupOp(conn, columnFrom, cardFrom, columnTo, cardTo)
		}
	})

	mux.Handle("vote", func(conn *sock.Conn, args []string) {
		if len(args) == 2 {
			columnId, cardId := args[0], args[1]

			r.voteOp(conn, columnId, cardId)
		}
	})

	return mux
}

func (r *Room) initOp(conn *sock.Conn) {
	if r.stage != "" {
		conn.Send(sock.Msg{
			Id:   "",
			Op:   "stage",
			Args: []string{r.stage},
		})
	}

	for columnId, column := range r.retro.Columns() {
		conn.Send(sock.Msg{
			Id:   "",
			Op:   "column",
			Args: []string{columnId, column.Name},
		})

		for cardId, card := range column.Cards() {
			conn.Send(sock.Msg{
				Id:   "",
				Op:   "card",
				Args: []string{columnId, cardId, boolToString(card.Revealed)},
			})

			for contentIndex, content := range card.Contents() {
				conn.Send(sock.Msg{
					Id:   content.Author,
					Op:   "content",
					Args: []string{columnId, cardId, string(contentIndex), content.Text},
				})
			}
		}
	}
}

func (r *Room) addOp(conn *sock.Conn, columnId, cardText string) {
	content := models.Content{
		Text:   cardText,
		Author: conn.Name,
	}

	card := &models.Card{
		Id:       strId(),
		Votes:    0,
		Revealed: false,
	}

	card.Add(content)

	r.retro.Get(columnId).Add(card)

	conn.Broadcast(sock.Msg{
		Id:   "",
		Op:   "card",
		Args: []string{columnId, card.Id, boolToString(card.Revealed)},
	})

	conn.Broadcast(sock.Msg{
		Id:   content.Author,
		Op:   "content",
		Args: []string{columnId, card.Id, string(0), content.Text},
	})
}

func (r *Room) moveOp(conn *sock.Conn, columnFrom, columnTo, cardId string) {
	target := r.retro.GetCard(columnFrom, cardId)

	r.retro.Get(columnTo).Add(target)
	r.retro.Get(columnFrom).Remove(cardId)

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "move",
		Args: []string{columnFrom, columnTo, cardId},
	})
}

func (r *Room) stageOp(conn *sock.Conn, stage string) {
	r.stage = stage

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "stage",
		Args: []string{stage},
	})
}

func (r *Room) revealOp(conn *sock.Conn, columnId, cardId string) {
	r.retro.GetCard(columnId, cardId).Revealed = true

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "reveal",
		Args: []string{columnId, cardId},
	})
}

func (r *Room) groupOp(conn *sock.Conn, columnFrom, cardFrom, columnTo, cardTo string) {
	from := r.retro.GetCard(columnFrom, cardFrom)
	to := r.retro.GetCard(columnTo, cardTo)

	r.retro.Get(columnFrom).Remove(cardFrom)

	for _, content := range from.Contents() {
		to.Add(content)
	}

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "group",
		Args: []string{columnFrom, cardFrom, columnTo, cardTo},
	})
}

func (r *Room) voteOp(conn *sock.Conn, columnId, cardId string) {
	r.retro.GetCard(columnId, cardId).Votes += 1

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "vote",
		Args: []string{columnId, cardId},
	})
}

func main() {
	room := NewRoom()
	room.retro.Add(models.NewColumn(strId(), "Start"))
	room.retro.Add(models.NewColumn(strId(), "More"))
	room.retro.Add(models.NewColumn(strId(), "Keep"))
	room.retro.Add(models.NewColumn(strId(), "Less"))
	room.retro.Add(models.NewColumn(strId(), "Stop"))

	http.Handle("/ws", websocket.Handler(room.websocketHandler))

	log.Println("listening on :8080")
	http.ListenAndServe(":8080", nil)
}
