import 'package:flutter/material.dart';

import '../../models/model_info.dart';
import '../../utils/platform.dart';
import '../styles.dart';

/// Виджет селектора моделей с поиском и фильтрацией.
///
/// Предоставляет выпадающий список моделей с возможностью поиска
/// по названию или ID модели. Поддерживает адаптивную ширину для мобильных устройств.
class ModelSelector extends StatefulWidget {
  /// Список доступных моделей.
  final List<ModelInfo> models;

  /// Выбранная модель (ID).
  final String? selectedModelId;

  /// Callback при изменении выбранной модели.
  final ValueChanged<String?>? onChanged;

  /// Ширина виджета (опционально, для десктопа).
  final double? width;

  /// Показывать ли поле поиска.
  final bool showSearch;

  const ModelSelector({
    super.key,
    required this.models,
    this.selectedModelId,
    this.onChanged,
    this.width,
    this.showSearch = true,
  });

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<ModelInfo> _filteredModels = [];
  String? _selectedModelId;

  @override
  void initState() {
    super.initState();
    _selectedModelId = widget.selectedModelId;
    _filteredModels = widget.models;
    _searchController.addListener(_filterModels);
  }

  @override
  void didUpdateWidget(ModelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.models != oldWidget.models) {
      _filterModels();
    }
    if (widget.selectedModelId != oldWidget.selectedModelId) {
      _selectedModelId = widget.selectedModelId;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterModels);
    _searchController.dispose();
    super.dispose();
  }

  void _filterModels() {
    final searchText = _searchController.text.toLowerCase().trim();
    
    setState(() {
      if (searchText.isEmpty) {
        _filteredModels = widget.models;
      } else {
        _filteredModels = widget.models.where((model) {
          final nameMatch = model.name.toLowerCase().contains(searchText);
          final idMatch = model.id.toLowerCase().contains(searchText);
          final descriptionMatch = model.description?.toLowerCase().contains(searchText) ?? false;
          return nameMatch || idMatch || descriptionMatch;
        }).toList();
      }
    });
  }

  void _onModelChanged(String? modelId) {
    setState(() {
      _selectedModelId = modelId;
    });
    widget.onChanged?.call(modelId);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformUtils.isMobile();
    final effectiveWidth = isMobile ? null : (widget.width ?? AppStyles.searchFieldWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showSearch && widget.models.length > 5) ...[
          SizedBox(
            width: effectiveWidth,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск модели',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppStyles.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                  borderSide: const BorderSide(color: AppStyles.borderColor),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppStyles.borderRadius)),
                  borderSide: BorderSide(color: AppStyles.borderColor),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppStyles.borderRadius)),
                  borderSide: BorderSide(
                    color: AppStyles.accentColor,
                    width: 2,
                  ),
                ),
                hintStyle: AppStyles.hintTextStyle,
                contentPadding: const EdgeInsets.all(AppStyles.paddingSmall),
              ),
              style: AppStyles.primaryTextStyle,
              cursorColor: AppStyles.textPrimary,
            ),
          ),
          const SizedBox(height: AppStyles.paddingSmall),
        ],
        SizedBox(
          width: effectiveWidth,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedModelId ?? (widget.models.isNotEmpty ? widget.models.first.id : null),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppStyles.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                borderSide: const BorderSide(color: AppStyles.borderColor),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppStyles.borderRadius)),
                borderSide: BorderSide(color: AppStyles.borderColor),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppStyles.borderRadius)),
                borderSide: BorderSide(
                  color: AppStyles.accentColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(AppStyles.paddingSmall),
            ),
            dropdownColor: AppStyles.cardColor,
            style: AppStyles.primaryTextStyle,
            icon: const Icon(
              Icons.arrow_drop_down,
              color: AppStyles.textPrimary,
            ),
            hint: const Text(
              'Выбор модели',
              style: AppStyles.hintTextStyle,
            ),
            items: _filteredModels.map((model) {
              return DropdownMenuItem<String>(
                value: model.id,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      model.displayName,
                      style: AppStyles.primaryTextStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (model.id != model.name)
                      Text(
                        model.id,
                        style: AppStyles.secondaryTextStyle.copyWith(
                          fontSize: AppStyles.fontSizeHint,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: _filteredModels.isEmpty ? null : _onModelChanged,
            selectedItemBuilder: (context) {
              // Показываем только название в выбранном элементе
              return _filteredModels.map((model) {
                return Text(
                  model.displayName,
                  style: AppStyles.primaryTextStyle,
                  overflow: TextOverflow.ellipsis,
                );
              }).toList();
            },
          ),
        ),
        if (_filteredModels.isEmpty && _searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppStyles.paddingSmall),
            child: Text(
              'Модели не найдены',
              style: AppStyles.secondaryTextStyle.copyWith(
                fontSize: AppStyles.fontSizeHint,
              ),
            ),
          ),
      ],
    );
  }
}
