package data

import (
	_ "github.com/mxk/go-sqlite/sqlite3"

	"database/sql"
)

type Database struct {
	db *sql.DB
}

func Open(path string) (*Database, error) {
	sqlite, err := sql.Open("sqlite3", path)
	if err != nil {
		return nil, err
	}

	db := &Database{sqlite}

	return db, db.setup()
}

func (d *Database) setup() error {
	_, err := d.db.Exec(`
    CREATE TABLE IF NOT EXISTS users (
      Username TEXT PRIMARY KEY,
      Token    TEXT
    );
  `)

	return err
}

func (d *Database) Close() error {
	return d.db.Close()
}
