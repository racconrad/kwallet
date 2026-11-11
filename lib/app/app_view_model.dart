import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/mvvm/view_model.dart';

class AppViewModel extends ViewModel {
  final SettingsRepository repository;
  Map<String, String> settings = const {};
  AppViewModel(this.repository) {
    observe(repository.changes, load);
  }
  Future<void> load() async {
    final request = beginRequest();
    try {
      final data = await repository.getSettings();
      if (!isCurrent(request)) return;
      settings = Map.unmodifiable(data);
      changed();
    } catch (_) {
      if (isCurrent(request)) fail('No pudimos abrir tus ajustes.');
    }
  }
}
