package database

func (d *Database) AddUser(retroId, username string) error {
	_, err := d.db.Exec("INSERT INTO retro_users(Retro, Username) VALUES (?, ?)",
		retroId,
		username)

	return err
}
