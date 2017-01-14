package database

type Retro struct {
	Id string
}

func (d *Database) EnsureRetro(retro Retro) error {
	_, err := d.db.Exec("INSERT OR REPLACE INTO retros(Id) VALUES (?)",
		retro.Id)

	return err
}
