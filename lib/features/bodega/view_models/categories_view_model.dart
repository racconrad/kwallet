import 'package:uuid/uuid.dart';

import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/mvvm/view_model.dart';
import 'package:knotes/features/bodega/models/category_model.dart';

class CategoriesViewModel extends ViewModel {
  final FinanceRepository repository;
  List<CategoryModel> categories = const [];
  bool loading = true;
  String type;
  CategoriesViewModel(this.repository, this.type) {
    observe(repository.changes, load);
  }
  Future<void> load() async {
    final request = beginRequest();
    try {
      final rows = await repository.getCategories(type: type);
      if (!isCurrent(request)) return;
      categories = List.unmodifiable(rows);
      loading = false;
      error = null;
      changed();
    } catch (_) {
      if (isCurrent(request)) {
        loading = false;
        fail('No se pudieron cargar las categorías.');
      }
    }
  }

  void selectType(String value) {
    type = value;
    load();
  }

  Future<bool> add(String name, String icon, int color) {
    if (name.trim().isEmpty) return Future.value(fail('Escribe un nombre.'));
    return perform(
      () => repository.createCategory(
        CategoryModel(
          id: const Uuid().v4(),
          name: name.trim(),
          type: type,
          iconKey: icon,
          colorValue: color,
          isDefault: false,
        ),
      ),
    );
  }

  Future<bool> remove(String id) =>
      perform(() => repository.deleteCategory(id));
}
