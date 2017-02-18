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

func (d *Database) GetUsers() (users []User, err error) {
	rows, err := d.db.Query("SELECT Username, Token FROM users")
	if err != nil {
		return users, err
	}
	defer rows.Close()

	for rows.Next() {
		var user User
		if err = rows.Scan(&user.Username, &user.Token); err != nil {
			return users, err
		}
		users = append(users, user)
	}

	return users, rows.Err()
}
