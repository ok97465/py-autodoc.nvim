.PHONY: test bootstrap

test:
	@echo "Running tests..."
	@LUA_PATH="./lua/?.lua;./lua/?/init.lua;;" busted --verbose

bootstrap:
	@echo "Installing test dependencies..."
	@luarocks install busted
