package database

type Retro struct {
	Id    string
	Name  string
	Stage string
}

func (d *Database) AddRetro(retro Retro) error {
	_, err := d.db.Exec("INSERT INTO retros(Id, Name, Stage) VALUES (?, ?, ?)",
		retro.Id,
		retro.Name,
		retro.Stage)

	return err
}

func (d *Database) GetRetro(id string) (Retro, error) {
	row := d.db.QueryRow("SELECT Id, Name, Stage FROM retros WHERE Id=?",
		id)

	var retro Retro
	err := row.Scan(&retro.Id, &retro.Name, &retro.Stage)

	return retro, err
}

func (d *Database) GetRetros(username string) (retros []Retro, err error) {
	rows, err := d.db.Query(`
    SELECT retros.Id, retros.Name, retros.Stage
    FROM retros
    INNER JOIN retro_users
      ON retros.Id = retro_users.Retro
    WHERE retro_users.Username = ?`,
		username)
	if err != nil {
		return retros, err
	}
	defer rows.Close()

	for rows.Next() {
		var retro Retro
		if err = rows.Scan(&retro.Id, &retro.Name, &retro.Stage); err != nil {
			return retros, err
		}
		retros = append(retros, retro)
	}

	return retros, rows.Err()
}

func (d *Database) SetStage(id, stage string) error {
	_, err := d.db.Exec("UPDATE retros SET Stage=? WHERE Id=?",
		stage,
		id)

	return err
}
