package database

func (d *Database) AddParticipant(retroId, username string) error {
	_, err := d.db.Exec("INSERT INTO participants(Retro, Username) VALUES (?, ?)",
		retroId,
		username)

	return err
}

func (d *Database) GetParticipants(retroId string) (participants []string, err error) {
	rows, err := d.db.Query("SELECT Username FROM participants WHERE Retro = ?",
		retroId)
	if err != nil {
		return participants, err
	}
	defer rows.Close()

	for rows.Next() {
		var participant string
		if err = rows.Scan(&participant); err != nil {
			return participants, err
		}
		participants = append(participants, participant)
	}

	return participants, rows.Err()
}
