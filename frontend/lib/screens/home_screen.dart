import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo_app/providers/todo_provider.dart';
import 'package:todo_app/widgets/todo_card.dart';
import 'package:todo_app/widgets/add_todo_dialog.dart';
import 'package:todo_app/widgets/loading_widget.dart';
import 'package:todo_app/widgets/error_widget.dart' as custom_error;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load todos when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodoProvider>().loadTodos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Todo App',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<TodoProvider>().loadTodos();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<TodoProvider>(
        builder: (context, todoProvider, child) {
          if (todoProvider.isLoading) {
            return const LoadingWidget();
          }

          if (todoProvider.error != null) {
            return custom_error.CustomErrorWidget(
              error: todoProvider.error!,
              onRetry: () => todoProvider.loadTodos(),
            );
          }

          if (todoProvider.todos.isEmpty) {
            return _buildEmptyState();
          }

          return _buildTodoList(todoProvider);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTodoDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Todo'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No todos yet!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first todo to get started',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddTodoDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Todo'),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoList(TodoProvider todoProvider) {
    final pendingTodos = todoProvider.pendingTodos;
    final completedTodos = todoProvider.completedTodos;

    return CustomScrollView(
      slivers: [
        // Pending Todos Section
        if (pendingTodos.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Pending (${pendingTodos.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final todo = pendingTodos[index];
                return TodoCard(
                  todo: todo,
                  onToggle: () => todoProvider.toggleTodo(todo.id!),
                  onEdit: () => _showEditTodoDialog(context, todo),
                  onDelete: () => _showDeleteDialog(context, todo),
                );
              },
              childCount: pendingTodos.length,
            ),
          ),
        ],

        // Completed Todos Section
        if (completedTodos.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Completed (${completedTodos.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final todo = completedTodos[index];
                return TodoCard(
                  todo: todo,
                  onToggle: () => todoProvider.toggleTodo(todo.id!),
                  onEdit: () => _showEditTodoDialog(context, todo),
                  onDelete: () => _showDeleteDialog(context, todo),
                );
              },
              childCount: completedTodos.length,
            ),
          ),
        ],

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  void _showAddTodoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddTodoDialog(),
    );
  }

  void _showEditTodoDialog(BuildContext context, todo) {
    showDialog(
      context: context,
      builder: (context) => AddTodoDialog(todo: todo),
    );
  }

  void _showDeleteDialog(BuildContext context, todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Todo'),
        content: Text('Are you sure you want to delete "${todo.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TodoProvider>().deleteTodo(todo.id!);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
} 