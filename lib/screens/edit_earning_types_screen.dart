import 'package:flutter/material.dart';
import '../models/transaction_type.dart';
import '../services/database_helper.dart';

class EditEarningTypesScreen extends StatefulWidget {
  const EditEarningTypesScreen({super.key});

  @override
  _EditEarningTypesScreenState createState() => _EditEarningTypesScreenState();
}

class _EditEarningTypesScreenState extends State<EditEarningTypesScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<TransactionType> earningTypes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEarningTypes();
  }

  Future<void> _loadEarningTypes() async {
    setState(() => isLoading = true);
    final types = await dbHelper.getTransactionTypesByCategory('in');
    setState(() {
      earningTypes = types;
      isLoading = false;
    });
  }

  void _showAddEditTypeDialog({TransactionType? type}) {
    final TextEditingController nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    if (type != null) {
      nameController.text = type.name;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(type == null ? 'Add Earning Type' : 'Edit Earning Type'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please enter a name'
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  if (type == null) {
                    await dbHelper.insertTransactionType(
                      TransactionType(
                          name: nameController.text.trim(), category: 'in'),
                    );
                  } else {
                    await dbHelper.updateTransactionType(
                      TransactionType(
                          id: type.id,
                          name: nameController.text.trim(),
                          category: 'in'),
                    );
                  }
                  Navigator.pop(context);
                  _loadEarningTypes();
                }
              },
              child: Text(type == null ? 'Add' : 'Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteType(TransactionType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete "${type.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await dbHelper.deleteTransactionType(type.id!);
      _loadEarningTypes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Earning Types')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : earningTypes.isEmpty
              ? const Center(child: Text('No earning types found'))
              : ListView.builder(
                  itemCount: earningTypes.length,
                  itemBuilder: (context, index) {
                    final type = earningTypes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(type.name,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          onSelected: (value) {
                            if (value == 'rename') {
                              _showAddEditTypeDialog(type: type);
                            } else if (value == 'delete') {
                              _deleteType(type);
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'rename',
                              child: SizedBox(
                                height: 40,
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.blue),
                                    SizedBox(width: 10),
                                    Text('Rename',
                                        style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: SizedBox(
                                height: 40,
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 10),
                                    Text('Delete',
                                        style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditTypeDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
