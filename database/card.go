package database

type Card struct {
	Id       string
	Column   string
	Votes    int
	Revealed bool
}

func (d *Database) AddCard(card Card) error {
	_, err := d.db.Exec("INSERT INTO cards(Id, Column, Votes, Revealed) VALUES (?, ?, ?, ?)",
		card.Id,
		card.Column,
		card.Votes,
		card.Revealed)

	return err
}

func (d *Database) GetCard(id string) (Card, error) {
	row := d.db.QueryRow("SELECT Id, Column, Votes, Revealed FROM cards WHERE Id=?",
		id)

	var card Card
	err := row.Scan(&card.Id, &card.Column, &card.Votes, &card.Revealed)

	return card, err
}

func (d *Database) MoveCard(id, columnId string) error {
	_, err := d.db.Exec("UPDATE cards SET Column=? WHERE Id=?",
		columnId,
		id)

	return err
}

func (d *Database) RevealCard(id string) error {
	_, err := d.db.Exec("UPDATE cards SET Revealed=1 WHERE Id=?",
		id)

	return err
}

func (d *Database) VoteCard(id string) error {
	_, err := d.db.Exec("UPDATE cards SET Votes=Votes + 1 WHERE Id=?",
		id)

	return err
}

func (d *Database) GroupCards(cardFrom, cardTo string) error {
	tx, err := d.db.Begin()
	if err != nil {
		return err
	}

	_, err = tx.Exec(`UPDATE cards SET Votes=Votes + ( SELECT Votes FROM cards WHERE Id=? ) WHERE Id=?`,
		cardFrom,
		cardTo)

	if err != nil {
		tx.Rollback()
		return err
	}

	_, err = tx.Exec("UPDATE contents SET Card=? WHERE Card=?",
		cardTo,
		cardFrom)

	if err != nil {
		tx.Rollback()
		return err
	}

	_, err = tx.Exec("DELETE FROM cards WHERE Id=?",
		cardFrom)

	if err != nil {
		tx.Rollback()
		return err
	}

	return tx.Commit()
}

func (d *Database) GetCards(columnId string) (cards []Card, err error) {
	rows, err := d.db.Query("SELECT Id, Column, Votes, Revealed FROM cards WHERE Column=?",
		columnId)
	if err != nil {
		return cards, err
	}
	defer rows.Close()

	for rows.Next() {
		var card Card
		if err = rows.Scan(&card.Id, &card.Column, &card.Votes, &card.Revealed); err != nil {
			return cards, err
		}
		cards = append(cards, card)
	}

	return cards, rows.Err()
}
