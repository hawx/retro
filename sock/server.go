package sock

import (
	"io"
	"log"
	"net/http"

	"golang.org/x/net/websocket"
)

type Server struct {
	hub *hub
	mux *mux
}

func NewServer() *Server {
	return &Server{
		hub: newHub(),
		mux: newMux(),
	}
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	websocket.Handler(s.serve).ServeHTTP(w, r)
}

func (s *Server) serve(ws *websocket.Conn) {
	conn := s.hub.addConnection(ws)
	defer s.hub.removeConnection(conn)

	if err := s.mux.serve(conn); err != io.EOF {
		log.Println(err)
	}
}

func (s *Server) Handle(op string, handler Handler) {
	s.mux.handle(op, handler)
}

func (s *Server) Auth(authenticate Authenticator) {
	s.mux.authenticate = authenticate
}

func (s *Server) OnConnect(handler OnConnectHandler) {
	s.mux.onConnect = &handler
}
