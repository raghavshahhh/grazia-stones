import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/repositories/ai_job_repository.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';

// Supabase is not initialised in tests, so every call below runs as a signed-out user.
void main() {
  test('profile save without a session fails instead of silently succeeding', () async {
    expect(SupabaseService.instance.updateProfile({'full_name': 'X'}), throwsStateError);
  });

  test('password reset link opens the app on its reset route', () {
    expect(SupabaseService.resetPasswordUrl, 'graziastones:///reset-password');
  });

  test('retrying an AI job never returns a local stand-in job', () async {
    final repo = AIJobRepository();
    final local = await repo.createVisualizationJob(inputImageUrl: 'data:image/png;base64,AA==');
    expect(repo.retryJob(local.id), throwsStateError);
  });
}
