import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TaskScreen(),
    );
  }
}

class Task {
  final int id;
  final String title;
  final String description;
  final bool completed;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      completed: json['completed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed,
    };
  }
}

class TaskService {
  static const String baseUrl = 'http://localhost:8080/api';

  static Future<List<Task>> getTasks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tasks'));
      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty || responseBody == 'null') {
          return [];
        }

        final dynamic jsonResponse = json.decode(responseBody);
        if (jsonResponse == null) {
          return [];
        }

        List<dynamic> jsonList = jsonResponse as List<dynamic>;
        return jsonList.map((json) => Task.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load tasks: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getTasks: $e');
      throw Exception('Error connecting to server: $e');
    }
  }

  static Future<Task> createTask(String title, String description) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'description': description,
        }),
      );
      if (response.statusCode == 201) {
        return Task.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create task');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Task> updateTask(Task task) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/tasks/${task.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(task.toJson()),
      );
      if (response.statusCode == 200) {
        return Task.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update task');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> deleteTask(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/tasks/$id'));
      if (response.statusCode != 204) {
        throw Exception('Failed to delete task');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  List<Task> tasks = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final taskList = await TaskService.getTasks();
      setState(() {
        tasks = taskList ?? []; // Ensure tasks is never null
        isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
        tasks = []; // Set empty list on error
      });
    }
  }

  Future<void> createTask(String title, String description) async {
    try {
      await TaskService.createTask(title, description);
      loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating task: $e')),
      );
    }
  }

  Future<void> toggleTask(Task task) async {
    try {
      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        completed: !task.completed,
      );
      await TaskService.updateTask(updatedTask);
      loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task: $e')),
      );
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      await TaskService.deleteTask(id);
      loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting task: $e')),
      );
    }
  }

  void showAddTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  createTask(titleController.text, descriptionController.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadTasks,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $error'),
                      ElevatedButton(
                        onPressed: loadTasks,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : tasks.isEmpty
                  ? const Center(
                      child: Text('No tasks yet. Add one using the + button!'),
                    )
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Checkbox(
                              value: task.completed,
                              onChanged: (_) => toggleTask(task),
                            ),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: task.description.isNotEmpty
                                ? Text(task.description)
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => deleteTask(task.id),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
