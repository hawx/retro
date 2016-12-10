package models

import "sync"

type Retro struct {
	sync.RWMutex
	columns map[string]*Column
}

func NewRetro() *Retro {
	return &Retro{
		columns: map[string]*Column{},
	}
}

func (r *Retro) Add(column *Column) {
	r.Lock()
	r.columns[column.Id] = column
	r.Unlock()
}

func (r *Retro) Get(id string) *Column {
	r.RLock()
	column := r.columns[id]
	r.RUnlock()
	return column
}

func (r *Retro) GetCard(columnId, cardId string) *Card {
	column := r.Get(columnId)
	if column != nil {
		return column.Get(cardId)
	}
	return nil
}

func (r *Retro) Columns() map[string]*Column {
	r.RLock()
	defer r.RUnlock()

	columns := map[string]*Column{}
	for id, column := range r.columns {
		columns[id] = column
	}

	return columns
}
