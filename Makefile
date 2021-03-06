.PHONY: all
all: out/retro out/app/dist out/config.toml

out/app/dist:
				(cd app; npm run build --progress --verbose)
				mkdir -p out/app/dist
				cp app/dist/* out/app/dist

out/retro:
				go build -o ./out/retro .

out/config.toml:
				cp config.toml ./out

.PHONY: install
install:
				go get -v ./...
				(cd app; npm install)

.PHONY: test
test:
				go test ./... && node app/test.js

.PHONY: clean
clean:
				rm -rf ./out
