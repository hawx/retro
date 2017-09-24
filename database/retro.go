package database

import "time"

type Retro struct {
	Id        string
	Name      string
	Stage     string
	Leader string
	CreatedAt time.Time
}

func (d *Database) AddRetro(retro Retro) error {
	_, err := d.db.Exec("INSERT INTO retros(Id, Name, Stage, Leader, CreatedAt) VALUES (?, ?, ?, ?, ?)",
		retro.Id,
		retro.Name,
		retro.Stage,
		retro.Leader,
		retro.CreatedAt)

	return err
}

func (d *Database) GetRetro(id string) (Retro, error) {
	row := d.db.QueryRow("SELECT Id, Name, Stage, Leader, CreatedAt FROM retros WHERE Id=?",
		id)

	var retro Retro
	err := row.Scan(&retro.Id, &retro.Name, &retro.Stage, &retro.Leader, &retro.CreatedAt)

	return retro, err
}

func (d *Database) GetRetros(username string) (retros []Retro, err error) {
	rows, err := d.db.Query(`
    SELECT retros.Id, retros.Name, retros.Stage, retros.Leader, retros.CreatedAt
    FROM retros
    INNER JOIN participants
      ON retros.Id = participants.Retro
    WHERE participants.Username = ?
    ORDER BY retros.CreatedAt`,
		username)
	if err != nil {
		return retros, err
	}
	defer rows.Close()

	for rows.Next() {
		var retro Retro
		if err = rows.Scan(&retro.Id, &retro.Name, &retro.Stage, &retro.Leader, &retro.CreatedAt); err != nil {
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
