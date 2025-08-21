import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../services/face_embedding_service.dart';
import '../utils/logger.dart';
import '../utils/custom_colors.dart';

class FaceDataDebugScreen extends StatefulWidget {
  const FaceDataDebugScreen({super.key});

  @override
  State<FaceDataDebugScreen> createState() => _FaceDataDebugScreenState();
}

class _FaceDataDebugScreenState extends State<FaceDataDebugScreen> {
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();
  String _debugInfo = 'Loading...';
  List<String> _storedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    try {
      await _embeddingService.initialize();

      final prefs = await SharedPreferences.getInstance();
      final appDocDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();

      // Get all stored preferences keys
      final allKeys = prefs.getKeys();
      final faceKeys = allKeys
          .where((key) => key.startsWith('face_embedding_'))
          .toList();

      // Extract user IDs from face embedding keys
      _storedUsers = faceKeys
          .where((key) => !key.endsWith('_hash'))
          .map((key) => key.replaceAll('face_embedding_', ''))
          .toList();

      final StringBuffer debugBuffer = StringBuffer();
      debugBuffer.writeln('📱 FACE RECOGNITION DEBUG INFO');
      debugBuffer.writeln('═' * 40);
      debugBuffer.writeln();

      debugBuffer.writeln('📂 STORAGE LOCATIONS:');
      debugBuffer.writeln('App Documents: ${appDocDir.path}');
      debugBuffer.writeln('Temp Directory: ${tempDir.path}');
      debugBuffer.writeln(
        'SharedPreferences: Platform-specific secure storage',
      );
      debugBuffer.writeln();

      debugBuffer.writeln('👥 REGISTERED USERS: ${_storedUsers.length}');
      if (_storedUsers.isNotEmpty) {
        for (int i = 0; i < _storedUsers.length; i++) {
          final userId = _storedUsers[i];
          debugBuffer.writeln('${i + 1}. $userId');

          // Try to load embedding to verify it exists
          final embedding = await _embeddingService.loadFaceEmbedding(userId);
          if (embedding != null) {
            debugBuffer.writeln('   ✅ Embedding: ${embedding.length}D vector');
            debugBuffer.writeln(
              '   📊 Sample values: [${embedding.take(3).map((e) => e.toStringAsFixed(3)).join(', ')}...]',
            );
          } else {
            debugBuffer.writeln('   ❌ Embedding: Failed to load');
          }
          debugBuffer.writeln();
        }
      } else {
        debugBuffer.writeln('No registered users found.');
        debugBuffer.writeln();
      }

      debugBuffer.writeln('🔍 RAW SHAREDPREFERENCES DATA:');
      final faceRelatedKeys = allKeys
          .where(
            (key) =>
                key.startsWith('face_embedding_') ||
                key.contains('face') ||
                key.contains('embed'),
          )
          .toList();

      if (faceRelatedKeys.isNotEmpty) {
        for (final key in faceRelatedKeys) {
          final value = prefs.getString(key);
          if (value != null) {
            final truncatedValue = value.length > 50
                ? '${value.substring(0, 50)}...'
                : value;
            debugBuffer.writeln('$key: $truncatedValue');
          }
        }
      } else {
        debugBuffer.writeln('No face-related data found in SharedPreferences.');
      }

      debugBuffer.writeln();
      debugBuffer.writeln('🔧 SERVICE STATUS:');
      debugBuffer.writeln('Embedding Service: ${_embeddingService.toString()}');

      if (mounted) {
        setState(() {
          _debugInfo = debugBuffer.toString();
        });
      }
    } catch (e) {
      Logger.error('Debug info loading failed: $e');
      setState(() {
        _debugInfo = 'Error loading debug info: $e';
      });
    }
  }

  Future<void> _testSaveEmbedding() async {
    try {
      // Create test embedding
      final testEmbedding = List.generate(512, (i) => (i / 512.0) - 0.5);
      final testUserId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';

      Logger.info('Saving test embedding for user: $testUserId');

      final success = await _embeddingService.saveFaceEmbedding(
        testUserId,
        testEmbedding,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Test embedding saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload debug info
        _loadDebugInfo();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save test embedding'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Logger.error('Test save failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove all face-related data
      final keysToRemove = prefs
          .getKeys()
          .where((key) => key.startsWith('face_embedding_'))
          .toList();

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🧹 Cleared ${keysToRemove.length} face data entries'),
          backgroundColor: CustomColors.getWarningColor(context),
        ),
      );

      // Reload debug info
      _loadDebugInfo();
    } catch (e) {
      Logger.error('Clear data failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Face Data Debug',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: CustomColors.getOnSurfaceColor(context),
          ),
        ),
        backgroundColor: CustomColors.getSurfaceColor(context),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: CustomColors.getOnSurfaceColor(context),
            ),
            onPressed: _loadDebugInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testSaveEmbedding,
                    icon: Icon(Icons.science, size: 18),
                    label: Text('Test Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomColors.getPrimaryColor(context),
                      foregroundColor: CustomColors.getOnPrimaryColor(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearAllData,
                    icon: Icon(Icons.clear_all, size: 18),
                    label: Text('Clear All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomColors.getErrorColor(context),
                      foregroundColor: CustomColors.getOnPrimaryColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Debug Info
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CustomColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: CustomColors.getSecondaryColor(
                    context,
                  ).withOpacity(0.3),
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _debugInfo,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: CustomColors.getOnSurfaceColor(context),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
