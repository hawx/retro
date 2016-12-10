package models

import "sync"

type Card struct {
	Id       string
	Votes    int
	Revealed bool

	sync.RWMutex
	contents []Content
}

func (c *Card) Add(content Content) {
	c.Lock()
	c.contents = append(c.contents, content)
	c.Unlock()
}

func (c *Card) Contents() []Content {
	c.Lock()
	contents := make([]Content, len(c.contents))
	copy(contents, c.contents)
	c.Unlock()
	return contents
}
