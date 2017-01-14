package database

type User struct {
	Username string
	Token    string
}

func (d *Database) EnsureUser(user User) error {
	_, err := d.db.Exec("INSERT OR REPLACE INTO users(Username, Token) VALUES(?, ?)",
		user.Username,
		user.Token)

	return err
}

func (d *Database) GetUser(username string) (User, error) {
	row := d.db.QueryRow("SELECT Username, Token FROM users WHERE Username=?",
		username)

	var user User
	err := row.Scan(&user.Username, &user.Token)

	return user, err
}
