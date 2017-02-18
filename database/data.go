package database

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
      Username  TEXT PRIMARY KEY,
      Token     TEXT
    );

    CREATE TABLE IF NOT EXISTS retros (
      Id        TEXT PRIMARY KEY,
      Stage     TEXT
    );

    CREATE TABLE IF NOT EXISTS retro_users (
      Retro     TEXT,
      Username  TEXT,
      PRIMARY KEY(Username, Retro),
      FOREIGN KEY(Retro) REFERENCES retros(Id),
      FOREIGN KEY(Username) REFERENCES users(Username)
    );

    CREATE TABLE IF NOT EXISTS columns (
      Id        TEXT PRIMARY KEY,
      Retro     TEXT,
      Name      TEXT,
      "Order"   INTEGER,
      FOREIGN KEY(Retro) REFERENCES retros(Id)
    );

    CREATE TABLE IF NOT EXISTS cards (
      Id        TEXT PRIMARY KEY,
      Column    TEXT,
      Votes     INTEGER,
      Revealed  BOOLEAN,
      FOREIGN KEY(Column) REFERENCES columns(Id)
    );

    CREATE TABLE IF NOT EXISTS contents (
      Id        TEXT PRIMARY KEY,
      Card      TEXT,
      Text      TEXT,
      Author    TEXT,
      FOREIGN KEY(Card) REFERENCES cards(Id),
      FOREIGN KEY(Author) REFERENCES users(Username)
    );
  `)

	return err
}

func (d *Database) Close() error {
	return d.db.Close()
}
