import 'package:flutter/foundation.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/services/api_service.dart';

class TodoProvider with ChangeNotifier {
  final ApiService _apiService;
  List<Todo> _todos = [];
  bool _isLoading = false;
  String? _error;

  TodoProvider({ApiService? apiService}) 
      : _apiService = apiService ?? ApiService(baseUrl: 'http://localhost:5000/api');

  // Getters
  List<Todo> get todos => _todos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  List<Todo> get completedTodos => _todos.where((todo) => todo.completed).toList();
  List<Todo> get pendingTodos => _todos.where((todo) => !todo.completed).toList();

  // Load all todos
  Future<void> loadTodos() async {
    _setLoading(true);
    _clearError();
    
    try {
      _todos = await _apiService.getTodos();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Create a new todo
  Future<void> createTodo(String title, String description) async {
    _setLoading(true);
    _clearError();
    
    try {
      final newTodo = await _apiService.createTodo(title, description);
      _todos.add(newTodo);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Update a todo
  Future<void> updateTodo(int id, {String? title, String? description, bool? completed}) async {
    _setLoading(true);
    _clearError();
    
    try {
      final updatedTodo = await _apiService.updateTodo(
        id, 
        title: title, 
        description: description, 
        completed: completed
      );
      
      final index = _todos.indexWhere((todo) => todo.id == id);
      if (index != -1) {
        _todos[index] = updatedTodo;
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Delete a todo
  Future<void> deleteTodo(int id) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _apiService.deleteTodo(id);
      _todos.removeWhere((todo) => todo.id == id);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Toggle todo completion
  Future<void> toggleTodo(int id) async {
    _setLoading(true);
    _clearError();
    
    try {
      final updatedTodo = await _apiService.toggleTodo(id);
      final index = _todos.indexWhere((todo) => todo.id == id);
      if (index != -1) {
        _todos[index] = updatedTodo;
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Health check
  Future<bool> healthCheck() async {
    return await _apiService.healthCheck();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all todos (for testing)
  void clearTodos() {
    _todos.clear();
    notifyListeners();
  }
} 