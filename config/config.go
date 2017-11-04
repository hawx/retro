package config

import "github.com/BurntSushi/toml"

type Config struct {
	GitHub    *GitHub    `toml:"github"`
	Office365 *Office365 `toml:"office365"`
}

type GitHub struct {
	ClientID     string `toml:"clientID"`
	ClientSecret string `toml:"clientSecret"`
	Organisation string `toml:"organisation"`
}

type Office365 struct {
	ClientID     string `toml:"clientID"`
	ClientSecret string `toml:"clientSecret"`
	Domain       string `toml:"domain"`
}

func Read(path string) (Config, error) {
	var conf Config
	_, err := toml.DecodeFile(path, &conf)
	return conf, err
}
