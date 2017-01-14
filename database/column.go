package database

type Column struct {
	Id    string
	Retro string
	Name  string
}

func (d *Database) EnsureColumn(column Column) error {
	_, err := d.db.Exec("INSERT OR REPLACE INTO columns(Id, Retro, Name) VALUES (?, ?, ?)",
		column.Id,
		column.Retro,
		column.Name)

	return err
}

func (d *Database) GetColumn(id string) (Column, error) {
	row := d.db.QueryRow("SELECT Id, Retro, Name FROM columns WHERE Id=?",
		id)

	var column Column
	err := row.Scan(&column.Id, &column.Retro, &column.Name)

	return column, err
}

func (d *Database) GetColumns(retroId string) (columns []Column, err error) {
	rows, err := d.db.Query("SELECT Id, Retro, Name FROM columns WHERE Retro=?",
		retroId)
	if err != nil {
		return columns, err
	}
	defer rows.Close()

	for rows.Next() {
		var column Column
		if err = rows.Scan(&column.Id, &column.Retro, &column.Name); err != nil {
			return columns, err
		}
		columns = append(columns, column)
	}

	return columns, rows.Err()
}
