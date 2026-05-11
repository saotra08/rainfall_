all:
	@docker build -t rainfall:42 .
	@clear
	@docker run --name rainfall42 --env-file '.env' --network 'host' --rm -it rainfall:42 bash
# 	@docker rmi rainfall:42 2>/dev/null || true

exec:
	@docker exec -it rainfall42 bash

.PHONY: all exec
