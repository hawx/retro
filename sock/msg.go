package sock

// Msg is a standard message type that should work for all the use cases required.
type Msg struct {
	// Id is the name for the connection that the message originated from, or an
	// empty string if the message originated from the server.
	Id string `json:"id"`

	// Auth contains parameters used to authenticate a messages origin. It is not
	// present on messages sent from the server to a client.
	Auth *MsgAuth `json:"auth"`

	// Op is the name of the operation being carried out.
	Op string `json:"op"`

	// Data is anything useful, encoded in a string, hopefully in JSON.
	Data string `json:"data"`
}

type MsgAuth struct {
	Username string `json:"username"`
	Token    string `json:"token"`
}
