package sock

// Msg is a standard message type that should work for all the use cases required.
type Msg struct {
	// Id is the name for the connection that the message originated from, or an
	// empty string if the message originated from the server.
	Id string `json:"id"`

	// Op is the name of the operation being carried out.
	Op string `json:"op"`

	// Args is a list of arguments for the operation.
	Args []string `json:"args"`
}
