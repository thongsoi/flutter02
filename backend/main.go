package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
)

type Task struct {
	ID          int    `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Completed   bool   `json:"completed"`
}

type TaskRequest struct {
	Title       string `json:"title"`
	Description string `json:"description"`
}

type Server struct {
	db *pgxpool.Pool
}

func main() {
	// Load .env file
	err := godotenv.Load()
	if err != nil {
		log.Println("Warning: .env file not found")
	}

	//Database connection
	dbURL := os.Getenv("DATABASE_URL")

	/*
		if dbURL == "" {
			dbURL = "postgres://username:password@localhost:5432/taskdb?sslmode=disable"
		}
	*/

	pool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v\n", err)
	}
	defer pool.Close()

	// Test connection
	err = pool.Ping(context.Background())
	if err != nil {
		log.Fatalf("Unable to ping database: %v\n", err)
	}
	log.Println("Connected to PostgreSQL!")

	// Initialize database
	err = initDB(pool)
	if err != nil {
		log.Fatalf("Unable to initialize database: %v\n", err)
	}

	server := &Server{db: pool}

	// Setup router
	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	// CORS configuration
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	// Routes
	r.Get("/api/tasks", server.getTasks)
	r.Post("/api/tasks", server.createTask)
	r.Put("/api/tasks/{id}", server.updateTask)
	r.Delete("/api/tasks/{id}", server.deleteTask)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

func initDB(pool *pgxpool.Pool) error {
	query := `
	CREATE TABLE IF NOT EXISTS tasks (
		id SERIAL PRIMARY KEY,
		title VARCHAR(255) NOT NULL,
		description TEXT,
		completed BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);`

	_, err := pool.Exec(context.Background(), query)
	return err
}

func (s *Server) getTasks(w http.ResponseWriter, r *http.Request) {
	rows, err := s.db.Query(context.Background(),
		"SELECT id, title, description, completed FROM tasks ORDER BY id DESC")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var tasks []Task
	for rows.Next() {
		var task Task
		err := rows.Scan(&task.ID, &task.Title, &task.Description, &task.Completed)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		tasks = append(tasks, task)
	}

	// Ensure we always return an array, even if empty
	if tasks == nil {
		tasks = []Task{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tasks)
}

func (s *Server) createTask(w http.ResponseWriter, r *http.Request) {
	var req TaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	var task Task
	err := s.db.QueryRow(context.Background(),
		"INSERT INTO tasks (title, description) VALUES ($1, $2) RETURNING id, title, description, completed",
		req.Title, req.Description).Scan(&task.ID, &task.Title, &task.Description, &task.Completed)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(task)
}

func (s *Server) updateTask(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "Invalid task ID", http.StatusBadRequest)
		return
	}

	var task Task
	if err := json.NewDecoder(r.Body).Decode(&task); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err = s.db.QueryRow(context.Background(),
		"UPDATE tasks SET title = $1, description = $2, completed = $3 WHERE id = $4 RETURNING id, title, description, completed",
		task.Title, task.Description, task.Completed, id).Scan(&task.ID, &task.Title, &task.Description, &task.Completed)

	if err != nil {
		if err == pgx.ErrNoRows {
			http.Error(w, "Task not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(task)
}

func (s *Server) deleteTask(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "Invalid task ID", http.StatusBadRequest)
		return
	}

	result, err := s.db.Exec(context.Background(), "DELETE FROM tasks WHERE id = $1", id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if result.RowsAffected() == 0 {
		http.Error(w, "Task not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
