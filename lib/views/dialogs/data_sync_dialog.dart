import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../providers/focus_session_provider.dart';
import '../../providers/task_provider.dart';
import '../../repositories/storage_service.dart';

class DataSyncDialog extends ConsumerStatefulWidget {
  const DataSyncDialog({super.key});

  @override
  ConsumerState<DataSyncDialog> createState() => _DataSyncDialogState();
}

class _DataSyncDialogState extends ConsumerState<DataSyncDialog> {
  final TextEditingController _importController = TextEditingController();
  bool _isExporting = false;
  bool _isImporting = false;
  String? _statusMessage;
  bool _isSuccess = true;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
      _statusMessage = null;
    });

    try {
      final jsonStr = await StorageService.instance.exportAllDataAsJson();
      await Clipboard.setData(ClipboardData(text: jsonStr));
      setState(() {
        _isExporting = false;
        _isSuccess = true;
        _statusMessage = '数据已成功导出并复制到剪贴板！可直接粘贴发送至手机或 Mac 导入。';
      });
    } catch (e) {
      setState(() {
        _isExporting = false;
        _isSuccess = false;
        _statusMessage = '导出失败: $e';
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _importController.text = data.text!;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('剪贴板中无文本内容')));
    }
  }

  Future<void> _importData() async {
    final text = _importController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _isSuccess = false;
        _statusMessage = '请先粘贴或输入要导入的 JSON 数据';
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _statusMessage = null;
    });

    try {
      final success = await StorageService.instance.importDataFromJson(text);
      if (success) {
        // 重新加载任务列表与历史记录
        await ref.read(tasksProvider.notifier).reload();
        await ref.read(focusSessionsProvider.notifier).reload();

        if (!mounted) return;
        setState(() {
          _isImporting = false;
          _isSuccess = true;
          _statusMessage = '数据恢复与导入成功！任务列表已实时刷新。';
        });
      } else {
        setState(() {
          _isImporting = false;
          _isSuccess = false;
          _statusMessage = '导入失败：数据格式不正确，请确认是合法的备份 JSON。';
        });
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _isSuccess = false;
        _statusMessage = '导入出错: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部标题
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '跨端数据互通与备份',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '无需依赖网络云端账号，即可在 Mac 和 Android 手机之间无损复制或还原任务数据。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 20),

                // 模块 1：导出数据
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. 导出本端数据',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '将全部任务、子任务进度以及专注打卡记录打包为标准 JSON，并复制到剪贴板。',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isExporting ? null : _exportData,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('导出并复制到剪贴板'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 模块 2：导入数据
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '2. 从另一端导入数据',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.paste_rounded, size: 16),
                            label: const Text(
                              '粘贴剪贴板内容',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _importController,
                        maxLines: 4,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: '在此粘贴备份的 JSON 数据...',
                          hintStyle: const TextStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.accent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isImporting ? null : _importData,
                          icon: _isImporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accent,
                                  ),
                                )
                              : const Icon(
                                  Icons.file_download_rounded,
                                  size: 18,
                                ),
                          label: const Text('确认导入并覆盖恢复'),
                        ),
                      ),
                    ],
                  ),
                ),

                // 状态消息提示
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isSuccess
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isSuccess ? AppColors.success : AppColors.error,
                      ),
                    ),
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isSuccess ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
