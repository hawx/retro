package database

type Retro struct {
	Id    string
	Stage string
}

func (d *Database) EnsureRetro(retro Retro) error {
	_, err := d.db.Exec("INSERT OR IGNORE INTO retros(Id, Stage) VALUES (?, ?)",
		retro.Id,
		retro.Stage)

	return err
}

func (d *Database) GetRetro(id string) (Retro, error) {
	row := d.db.QueryRow("SELECT Id, Stage FROM retros WHERE Id=?",
		id)

	var retro Retro
	err := row.Scan(&retro.Id, &retro.Stage)

	return retro, err
}

func (d *Database) SetStage(id, stage string) error {
	_, err := d.db.Exec("UPDATE retros SET Stage=? WHERE Id=?",
		stage,
		id)

	return err
}
