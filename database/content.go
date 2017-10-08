package database

type Content struct {
	Id     string
	Card   string
	Text   string
	Author string
}

func (d *Database) AddContent(content Content) error {
	_, err := d.db.Exec("INSERT INTO contents(Id, Card, Text, Author) VALUES (?, ?, ?, ?)",
		content.Id,
		content.Card,
		content.Text,
		content.Author)

	return err
}

func (d *Database) UpdateContent(id string, text string) error { 
	_, err := d.db.Exec("UPDATE contents SET Text=? WHERE Id=?",
		text,
		id)

	return err	
}

func (d *Database) GetContent(id string) (Content, error) {
	row := d.db.QueryRow("SELECT Id, Card, Text, Author FROM contents WHERE Id=?",
		id)

	var content Content
	err := row.Scan(&content.Id, &content.Card, &content.Text, &content.Author)

	return content, err
}

func (d *Database) GetContents(cardId string) (contents []Content, err error) {
	rows, err := d.db.Query("SELECT Id, Card, Text, Author FROM contents WHERE Card=?",
		cardId)
	if err != nil {
		return contents, err
	}
	defer rows.Close()

	for rows.Next() {
		var content Content
		if err = rows.Scan(&content.Id, &content.Card, &content.Text, &content.Author); err != nil {
			return contents, err
		}
		contents = append(contents, content)
	}

	return contents, rows.Err()
}
