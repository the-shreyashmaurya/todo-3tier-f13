import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:todo_app/models/todo.dart';

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  // Helper method to get full URL
  String _getUrl(String endpoint) {
    return '$baseUrl/$endpoint';
  }

  // Get all todos
  Future<List<Todo>> getTodos() async {
    try {
      final response = await http.get(Uri.parse(_getUrl('todos')));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Todo.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load todos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load todos: $e');
    }
  }

  // Get a specific todo
  Future<Todo> getTodo(int id) async {
    try {
      final response = await http.get(Uri.parse(_getUrl('todos/$id')));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return Todo.fromJson(jsonData);
      } else {
        throw Exception('Failed to load todo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load todo: $e');
    }
  }

  // Create a new todo
  Future<Todo> createTodo(String title, String description) async {
    try {
      final response = await http.post(
        Uri.parse(_getUrl('todos')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'description': description,
          'completed': false,
        }),
      );
      
      if (response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        return Todo.fromJson(jsonData);
      } else {
        throw Exception('Failed to create todo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to create todo: $e');
    }
  }

  // Update a todo
  Future<Todo> updateTodo(int id, {String? title, String? description, bool? completed}) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (completed != null) updateData['completed'] = completed;

      final response = await http.put(
        Uri.parse(_getUrl('todos/$id')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return Todo.fromJson(jsonData);
      } else {
        throw Exception('Failed to update todo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update todo: $e');
    }
  }

  // Delete a todo
  Future<void> deleteTodo(int id) async {
    try {
      final response = await http.delete(Uri.parse(_getUrl('todos/$id')));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to delete todo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete todo: $e');
    }
  }

  // Toggle todo completion status
  Future<Todo> toggleTodo(int id) async {
    try {
      final response = await http.patch(Uri.parse(_getUrl('todos/$id/toggle')));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return Todo.fromJson(jsonData);
      } else {
        throw Exception('Failed to toggle todo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to toggle todo: $e');
    }
  }

  // Health check
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse(_getUrl('health')));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
} 