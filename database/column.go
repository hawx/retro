package database

type Column struct {
	Id    string
	Retro string
	Name  string
	Order int
}

func (d *Database) AddColumn(column Column) error {
	_, err := d.db.Exec("INSERT INTO columns(Id, Retro, Name, \"Order\") VALUES (?, ?, ?, ?)",
		column.Id,
		column.Retro,
		column.Name,
		column.Order)

	return err
}

func (d *Database) GetColumn(id string) (Column, error) {
	row := d.db.QueryRow("SELECT Id, Retro, Name, Order FROM columns WHERE Id=?",
		id)

	var column Column
	err := row.Scan(&column.Id, &column.Retro, &column.Name, &column.Order)

	return column, err
}

func (d *Database) GetColumns(retroId string) (columns []Column, err error) {
	rows, err := d.db.Query("SELECT Id, Retro, Name, \"Order\" FROM columns WHERE Retro=? ORDER BY \"Order\"",
		retroId)
	if err != nil {
		return columns, err
	}
	defer rows.Close()

	for rows.Next() {
		var column Column
		if err = rows.Scan(&column.Id, &column.Retro, &column.Name, &column.Order); err != nil {
			return columns, err
		}
		columns = append(columns, column)
	}

	return columns, rows.Err()
}
