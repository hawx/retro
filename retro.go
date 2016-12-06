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
	mux   *sock.Mux
	// mu, pls
	columns map[string]*Column
}

func NewRetro() *Retro {
	r := &Retro{
		hub:     sock.NewHub(),
		columns: map[string]*Column{},
	}
	r.mux = retroMux(r)

	return r
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
	votes    int
	revealed bool
	contents []Content
}

type Content struct {
	text   string
	author string
}

func boolToString(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

func (r *Retro) websocketHandler(ws *websocket.Conn) {
	conn := r.hub.AddConnection(ws)
	defer r.hub.RemoveConnection(conn)

	if err := r.mux.Serve(conn); err != io.EOF {
		log.Println(err)
	}
}

func retroMux(r *Retro) *sock.Mux {
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

	return mux
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
				Id:   "",
				Op:   "card",
				Args: []string{columnId, cardId, boolToString(card.revealed)},
			})

			for contentIndex, content := range card.contents {
				conn.Send(sock.Msg{
					Id:   content.author,
					Op:   "content",
					Args: []string{columnId, cardId, string(contentIndex), content.text},
				})
			}
		}
	}
}

func (r *Retro) addOp(conn *sock.Conn, columnId, cardText string) {
	content := Content{
		text:   cardText,
		author: conn.Name,
	}

	cardId := r.columns[columnId].AddCard(&Card{
		votes:    0,
		revealed: false,
		contents: []Content{content},
	})

	conn.Broadcast(sock.Msg{
		Id:   "",
		Op:   "card",
		Args: []string{columnId, cardId, boolToString(false)},
	})

	conn.Broadcast(sock.Msg{
		Id:   content.author,
		Op:   "content",
		Args: []string{columnId, cardId, string(0), content.text},
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

func (r *Retro) groupOp(conn *sock.Conn, columnFrom, cardFrom, columnTo, cardTo string) {
	from := r.columns[columnFrom].cards[cardFrom]
	to := r.columns[columnTo].cards[cardTo]

	delete(r.columns[columnFrom].cards, cardFrom)
	to.contents = append(to.contents, from.contents...)

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "group",
		Args: []string{columnFrom, cardFrom, columnTo, cardTo},
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
