.PHONY: run

run:
	cd backend && go run main.go & \
	cd frontend/flutter run

#command at project root$ make run