package models

import "sync"

type Retro struct {
	sync.RWMutex
	columns []*Column
}

func NewRetro() *Retro {
	return &Retro{
		columns: []*Column{},
	}
}

func (r *Retro) Add(column *Column) {
	r.Lock()
	r.columns = append(r.columns, column)
	r.Unlock()
}

func (r *Retro) Get(id string) *Column {
	r.RLock()
	defer r.RUnlock()

	for _, column := range r.columns {
		if column.Id == id {
			return column
		}
	}
	return nil
}

func (r *Retro) GetCard(columnId, cardId string) *Card {
	column := r.Get(columnId)
	if column != nil {
		return column.Get(cardId)
	}
	return nil
}

func (r *Retro) Columns() []*Column {
	r.RLock()
	defer r.RUnlock()

	columns := make([]*Column, len(r.columns))
	copy(columns, r.columns)

	return columns
}
