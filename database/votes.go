package database

type Vote struct {
	Username string
	Card     string
	Count    int
}

func (d *Database) Vote(username, cardId string) error {
	_, err := d.db.Exec("INSERT INTO votes(Username, Card) VALUES (?, ?)",
		username, cardId)

	return err
}

func (d *Database) Unvote(username, cardId string) error {
	_, err := d.db.Exec("DELETE FROM votes WHERE Id=(SELECT MIN(Id) FROM votes WHERE Username=? AND Card=?)",
		username, cardId)

	return err
}
