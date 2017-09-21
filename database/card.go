package database

type Card struct {
	Id         string
	Column     string
	Revealed   bool
	Votes      int
	TotalVotes int
}

func (d *Database) AddCard(card Card) error {
	_, err := d.db.Exec("INSERT INTO cards(Id, Column, Revealed) VALUES (?, ?, ?)",
		card.Id,
		card.Column,
		card.Revealed)

	return err
}

func (d *Database) GetCard(id string) (Card, error) {
	row := d.db.QueryRow(`
    SELECT cards.Id, cards.Column, cards.Revealed, COUNT(votes.Id)
    FROM cards
    JOIN votes ON cards.Id = votes.Card
    GROUP BY cards.Id, cards.Column, cards.Revealed
    WHERE Id=?`,
		id)

	var card Card
	err := row.Scan(&card.Id, &card.Column, &card.Revealed, &card.Votes)

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

func (d *Database) DeleteCard(id string) error {
	_, err := d.db.Exec("DELETE FROM cards WHERE Id=?",
		id)

	return err
}

func (d *Database) GroupCards(cardFrom, cardTo string) error {
	tx, err := d.db.Begin()
	if err != nil {
		return err
	}

	_, err = tx.Exec("UPDATE votes SET Card=? WHERE Card=?",
		cardTo,
		cardFrom)

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

func (d *Database) GetCards(username, columnId string) (cards []Card, err error) {
	rows, err := d.db.Query(`
    SELECT cards.Id,
           cards.Column,
           cards.Revealed,
           SUM(CASE WHEN votes.Username = ? THEN 1 ELSE 0 END),
           COUNT(votes.Id)
    FROM cards
    LEFT JOIN votes ON cards.Id = votes.Card
    WHERE cards.Column = ?
    GROUP BY cards.Id, cards.Column, cards.Revealed`,
		username, columnId)
	if err != nil {
		return cards, err
	}
	defer rows.Close()

	for rows.Next() {
		var card Card
		if err = rows.Scan(&card.Id, &card.Column, &card.Revealed, &card.Votes, &card.TotalVotes); err != nil {
			return cards, err
		}
		cards = append(cards, card)
	}

	return cards, rows.Err()
}
