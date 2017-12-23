.PHONY: all
all: out/retro out/app/dist out/config.toml

out/app/dist:
				(cd app; npm run build -- --output-path ../out/app/dist)

out/retro:
				go build -o ./out/retro .

out/config.toml:
				cp config.toml ./out

.PHONY: install
install:
				go get -v ./...
				(cd app; npm install)
				npm i -g elm

.PHONY: test
test:
				go test ./...
				(cd app; node test.js)

.PHONY: clean
clean:
				rm -rf ./out
