.PHONY: run

run:
	cd backend && go run main.go & \
	cd frontend && flutter run

