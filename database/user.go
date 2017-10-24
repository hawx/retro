package database

type User struct {
	Username string
	Secret   string
}

func (d *Database) EnsureUser(username, secret string) error {
	_, err := d.db.Exec("INSERT OR IGNORE INTO users(Username, Secret) VALUES(?, ?)",
		username,
		secret)

	return err
}

func (d *Database) GetUser(username string) (User, error) {
	row := d.db.QueryRow("SELECT Username, Secret FROM users WHERE Username=?",
		username)

	var user User
	err := row.Scan(&user.Username, &user.Secret)

	return user, err
}

func (d *Database) GetUsers() (users []User, err error) {
	rows, err := d.db.Query("SELECT Username, Secret FROM users")
	if err != nil {
		return users, err
	}
	defer rows.Close()

	for rows.Next() {
		var user User
		if err = rows.Scan(&user.Username, &user.Secret); err != nil {
			return users, err
		}
		users = append(users, user)
	}

	return users, rows.Err()
}
