package models

import "sync"

type Column struct {
	Id   string
	Name string

	sync.RWMutex
	cards map[string]*Card
}

func NewColumn(id, name string) *Column {
	return &Column{
		Id:    id,
		Name:  name,
		cards: map[string]*Card{},
	}
}

func (c *Column) Add(card *Card) {
	c.Lock()
	c.cards[card.Id] = card
	c.Unlock()
}

func (c *Column) Get(id string) *Card {
	c.RLock()
	card := c.cards[id]
	c.RUnlock()
	return card
}

func (c *Column) Remove(id string) {
	c.Lock()
	delete(c.cards, id)
	c.Unlock()
}

func (c *Column) Cards() map[string]*Card {
	c.RLock()
	defer c.RUnlock()

	cards := map[string]*Card{}
	for id, card := range c.cards {
		cards[id] = card
	}

	return cards
}
